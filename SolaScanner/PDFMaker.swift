import CoreText
import UIKit
import Vision

/// One scanned page, already shrunk and JPEG-compressed. The image is backed by the JPEG data,
/// so the PDF embeds it as is instead of storing raw pixels.
nonisolated struct Page: @unchecked Sendable {
    let image: CGImage
    /// Recognized text lines, boxes in 0…1 with the origin top left.
    var lines: [TextLine] = []

    var text: String { lines.map(\.text).joined(separator: "\n") }
}

nonisolated struct TextLine: Sendable {
    let text: String
    let box: CGRect
}

nonisolated enum PDFMaker {
    /// Longest side of a page image in pixels, about 250 dpi for A4.
    private static let maxSide: CGFloat = 2400
    /// PDF page width in points (A4); the height follows the page's aspect ratio.
    private static let pageWidth: CGFloat = 595

    /// Shrinks and compresses the camera images, then reads their text.
    @concurrent static func prepare(_ images: [UIImage]) async -> [Page] {
        var pages: [Page] = []
        for image in images {
            guard let page = compress(image) else { continue }
            pages.append(Page(image: page, lines: read(page)))
        }
        return pages
    }

    private static func compress(_ image: UIImage) -> CGImage? {
        let scale = min(1, maxSide / max(image.size.width, image.size.height))
        let size = CGSize(width: (image.size.width * scale).rounded(), height: (image.size.height * scale).rounded())
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let drawn = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
        guard let data = drawn.jpegData(compressionQuality: 0.72),
              let provider = CGDataProvider(data: data as CFData) else { return nil }
        return CGImage(jpegDataProviderSource: provider, decode: nil, shouldInterpolate: true, intent: .defaultIntent)
    }

    /// Text recognition with Vision, on the device. Languages are detected automatically.
    private static func read(_ image: CGImage) -> [TextLine] {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.automaticallyDetectsLanguage = true
        try? VNImageRequestHandler(cgImage: image).perform([request])
        return (request.results ?? []).compactMap { observation in
            guard let text = observation.topCandidates(1).first?.string, !text.isEmpty else { return nil }
            let box = observation.boundingBox
            return TextLine(text: text, box: CGRect(x: box.minX, y: 1 - box.maxY, width: box.width, height: box.height))
        }
    }

    /// A PDF with the page images and the recognized text as an invisible layer on top,
    /// so the document can be searched and text can be selected.
    @concurrent static func make(_ pages: [Page], title: String, info: DocumentInfo?) async -> Data {
        let format = UIGraphicsPDFRendererFormat()
        var meta: [String: Any] = [
            kCGPDFContextTitle as String: title,
            kCGPDFContextCreator as String: "Sola Scanner",
        ]
        if let info {
            if !info.sender.isEmpty { meta[kCGPDFContextAuthor as String] = info.sender }
            if !info.summary.isEmpty { meta[kCGPDFContextSubject as String] = info.summary }
            let keywords = [info.kind.label] + info.keywords
            meta[kCGPDFContextKeywords as String] = keywords.joined(separator: ", ")
        }
        format.documentInfo = meta

        let a4 = CGRect(x: 0, y: 0, width: pageWidth, height: pageWidth * 297 / 210)
        return UIGraphicsPDFRenderer(bounds: a4, format: format).pdfData { context in
            for page in pages {
                let height = pageWidth * CGFloat(page.image.height) / CGFloat(max(1, page.image.width))
                let bounds = CGRect(x: 0, y: 0, width: pageWidth, height: height)
                context.beginPage(withBounds: bounds, pageInfo: [:])
                UIImage(cgImage: page.image).draw(in: bounds)
                drawText(page.lines, in: bounds, context.cgContext)
            }
        }
    }

    private static func drawText(_ lines: [TextLine], in bounds: CGRect, _ cg: CGContext) {
        cg.saveGState()
        cg.setTextDrawingMode(.invisible)
        cg.textMatrix = .identity
        for line in lines {
            let rect = CGRect(x: bounds.minX + line.box.minX * bounds.width, y: bounds.minY + line.box.minY * bounds.height,
                              width: line.box.width * bounds.width, height: line.box.height * bounds.height)
            guard rect.width > 1, rect.height > 1 else { continue }
            let font = CTFontCreateWithName("Helvetica" as CFString, rect.height * 0.8, nil)
            let ctLine = CTLineCreateWithAttributedString(NSAttributedString(string: line.text, attributes: [.font: font]))
            let width = CTLineGetTypographicBounds(ctLine, nil, nil, nil)
            guard width > 0 else { continue }
            cg.saveGState()
            // The UIKit PDF context has y pointing down; text needs it pointing up.
            cg.translateBy(x: rect.minX, y: rect.maxY - rect.height * 0.2)
            cg.scaleBy(x: rect.width / width, y: -1)
            cg.textPosition = .zero
            CTLineDraw(ctLine, cg)
            cg.restoreGState()
        }
        cg.restoreGState()
    }
}

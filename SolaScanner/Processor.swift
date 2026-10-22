import Observation
import UIKit

/// Turns camera pages into saved PDFs: text recognition, Apple Intelligence, name, file.
@Observable
final class Processor {
    enum Phase: Equatable {
        case reading, thinking(Int, of: Int), saving, done, failed(String)
    }

    private(set) var phase = Phase.reading
    private(set) var saved: [ScanRecord] = []
    /// Set when the chosen folder couldn't be reached and the scans went into the app's folder.
    private(set) var fellBack: String?

    private let store: Store

    init(store: Store) {
        self.store = store
    }

    func run(_ images: [UIImage]) async {
        phase = .reading
        let pages = await PDFMaker.prepare(images)
        guard !pages.isEmpty else {
            phase = .failed(String(localized: "The pages couldn't be read."))
            return
        }
        let documents = store.splitPages ? pages.map { [$0] } : [pages]
        let useAI = store.useAI && Assistant.status == .ready

        for (index, document) in documents.enumerated() {
            let text = document.map(\.text).joined(separator: "\n\n")
            var info: DocumentInfo?
            if useAI {
                phase = .thinking(index + 1, of: documents.count)
                info = await Assistant.describe(text)
            }
            phase = .saving
            let now = Date()
            let name = FileName.make(store.template, .init(now: now, info: info, number: store.takeNumber()))
            let data = await PDFMaker.make(document, title: info?.title ?? name, info: info)
            do {
                let (folder, fileName) = try write(data, name: name)
                let record = ScanRecord(fileName: fileName, folderID: folder.id, folderName: folder.name, created: now,
                                        pages: document.count, text: String(text.prefix(20_000)), info: info)
                store.add(record)
                saved.append(record)
            } catch {
                phase = .failed(error.localizedDescription)
                return
            }
        }
        phase = .done
    }

    /// Writes into the current folder, or into the app's own folder if that fails, so no scan gets lost.
    private func write(_ data: Data, name: String) throws -> (Folder, String) {
        let folder = store.currentFolder
        if let url = store.resolve(folder), let fileName = try? Files.write(data, name: name, in: url) {
            return (folder, fileName)
        }
        guard !folder.isLocal else { throw Files.Failure.folderGone }
        fellBack = folder.name
        return (.local, try Files.write(data, name: name, in: Files.localFolder))
    }
}

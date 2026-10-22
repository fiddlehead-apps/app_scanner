#if DEBUG
import UIKit

/// A made-up letter as a camera page, to try the whole flow in the simulator (`-debugScreen sample`).
enum DebugSample {
    static func letter() -> UIImage {
        let size = CGSize(width: 1240, height: 1754)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            UIColor.white.setFill()
            UIRectFill(CGRect(origin: .zero, size: size))
            let lines: [(String, CGFloat, Bool)] = [
                ("Stadtwerke Musterstadt GmbH · Hafenstraße 12 · 12345 Musterstadt", 26, false),
                ("Familie Beispiel", 34, false),
                ("Lindenweg 3", 34, false),
                ("12345 Musterstadt", 34, false),
                ("Musterstadt, 14.10.2026", 34, false),
                ("Rechnung Nr. 2026-10-4471", 46, true),
                ("Stromlieferung 01.09.2026 bis 30.09.2026", 34, false),
                ("Verbrauch: 212 kWh", 34, false),
                ("Grundpreis: 12,90 €", 34, false),
                ("Arbeitspreis: 71,30 €", 34, false),
                ("Gesamtbetrag: 84,20 €", 38, true),
                ("Der Betrag wird am 28.10.2026 von Ihrem Konto abgebucht.", 34, false),
                ("Mit freundlichen Grüßen", 34, false),
                ("Ihre Stadtwerke Musterstadt", 34, false),
            ]
            var y: CGFloat = 120
            for (text, size, bold) in lines {
                let font = UIFont.systemFont(ofSize: size, weight: bold ? .bold : .regular)
                (text as NSString).draw(at: CGPoint(x: 110, y: y), withAttributes: [.font: font, .foregroundColor: UIColor.black])
                y += size * 2.2
            }
        }
    }
}
#endif

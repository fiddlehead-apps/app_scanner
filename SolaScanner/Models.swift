import Foundation
import SwiftUI

/// A folder scans are saved into. Without a bookmark it is the app's own folder
/// (Files → On My iPhone → Sola Scanner).
nonisolated struct Folder: Codable, Identifiable, Hashable, Sendable {
    var id = UUID()
    var name: String
    var bookmark: Data?

    static let local = Folder(id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!, name: "Sola Scanner")

    var isLocal: Bool { bookmark == nil }
}

/// What kind of paper a document is. Apple Intelligence picks one.
nonisolated enum DocumentKind: String, Codable, CaseIterable, Sendable {
    case invoice, receipt, letter, contract, statement, form, certificate, notice, manual, other

    var label: String {
        switch self {
        case .invoice: String(localized: "Invoice")
        case .receipt: String(localized: "Receipt")
        case .letter: String(localized: "Letter")
        case .contract: String(localized: "Contract")
        case .statement: String(localized: "Statement")
        case .form: String(localized: "Form")
        case .certificate: String(localized: "Certificate")
        case .notice: String(localized: "Notice")
        case .manual: String(localized: "Manual")
        case .other: String(localized: "Document")
        }
    }

    var symbol: String {
        switch self {
        case .invoice: "eurosign.circle"
        case .receipt: "receipt"
        case .letter: "envelope"
        case .contract: "signature"
        case .statement: "list.bullet.rectangle"
        case .form: "checklist"
        case .certificate: "rosette"
        case .notice: "building.columns"
        case .manual: "book.closed"
        case .other: "doc.text"
        }
    }
}

/// What Apple Intelligence read from a document. Empty strings mean "not found".
nonisolated struct DocumentInfo: Codable, Hashable, Sendable {
    var title: String
    var kind: DocumentKind
    var sender: String
    /// yyyy-MM-dd
    var date: String
    var amount: String
    var summary: String
    var keywords: [String]
}

/// One saved document, for the history on the start screen.
nonisolated struct ScanRecord: Codable, Identifiable, Hashable, Sendable {
    var id = UUID()
    var fileName: String
    var folderID: UUID
    var folderName: String
    var created: Date
    var pages: Int
    /// Recognized text, for searching the history.
    var text: String
    var info: DocumentInfo?
}

nonisolated struct SaveData: Codable, Sendable {
    var records: [ScanRecord]
    var folders: [Folder]
    var currentFolder: UUID
    var template: String
    var counter: Int
    var splitPages: Bool
    var useAI: Bool
}

/// Placeholders in the name template, e.g. "{Date} {Title}". English and German names both work.
nonisolated enum NameToken: CaseIterable, Sendable {
    case date, time, title, sender, kind, number

    var label: String {
        switch self {
        case .date: String(localized: "Date")
        case .time: String(localized: "Time")
        case .title: String(localized: "Title")
        case .sender: String(localized: "Sender")
        case .kind: String(localized: "Type")
        case .number: String(localized: "No.")
        }
    }

    var placeholder: String { "{\(label)}" }

    /// Whether the value comes from Apple Intelligence.
    var needsAI: Bool { self == .title || self == .sender || self == .kind }

    private var aliases: [String] {
        switch self {
        case .date: ["date", "datum"]
        case .time: ["time", "uhrzeit", "zeit"]
        case .title: ["title", "titel"]
        case .sender: ["sender", "absender", "from", "von"]
        case .kind: ["type", "kind", "art", "typ"]
        case .number: ["no.", "no", "nr.", "nr", "number", "nummer"]
        }
    }

    static func named(_ key: String) -> NameToken? {
        let key = key.trimmingCharacters(in: .whitespaces).lowercased()
        return allCases.first { $0.aliases.contains(key) || $0.label.lowercased() == key }
    }
}

/// Turns the name template into a file name (without ".pdf").
nonisolated enum FileName {
    static var defaultTemplate: String { "\(NameToken.date.placeholder) \(NameToken.title.placeholder)" }

    struct Values {
        var now: Date
        var info: DocumentInfo?
        var number: Int
        /// Used for {Title} when there is no title from Apple Intelligence.
        var fallbackTitle = "Scan"
    }

    static func make(_ template: String, _ values: Values) -> String {
        let name = fill(template, values)
        if !name.isEmpty { return name }
        return fill("Scan {date} {time}", values)
    }

    private static func fill(_ template: String, _ values: Values) -> String {
        var result = ""
        var rest = Substring(template)
        while let open = rest.firstIndex(of: "{") {
            result += rest[..<open]
            guard let close = rest[open...].firstIndex(of: "}") else {
                rest = rest[open...]
                break
            }
            let key = String(rest[rest.index(after: open)..<close])
            if let token = NameToken.named(key) {
                result += value(of: token, values)
            } else {
                result += rest[open...close]
            }
            rest = rest[rest.index(after: close)...]
        }
        result += rest
        return clean(result)
    }

    private static func value(of token: NameToken, _ values: Values) -> String {
        let info = values.info
        switch token {
        case .date:
            // The date printed on the document if Apple Intelligence found one, otherwise today.
            if let date = info?.date, !date.isEmpty { return date }
            return values.now.formatted(.iso8601.year().month().day())
        case .time:
            let parts = Calendar.current.dateComponents([.hour, .minute], from: values.now)
            return String(format: "%02d-%02d", parts.hour ?? 0, parts.minute ?? 0)
        case .title:
            if let title = info?.title, !title.isEmpty { return title }
            return values.fallbackTitle
        case .sender:
            return info?.sender ?? ""
        case .kind:
            return info?.kind.label ?? ""
        case .number:
            return String(format: "%03d", values.number)
        }
    }

    /// Removes characters that file systems don't like and the gaps left by empty placeholders.
    static func clean(_ name: String) -> String {
        var name = name
        for bad in ["/", "\\", ":"] { name = name.replacingOccurrences(of: bad, with: "-") }
        name = String(name.filter { !"?*\"<>|\n\r\t".contains($0) })
        while name.contains("  ") { name = name.replacingOccurrences(of: "  ", with: " ") }
        for gap in [" - - ", " -  - ", " _ _ ", ", , "] {
            while name.contains(gap) { name = name.replacingOccurrences(of: gap, with: String(gap.prefix(3))) }
        }
        name = name.trimmingCharacters(in: CharacterSet(charactersIn: " -_,.;"))
        return String(name.prefix(120)).trimmingCharacters(in: .whitespaces)
    }
}

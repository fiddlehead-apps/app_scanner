import Foundation
import FoundationModels

/// Reads facts from a document's text with Apple Intelligence's on-device model.
/// Nothing leaves the iPhone.
nonisolated enum Assistant {
    enum Status: Equatable {
        case ready, notEnabled, notReady, unsupported

        var message: String {
            switch self {
            case .ready:
                String(localized: "Apple Intelligence reads title, sender, date and amount. Runs on this iPhone.")
            case .notEnabled:
                String(localized: "Turn on Apple Intelligence in the Settings app to read facts from documents.")
            case .notReady:
                String(localized: "Apple Intelligence is still getting ready (downloading its model). Try again later.")
            case .unsupported:
                String(localized: "This iPhone doesn't support Apple Intelligence. Scans are saved with text recognition only.")
            }
        }
    }

    static var status: Status {
        switch SystemLanguageModel.default.availability {
        case .available: .ready
        case .unavailable(.appleIntelligenceNotEnabled): .notEnabled
        case .unavailable(.modelNotReady): .notReady
        case .unavailable: .unsupported
        }
    }

    private static let instructions = """
        You read the text of a scanned paper document (from text recognition, may contain errors) \
        and fill in facts for filing it. Use only information found in the text. Leave a field \
        empty when the text doesn't contain it. Write title, summary and keywords in the language \
        of the document.
        """

    /// nil when Apple Intelligence is off or the model couldn't handle the text.
    @concurrent static func describe(_ text: String) async -> DocumentInfo? {
        guard status == .ready, text.count >= 20 else { return nil }
        // The model has a small context; long documents are cut, and cut harder if it still doesn't fit.
        for limit in [6000, 2500] {
            do {
                let session = LanguageModelSession(instructions: instructions)
                let response = try await session.respond(
                    to: "Document text:\n\n\(text.prefix(limit))",
                    generating: Facts.self,
                    options: GenerationOptions(samplingMode: .greedy))
                return response.content.info
            } catch {
                continue
            }
        }
        return nil
    }
}

@Generable
nonisolated struct Facts {
    @Guide(description: "Short, specific title, 2 to 6 words: the kind of document plus its subject, taken from the text. Write a period as month and year, not as exact dates. No sender name or address, no file extension.")
    var title: String

    @Guide(description: "What kind of document this is.")
    var kind: Kind

    @Guide(description: "Company, authority or person who issued or sent the document, short form without legal suffix or address. Empty if unknown.")
    var sender: String

    @Guide(description: "The main date printed on the document (invoice date, letter date) as YYYY-MM-DD. Empty if there is none.")
    var date: String

    @Guide(description: "Total amount to pay or paid, with currency, e.g. '84,20 €'. Empty if there is none.")
    var amount: String

    @Guide(description: "One or two sentences on what the document is about and what the reader has to do, if anything.")
    var summary: String

    @Guide(description: "Specific keywords for finding the document later: topics, products, customer or contract numbers. Not generic words like date, amount or document.", .maximumCount(5))
    var keywords: [String]

    @Generable
    enum Kind {
        case invoice, receipt, letter, contract, statement, form, certificate, notice, manual, other
    }

    var info: DocumentInfo {
        let isDate = date.wholeMatch(of: /\d{4}-\d{2}-\d{2}/) != nil
        return DocumentInfo(
            title: FileName.clean(title),
            kind: DocumentKind(rawValue: "\(kind)") ?? .other,
            sender: sender.trimmingCharacters(in: .whitespacesAndNewlines),
            date: isDate ? date : "",
            amount: amount.trimmingCharacters(in: .whitespacesAndNewlines),
            summary: summary.trimmingCharacters(in: .whitespacesAndNewlines),
            keywords: keywords.map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty })
    }
}

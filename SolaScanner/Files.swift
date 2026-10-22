import Foundation

/// Reading and writing PDFs in a folder the user picked. Folders outside the app need
/// security-scoped access and file coordination (iCloud Drive and other file providers).
nonisolated enum Files {
    enum Failure: LocalizedError {
        case folderGone, nameTaken

        var errorDescription: String? {
            switch self {
            case .folderGone: String(localized: "The folder can't be reached anymore. Pick it again.")
            case .nameTaken: String(localized: "A file with this name already exists.")
            }
        }
    }

    /// The app's own folder, visible in Files under On My iPhone.
    static var localFolder: URL { URL.documentsDirectory }

    /// Writes the PDF and returns the file name. Adds " 2", " 3" … if the name is taken.
    static func write(_ data: Data, name: String, in folder: URL) throws -> String {
        try access(folder) {
            let fileName = freeName(for: name, in: folder)
            try coordinate(writing: folder.appending(path: fileName), options: .forReplacing) { url in
                try data.write(to: url, options: .atomic)
            }
            return fileName
        }
    }

    static func rename(_ fileName: String, to name: String, in folder: URL) throws -> String {
        try access(folder) {
            let source = folder.appending(path: fileName)
            let target = name + ".pdf"
            if target == fileName { return fileName }
            guard !exists(target, in: folder) || target.lowercased() == fileName.lowercased() else { throw Failure.nameTaken }
            try coordinate(writing: source, options: .forMoving) { url in
                try FileManager.default.moveItem(at: url, to: folder.appending(path: target))
            }
            return target
        }
    }

    static func delete(_ fileName: String, in folder: URL) throws {
        try access(folder) {
            try coordinate(writing: folder.appending(path: fileName), options: .forDeleting) { url in
                try FileManager.default.removeItem(at: url)
            }
        }
    }

    static func read(_ fileName: String, in folder: URL) throws -> Data {
        try access(folder) {
            var result: Result<Data, Error> = .failure(Failure.folderGone)
            var error: NSError?
            NSFileCoordinator().coordinate(readingItemAt: folder.appending(path: fileName), options: [], error: &error) { url in
                result = Result { try Data(contentsOf: url) }
            }
            if let error { throw error }
            return try result.get()
        }
    }

    private static func freeName(for name: String, in folder: URL) -> String {
        var fileName = name + ".pdf"
        var number = 2
        while exists(fileName, in: folder) {
            fileName = "\(name) \(number).pdf"
            number += 1
        }
        return fileName
    }

    /// Also counts files in iCloud Drive that are not downloaded (".name.pdf.icloud").
    private static func exists(_ fileName: String, in folder: URL) -> Bool {
        FileManager.default.fileExists(atPath: folder.appending(path: fileName).path(percentEncoded: false))
            || FileManager.default.fileExists(atPath: folder.appending(path: ".\(fileName).icloud").path(percentEncoded: false))
    }

    private static func access<T>(_ folder: URL, _ body: () throws -> T) throws -> T {
        let scoped = folder.startAccessingSecurityScopedResource()
        defer { if scoped { folder.stopAccessingSecurityScopedResource() } }
        guard FileManager.default.fileExists(atPath: folder.path(percentEncoded: false)) else { throw Failure.folderGone }
        return try body()
    }

    private static func coordinate(writing url: URL, options: NSFileCoordinator.WritingOptions,
                                   _ body: (URL) throws -> Void) throws {
        var error: NSError?
        var bodyError: Error?
        NSFileCoordinator().coordinate(writingItemAt: url, options: options, error: &error) { url in
            do { try body(url) } catch { bodyError = error }
        }
        if let error = error ?? bodyError { throw error }
    }
}

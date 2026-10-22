import Foundation
import Observation

/// Folders, the name template and the list of saved scans. Saved as JSON in Application Support,
/// so it doesn't show up next to the scans in the Files app.
@Observable
final class Store {
    private(set) var records: [ScanRecord] = []
    private(set) var folders: [Folder] = [.local]
    var currentFolderID = Folder.local.id { didSet { save() } }
    var template = FileName.defaultTemplate { didSet { save() } }
    var splitPages = false { didSet { save() } }
    var useAI = true { didSet { save() } }
    /// Next value for {No.}.
    private(set) var counter = 1

    private static var file: URL { URL.applicationSupportDirectory.appending(path: "scanner.json") }
    private var loading = false

    init() {
        guard let data = try? Data(contentsOf: Self.file) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let saved = try? decoder.decode(SaveData.self, from: data) else { return }
        loading = true
        records = saved.records
        folders = [.local] + saved.folders.filter { !$0.isLocal }
        currentFolderID = folders.contains { $0.id == saved.currentFolder } ? saved.currentFolder : Folder.local.id
        // The untouched default follows the device language ("{Date} {Title}" ↔ "{Datum} {Titel}").
        template = ["{Date} {Title}", "{Datum} {Titel}"].contains(saved.template) ? FileName.defaultTemplate : saved.template
        counter = saved.counter
        splitPages = saved.splitPages
        useAI = saved.useAI
        loading = false
    }

    private func save() {
        guard !loading else { return }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let saved = SaveData(records: records, folders: folders, currentFolder: currentFolderID, template: template,
                             counter: counter, splitPages: splitPages, useAI: useAI)
        guard let data = try? encoder.encode(saved) else { return }
        try? FileManager.default.createDirectory(at: URL.applicationSupportDirectory, withIntermediateDirectories: true)
        try? data.write(to: Self.file, options: [.atomic, .completeFileProtection])
    }

    // MARK: Folders

    var currentFolder: Folder { folder(currentFolderID) ?? .local }

    func folder(_ id: UUID) -> Folder? { folders.first { $0.id == id } }

    /// Adds a folder picked in the Files dialog and makes it the current one.
    func addFolder(_ url: URL) throws {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        let bookmark = try url.bookmarkData(options: .minimalBookmark)
        let name = (try? url.resourceValues(forKeys: [.localizedNameKey]).localizedName) ?? url.lastPathComponent
        if let index = folders.firstIndex(where: { !$0.isLocal && resolve($0) == url.standardizedFileURL }) {
            folders[index].bookmark = bookmark
            currentFolderID = folders[index].id
        } else {
            let folder = Folder(name: name, bookmark: bookmark)
            folders.append(folder)
            currentFolderID = folder.id
        }
        save()
    }

    func removeFolder(_ folder: Folder) {
        guard !folder.isLocal else { return }
        folders.removeAll { $0.id == folder.id }
        if currentFolderID == folder.id { currentFolderID = Folder.local.id }
        save()
    }

    /// The folder's location, nil if it is gone or no longer allowed.
    func resolve(_ folder: Folder) -> URL? {
        guard let bookmark = folder.bookmark else { return Files.localFolder }
        var stale = false
        guard let url = try? URL(resolvingBookmarkData: bookmark, bookmarkDataIsStale: &stale) else { return nil }
        if stale, let index = folders.firstIndex(where: { $0.id == folder.id }) {
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            if let fresh = try? url.bookmarkData(options: .minimalBookmark) {
                folders[index].bookmark = fresh
                save()
            }
        }
        return url.standardizedFileURL
    }

    // MARK: Scans

    /// Hands out the next {No.} value.
    func takeNumber() -> Int {
        defer { counter += 1; save() }
        return counter
    }

    func add(_ record: ScanRecord) {
        records.insert(record, at: 0)
        save()
    }

    func rename(_ record: ScanRecord, to name: String) throws -> ScanRecord {
        guard let folder = folder(record.folderID), let url = resolve(folder) else { throw Files.Failure.folderGone }
        let fileName = try Files.rename(record.fileName, to: FileName.clean(name), in: url)
        guard let index = records.firstIndex(where: { $0.id == record.id }) else { return record }
        records[index].fileName = fileName
        save()
        return records[index]
    }

    /// Removes the scan from the list; with `deleteFile` also the PDF.
    func remove(_ record: ScanRecord, deleteFile: Bool) {
        if deleteFile, let folder = folder(record.folderID), let url = resolve(folder) {
            try? Files.delete(record.fileName, in: url)
        }
        records.removeAll { $0.id == record.id }
        save()
    }

    func clearHistory() {
        records = []
        save()
    }

    /// The scan's PDF, nil if the file was moved or deleted.
    func data(of record: ScanRecord) -> Data? {
        guard let folder = folder(record.folderID), let url = resolve(folder) else { return nil }
        return try? Files.read(record.fileName, in: url)
    }
}

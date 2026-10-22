import PDFKit
import SwiftUI

/// One saved scan: preview, facts, recognized text.
struct DocumentView: View {
    let store: Store
    let id: UUID
    @Environment(\.dismiss) private var dismiss
    @State private var pdf: PDFDocument?
    @State private var shareURL: URL?
    @State private var missing = false
    @State private var renaming: ScanRecord?
    @State private var confirmDelete = false

    private var record: ScanRecord? { store.records.first { $0.id == id } }

    var body: some View {
        ScrollView {
            if let record {
                VStack(spacing: 16) {
                    preview
                    VStack(alignment: .leading, spacing: 8) {
                        Text(record.fileName)
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(Color.ink)
                        Label(record.folderName, systemImage: "folder")
                        Text("\(record.created.formatted(date: .long, time: .shortened)) · \(String(localized: "\(record.pages) pages"))")
                    }
                    .font(.system(size: 14))
                    .foregroundStyle(Color.muted)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .card()
                    if let info = record.info {
                        InfoGrid(info: info).card()
                    }
                    if !record.text.isEmpty {
                        DisclosureGroup("Recognized text") {
                            Text(record.text)
                                .font(.system(size: 14))
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.top, 8)
                        }
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.ink)
                        .card()
                    }
                }
                .padding(20)
            }
        }
        .background(Color.bg)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if let shareURL {
                ToolbarItem(placement: .primaryAction) {
                    ShareLink(item: shareURL)
                }
            }
            ToolbarItem(placement: .primaryAction) {
                Menu("More", systemImage: "ellipsis") {
                    Button("Rename", systemImage: "pencil") { renaming = record }
                        .disabled(missing)
                    Button("Remove from list", systemImage: "minus.circle") {
                        if let record { store.remove(record, deleteFile: false) }
                        dismiss()
                    }
                    Button("Delete file", systemImage: "trash", role: .destructive) { confirmDelete = true }
                        .disabled(missing)
                }
            }
        }
        .renameAlert(item: $renaming, store: store)
        .confirmationDialog("The PDF is deleted from its folder.", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete file", role: .destructive) {
                if let record { store.remove(record, deleteFile: true) }
                dismiss()
            }
        }
        .task(id: record?.fileName) { load() }
    }

    @ViewBuilder
    private var preview: some View {
        if let pdf {
            PDFPreview(document: pdf)
                .frame(height: 440)
                .clipShape(.rect(cornerRadius: 16))
                .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Color.line, lineWidth: 1.5))
        } else if missing {
            Label("The file is no longer in its folder. It may have been moved, renamed or deleted in the Files app.",
                  systemImage: "questionmark.folder")
                .font(.system(size: 14))
                .foregroundStyle(Color.muted)
                .frame(maxWidth: .infinity, alignment: .leading)
                .card()
        }
    }

    private func load() {
        guard let record else { return }
        guard let data = store.data(of: record), let document = PDFDocument(data: data) else {
            missing = true
            pdf = nil
            shareURL = nil
            return
        }
        missing = false
        pdf = document
        // Sharing needs a plain file; the original may sit in a folder only this app may open.
        let dir = URL.temporaryDirectory.appending(path: record.id.uuidString, directoryHint: .isDirectory)
        try? FileManager.default.removeItem(at: dir)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appending(path: record.fileName)
        shareURL = (try? data.write(to: url)) != nil ? url : nil
    }
}

struct PDFPreview: UIViewRepresentable {
    let document: PDFDocument

    func makeUIView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.displayMode = .singlePageContinuous
        view.backgroundColor = .secondarySystemBackground
        return view
    }

    func updateUIView(_ view: PDFView, context: Context) {
        if view.document !== document { view.document = document }
    }
}

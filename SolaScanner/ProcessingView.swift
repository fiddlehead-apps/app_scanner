import SwiftUI

/// Shown right after scanning: progress, then where the document went and what was read from it.
struct ProcessingView: View {
    let processor: Processor
    let store: Store
    let scanAgain: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var renaming: ScanRecord?

    private var working: Bool {
        switch processor.phase {
        case .done, .failed: false
        default: true
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    switch processor.phase {
                    case .reading:
                        progress("Reading the text…")
                    case .thinking(let index, let count):
                        progress(count > 1 ? "Apple Intelligence is reading document \(index) of \(count)…"
                                           : "Apple Intelligence is reading the document…")
                    case .saving:
                        progress("Saving…")
                    case .failed(let message):
                        failed(message)
                    case .done:
                        done
                    }
                }
                .padding(20)
            }
            .background(Color.bg)
            .navigationTitle(working ? "" : String(localized: "Saved"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if !working {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { dismiss() }
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                if processor.phase == .done, DocumentCamera.isSupported {
                    Button {
                        scanAgain()
                        dismiss()
                    } label: {
                        Label("Scan next document", systemImage: "doc.viewfinder")
                    }
                    .buttonStyle(BigButtonStyle(primary: true))
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background { Color.bg.ignoresSafeArea() }
                }
            }
            .renameAlert(item: $renaming, store: store)
        }
        .interactiveDismissDisabled(working)
    }

    private func progress(_ text: LocalizedStringKey) -> some View {
        VStack(spacing: 16) {
            ProgressView()
                .controlSize(.large)
            Text(text)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Color.muted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 160)
    }

    private func failed(_ message: String) -> some View {
        VStack(spacing: 14) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 44))
                .foregroundStyle(Color.danger)
            Text("Not saved")
                .font(.system(size: 22, weight: .bold))
            Text(message)
                .foregroundStyle(Color.muted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 120)
    }

    private var done: some View {
        VStack(spacing: 14) {
            if let folder = processor.fellBack {
                Label("“\(folder)” couldn't be reached, so the scan went into the Sola Scanner folder. Pick the folder again in the settings.",
                      systemImage: "exclamationmark.triangle")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.danger)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .card()
            }
            ForEach(processor.saved) { saved in
                let record = store.records.first { $0.id == saved.id } ?? saved
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 26))
                            .foregroundStyle(Color.good)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(record.fileName)
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(Color.ink)
                            Label(record.folderName, systemImage: "folder")
                                .font(.system(size: 14))
                                .foregroundStyle(Color.muted)
                        }
                        Spacer(minLength: 0)
                    }
                    if let info = record.info {
                        Divider()
                        InfoGrid(info: info)
                    }
                    HStack {
                        Button("Rename", systemImage: "pencil") { renaming = record }
                        Spacer()
                        NavigationLink { DocumentView(store: store, id: record.id) } label: {
                            Label("Show", systemImage: "doc.text.magnifyingglass")
                        }
                    }
                    .font(.system(size: 15, weight: .semibold))
                }
                .card()
            }
        }
    }
}

/// The facts Apple Intelligence found.
struct InfoGrid: View {
    let info: DocumentInfo

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 12, verticalSpacing: 6) {
                row("Type", info.kind.label)
                row("Sender", info.sender)
                row("Date", formattedDate)
                row("Amount", info.amount)
            }
            if !info.summary.isEmpty {
                Text(info.summary)
                    .font(.system(size: 15))
                    .foregroundStyle(Color.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if !info.keywords.isEmpty {
                FlowLayout(spacing: 6, lineSpacing: 6) {
                    ForEach(info.keywords, id: \.self) { keyword in
                        Text(keyword)
                            .font(.system(size: 13, weight: .medium))
                            .padding(.horizontal, 10)
                            .frame(height: 26)
                            .foregroundStyle(Color.brand)
                            .background(Color.brandSoft, in: .capsule)
                    }
                }
            }
            Label("Read by Apple Intelligence, may contain mistakes.", systemImage: "sparkles")
                .font(.system(size: 12))
                .foregroundStyle(Color.muted)
        }
    }

    private var formattedDate: String {
        guard let date = try? Date(info.date, strategy: .iso8601.year().month().day()) else { return info.date }
        return date.formatted(date: .long, time: .omitted)
    }

    @ViewBuilder
    private func row(_ label: LocalizedStringKey, _ value: String) -> some View {
        if !value.isEmpty {
            GridRow {
                Text(label)
                    .font(.system(size: 14))
                    .foregroundStyle(Color.muted)
                Text(value)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Color.ink)
            }
        }
    }
}

extension View {
    /// Asks for a new file name and renames the PDF in its folder.
    func renameAlert(item: Binding<ScanRecord?>, store: Store) -> some View {
        modifier(RenameAlert(item: item, store: store))
    }
}

private struct RenameAlert: ViewModifier {
    @Binding var item: ScanRecord?
    let store: Store
    @State private var name = ""
    @State private var error: String?

    func body(content: Content) -> some View {
        content
            .alert("Rename", isPresented: Binding(get: { item != nil }, set: { if !$0 { item = nil } })) {
                TextField("Name", text: $name)
                Button("Cancel", role: .cancel) { item = nil }
                Button("Rename") {
                    if let record = item {
                        do { _ = try store.rename(record, to: name) } catch { self.error = error.localizedDescription }
                    }
                    item = nil
                }
            }
            .alert("Couldn't rename", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
                Button("OK") { error = nil }
            } message: {
                Text(error ?? "")
            }
            .onChange(of: item) { _, record in
                if let record { name = String(record.fileName.dropLast(record.fileName.hasSuffix(".pdf") ? 4 : 0)) }
            }
    }
}

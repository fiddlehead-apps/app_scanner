import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @Bindable var store: Store
    @Environment(\.dismiss) private var dismiss
    @State private var pickFolder = false
    @State private var confirmClear = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    ForEach(store.folders) { folder in
                        Button { store.currentFolderID = folder.id } label: {
                            HStack {
                                Label(folder.name, systemImage: folder.isLocal ? "iphone" : "folder")
                                    .foregroundStyle(Color.ink)
                                Spacer()
                                if folder.id == store.currentFolderID {
                                    Image(systemName: "checkmark").foregroundStyle(Color.brand)
                                }
                            }
                        }
                        .deleteDisabled(folder.isLocal)
                    }
                    .onDelete { offsets in
                        offsets.map { store.folders[$0] }.forEach(store.removeFolder)
                    }
                    Button("Add folder…", systemImage: "folder.badge.plus") { pickFolder = true }
                } header: {
                    Text("Folders")
                } footer: {
                    Text("Any folder from the Files app works, also on a USB stick or in iCloud Drive. iOS syncs folders in iCloud Drive like any other file there; the app itself uploads nothing. Swipe to remove a folder from the list, the files stay.")
                }

                Section {
                    LabeledContent("Scans", value: "\(store.records.count)")
                    Button("Clear list", role: .destructive) { confirmClear = true }
                        .disabled(store.records.isEmpty)
                } header: {
                    Text("Recent scans")
                } footer: {
                    Text("Text recognition and Apple Intelligence run on this iPhone. No account, no server, nothing leaves the device.")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .fileImporter(isPresented: $pickFolder, allowedContentTypes: [.folder]) { result in
                do { try store.addFolder(result.get()) } catch { self.error = error.localizedDescription }
            }
            .confirmationDialog("The list on the start screen is emptied. The PDFs stay in their folders.",
                                isPresented: $confirmClear, titleVisibility: .visible) {
                Button("Clear list", role: .destructive) { store.clearHistory() }
            }
            .alert("Couldn't add the folder", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
                Button("OK") { error = nil }
            } message: {
                Text(error ?? "")
            }
        }
    }
}

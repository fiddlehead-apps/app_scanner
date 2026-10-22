import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

extension Processor: Identifiable {}

struct HomeView: View {
    @Bindable var store: Store
    @Environment(\.scenePhase) private var scenePhase
    @State private var aiStatus = Assistant.status
    @State private var showCamera = false
    @State private var showSettings = false
    @State private var pickFolder = false
    @State private var photos: [PhotosPickerItem] = []
    /// Pages from the camera, processed once the camera is gone.
    @State private var captured: [UIImage] = []
    @State private var processor: Processor?
    @State private var scanAgain = false
    @State private var search = ""
    @State private var error: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    header
                    folderCard
                    nameCard
                    optionsCard
                    history
                }
                .padding(20)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Color.bg)
            .toolbar(.hidden, for: .navigationBar)
            .safeAreaInset(edge: .bottom) { scanButtons }
        }
        .fullScreenCover(isPresented: $showCamera, onDismiss: startProcessing) {
            DocumentCamera { images in
                captured = images
                showCamera = false
            }
            .ignoresSafeArea()
        }
        .sheet(item: $processor, onDismiss: {
            if scanAgain { scanAgain = false; showCamera = true }
        }) { processor in
            ProcessingView(processor: processor, store: store) { scanAgain = true }
        }
        .sheet(isPresented: $showSettings) { SettingsView(store: store) }
        .fileImporter(isPresented: $pickFolder, allowedContentTypes: [.folder]) { result in
            do { try store.addFolder(result.get()) } catch { self.error = error.localizedDescription }
        }
        .onChange(of: photos) { _, items in importPhotos(items) }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { aiStatus = Assistant.status }
        }
        .alert("Couldn't add the folder", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
            Button("OK") { error = nil }
        } message: {
            Text(error ?? "")
        }
        #if DEBUG
        .task { openDebugScreen() }
        #endif
    }

    private var aiReady: Bool { aiStatus == .ready && store.useAI }

    private var header: some View {
        HStack {
            Text("Sola Scanner")
                .font(.system(size: 30, weight: .bold))
                .foregroundStyle(Color.ink)
            Spacer()
            CircleIconButton(systemImage: "gearshape", label: "Settings") { showSettings = true }
        }
    }

    // MARK: Folder

    private var folderCard: some View {
        Menu {
            Picker("Folder", selection: $store.currentFolderID) {
                ForEach(store.folders) { folder in
                    Label(folder.name, systemImage: folder.isLocal ? "iphone" : "folder").tag(folder.id)
                }
            }
            Button("Choose another folder…", systemImage: "folder.badge.plus") { pickFolder = true }
        } label: {
            HStack(spacing: 14) {
                Image(systemName: store.currentFolder.isLocal ? "iphone" : "folder.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(Color.brand)
                    .frame(width: 44, height: 44)
                    .background(Color.brandSoft, in: .rect(cornerRadius: 12))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Save to")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.muted)
                    Text(store.currentFolder.name)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Color.ink)
                        .lineLimit(1)
                    if store.currentFolder.isLocal {
                        Text("Files app → On My iPhone")
                            .font(.system(size: 13))
                            .foregroundStyle(Color.muted)
                    }
                }
                Spacer()
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.muted)
            }
            .card(padding: 14)
        }
        .buttonStyle(PressStyle())
    }

    // MARK: Name

    private var nameCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("File name").sectionTitle()
                if store.template != FileName.defaultTemplate {
                    Button("Reset") { store.template = FileName.defaultTemplate }
                        .font(.system(size: 14, weight: .semibold))
                }
            }
            TextField("Name, e.g. Tax 2026", text: $store.template)
                .font(.system(size: 17))
                .autocorrectionDisabled()
                .submitLabel(.done)
                .padding(12)
                .background(Color.bg, in: .rect(cornerRadius: 12))
            FlowLayout(spacing: 8, lineSpacing: 8) {
                ForEach(NameToken.allCases, id: \.self) { token in
                    Button { insert(token) } label: {
                        HStack(spacing: 4) {
                            if token.needsAI { Image(systemName: "sparkles").font(.system(size: 11, weight: .bold)) }
                            Text(token.label)
                        }
                        .font(.system(size: 14, weight: .semibold))
                        .padding(.horizontal, 12)
                        .frame(height: 32)
                        .foregroundStyle(Color.brand)
                        .background(Color.brandSoft, in: .capsule)
                        .opacity(token.needsAI && !aiReady ? 0.5 : 1)
                    }
                    .buttonStyle(PressStyle())
                }
            }
            Text("Example: \(preview)")
                .font(.system(size: 14))
                .foregroundStyle(Color.muted)
            if !aiReady, NameToken.allCases.contains(where: { $0.needsAI && store.template.localizedCaseInsensitiveContains($0.placeholder) }) {
                Text("Without Apple Intelligence, Title becomes “Scan”, Sender and Type stay empty.")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.muted)
            }
        }
        .card()
    }

    private var preview: String {
        let sample = DocumentInfo(title: String(localized: "Electricity bill October"), kind: .invoice,
                                  sender: String(localized: "City Power"), date: "", amount: "", summary: "", keywords: [])
        return FileName.make(store.template, .init(now: .now, info: aiReady ? sample : nil, number: store.counter)) + ".pdf"
    }

    private func insert(_ token: NameToken) {
        let text = store.template
        store.template = text.isEmpty || text.hasSuffix(" ") ? text + token.placeholder : text + " " + token.placeholder
    }

    // MARK: Options

    private var optionsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Toggle(isOn: $store.splitPages) {
                Label("Each page is its own document", systemImage: "doc.on.doc")
            }
            Divider()
            Toggle(isOn: Binding(get: { aiReady }, set: { store.useAI = $0 })) {
                Label("Apple Intelligence", systemImage: "sparkles")
            }
            .disabled(aiStatus != .ready)
            Text(aiStatus == .ready && !store.useAI
                 ? String(localized: "Off: scans are saved with text recognition only.")
                 : aiStatus.message)
                .font(.system(size: 13))
                .foregroundStyle(Color.muted)
        }
        .font(.system(size: 16, weight: .medium))
        .foregroundStyle(Color.ink)
        .card()
    }

    // MARK: Scan

    private var scanButtons: some View {
        HStack(spacing: 12) {
            if DocumentCamera.isSupported {
                Button { showCamera = true } label: {
                    Label("Scan", systemImage: "doc.viewfinder")
                }
                .buttonStyle(BigButtonStyle(primary: true))
            }
            PhotosPicker(selection: $photos, maxSelectionCount: 20, matching: .images) {
                Label("Photos", systemImage: "photo.on.rectangle")
            }
            .buttonStyle(BigButtonStyle(primary: !DocumentCamera.isSupported))
            .frame(maxWidth: DocumentCamera.isSupported ? 150 : .infinity)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background { Color.bg.ignoresSafeArea() }
    }

    private func startProcessing() {
        guard !captured.isEmpty else { return }
        let images = captured
        captured = []
        process(images)
    }

    private func process(_ images: [UIImage]) {
        let processor = Processor(store: store)
        self.processor = processor
        Task { await processor.run(images) }
    }

    private func importPhotos(_ items: [PhotosPickerItem]) {
        guard !items.isEmpty else { return }
        photos = []
        Task {
            var images: [UIImage] = []
            for item in items {
                if let data = try? await item.loadTransferable(type: Data.self), let image = UIImage(data: data) {
                    images.append(image)
                }
            }
            if !images.isEmpty { process(images) }
        }
    }

    // MARK: History

    private var filtered: [ScanRecord] {
        let query = search.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return store.records }
        return store.records.filter { record in
            [record.fileName, record.text, record.info?.sender ?? "", record.info?.summary ?? "",
             record.info?.keywords.joined(separator: " ") ?? ""]
                .contains { $0.localizedStandardContains(query) }
        }
    }

    @ViewBuilder
    private var history: some View {
        if store.records.isEmpty {
            Label {
                Text("Choose a folder and a name, then tap Scan. The camera finds the page on its own and takes the picture. Each scan becomes a searchable PDF in the folder.")
            } icon: {
                Image(systemName: "lightbulb")
            }
            .font(.system(size: 14))
            .foregroundStyle(Color.muted)
            .frame(maxWidth: .infinity, alignment: .leading)
            .card()
        } else {
            VStack(spacing: 10) {
                Text("Recent scans").sectionTitle()
                    .padding(.top, 6)
                if store.records.count > 4 {
                    HStack {
                        Image(systemName: "magnifyingglass").foregroundStyle(Color.muted)
                        TextField("Search name and text", text: $search)
                            .autocorrectionDisabled()
                    }
                    .padding(12)
                    .background(Color.surface, in: .rect(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.line, lineWidth: 1.5))
                }
                LazyVStack(spacing: 10) {
                    ForEach(filtered) { record in
                        NavigationLink { DocumentView(store: store, id: record.id) } label: {
                            RecordRow(record: record)
                        }
                        .buttonStyle(PressStyle())
                    }
                }
            }
        }
    }

    #if DEBUG
    /// For screenshots in the simulator: `-debugScreen settings` or `sample` (scans a generated letter).
    private func openDebugScreen() {
        switch UserDefaults.standard.string(forKey: "debugScreen") {
        case "settings": showSettings = true
        case "sample": process([DebugSample.letter()])
        default: break
        }
    }
    #endif
}

struct RecordRow: View {
    let record: ScanRecord

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: record.info?.kind.symbol ?? "doc.text")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Color.brand)
                .frame(width: 40, height: 40)
                .background(Color.brandSoft, in: .rect(cornerRadius: 10))
            VStack(alignment: .leading, spacing: 3) {
                Text(record.fileName)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.ink)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                Text("\(record.folderName) · \(record.created.formatted(date: .abbreviated, time: .shortened)) · \(pagesText)")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.muted)
                    .lineLimit(1)
                if let summary = record.info?.summary, !summary.isEmpty {
                    Text(summary)
                        .font(.system(size: 13))
                        .foregroundStyle(Color.muted)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.muted)
        }
        .card(padding: 12)
    }

    private var pagesText: String { String(localized: "\(record.pages) pages") }
}

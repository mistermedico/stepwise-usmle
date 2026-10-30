import SwiftUI
import UniformTypeIdentifiers

struct FlashcardsView: View {
    @EnvironmentObject private var store: StudyStore
    @State private var moduleID = -1
    @State private var index = 0
    @State private var flipped = false
    private var pool: [StudyUnit] { store.curriculum.units.filter { moduleID == -1 || $0.topic == moduleID } }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Picker("Module", selection: $moduleID) {
                    Text("All modules").tag(-1)
                    ForEach(store.curriculum.modules) { Text($0.title).tag($0.id) }
                }.pickerStyle(.menu)
                if !pool.isEmpty {
                    let unit = pool[min(index, pool.count - 1)]
                    Text("Card \(min(index + 1, pool.count)) of \(pool.count)").font(.caption).foregroundStyle(.secondary)
                    Button { flipped.toggle() } label: {
                        VStack(alignment: .leading, spacing: 20) {
                            Text(flipped ? "ANSWER & MECHANISM" : "IDENTIFY THE CONCEPT AND EXPLAIN WHY").font(.caption.bold()).foregroundStyle(Theme.pale)
                            if flipped { Text(unit.title).font(.title2.bold()); Text(unit.mechanism) }
                            else { Text(unit.case).font(.title3) }
                            Label("Tap to flip", systemImage: "arrow.triangle.2.circlepath").font(.caption)
                        }.padding(24).frame(maxWidth: .infinity, minHeight: 300, alignment: .leading).foregroundStyle(.white).background(Theme.dark, in: RoundedRectangle(cornerRadius: 20))
                    }.buttonStyle(.plain).accessibilityIdentifier("flashcard")
                    if flipped { Text(unit.pitfall).padding().background(Theme.pale.opacity(0.3), in: RoundedRectangle(cornerRadius: 12)) }
                    HStack {
                        Button("Previous", systemImage: "arrow.left") { move(-1) }.buttonStyle(.bordered)
                        Spacer()
                        Button("Next", systemImage: "arrow.right") { move(1) }.buttonStyle(.borderedProminent)
                    }
                    NavigationLink("Open learning unit") { UnitDetailView(unit: unit) }
                }
            }.padding(20).frame(maxWidth: 800).frame(maxWidth: .infinity)
        }.navigationTitle("Flashcards").onChange(of: moduleID) { _, _ in index = 0; flipped = false }
    }
    private func move(_ delta: Int) { guard !pool.isEmpty else { return }; index = (index + delta + pool.count) % pool.count; flipped = false }
}

struct ProgressViewScreen: View {
    @EnvironmentObject private var store: StudyStore
    @State private var confirmReset = false
    @State private var exporting = false
    @State private var document = ProgressDocument(data: Data())
    @State private var exportError: String?
    var body: some View {
        List {
            Section("On this device") {
                LabeledContent("Units completed", value: "\(store.progress.completed.count)/240")
                LabeledContent("Questions attempted", value: "\(store.progress.answers.count)/480")
                LabeledContent("Latest-answer accuracy", value: "\(store.accuracy)%")
                LabeledContent("Completed sessions", value: "\(store.progress.sessions)")
                Text("These are study activity measures, not a validated estimate of exam readiness.").font(.caption).foregroundStyle(.secondary)
            }
            Section("Module completion") {
                ForEach(store.curriculum.modules) { module in
                    NavigationLink { ModuleDetailView(module: module) } label: {
                        VStack(alignment: .leading, spacing: 7) { Text(module.title); ProgressView(value: Double(store.completed(in: module)), total: 20); Text("\(store.completed(in: module))/20 complete").font(.caption).foregroundStyle(.secondary) }
                    }
                }
            }
            Section("Saved units") {
                let saved = store.curriculum.units.filter { store.progress.bookmarks.contains($0.id) }
                if saved.isEmpty { Text("Save units using the bookmark button while studying.").foregroundStyle(.secondary) }
                ForEach(saved) { unit in NavigationLink { UnitDetailView(unit: unit) } label: { UnitRow(unit: unit) } }
            }
            Section("Your data") {
                Text("Progress, bookmarks, and reviewer notes stay on this device. There is no account or cloud sync. Uninstalling the app or resetting progress removes local records.").font(.caption)
                Button("Export progress and review notes") {
                    do { document = ProgressDocument(data: try store.exportData()); exporting = true }
                    catch { exportError = error.localizedDescription }
                }
                Button("Reset all local progress", role: .destructive) { confirmReset = true }
            }
        }.navigationTitle("Your progress")
        .confirmationDialog("Delete all local progress and notes?", isPresented: $confirmReset, titleVisibility: .visible) { Button("Delete local data", role: .destructive) { store.reset() }; Button("Cancel", role: .cancel) {} }
        .fileExporter(isPresented: $exporting, document: document, contentType: .json, defaultFilename: "CardioFocus-progress") { result in if case .failure(let error) = result { exportError = error.localizedDescription } }
        .alert("Export unavailable", isPresented: Binding(get: { exportError != nil }, set: { if !$0 { exportError = nil } })) { Button("OK") { exportError = nil } } message: { Text(exportError ?? "") }
    }
}

struct ProgressDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var data: Data
    init(data: Data) { self.data = data }
    init(configuration: ReadConfiguration) throws { data = configuration.file.regularFileContents ?? Data() }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper { FileWrapper(regularFileWithContents: data) }
}

struct AboutView: View {
    @EnvironmentObject private var store: StudyStore
    var body: some View {
        List {
            Section("CardioFocus") {
                Text("Step 1 cardiology, one concept at a time.").font(.headline)
                Text("240 units across 12 modules, 480 paired questions, and 240 recall cards. Each pair revisits one concept through case recognition and mechanistic explanation. The complete curriculum is bundled for offline study.")
                Text("Version 1.0 · English · Free educational study aid").font(.caption).foregroundStyle(.secondary)
            }
            Section("Medical scope") {
                Text("For educational preparation only. Not medical advice, diagnosis, or treatment. Not affiliated with USMLE or NBME. Independent expert review and complete item-level source verification are pending. Use alongside current preparation materials and official practice resources.")
                Text("This app is not a complete exam curriculum, a diagnostic ECG or pathology-image bank, or a validated readiness assessment.")
            }
            Section("Sources and references") {
                ForEach(store.curriculum.references) { reference in
                    if let url = URL(string: reference.url) {
                        VStack(alignment: .leading, spacing: 5) {
                            Link(reference.title, destination: url)
                            Text(reference.role).font(.caption).foregroundStyle(.secondary)
                        }.padding(.vertical, 5)
                    }
                }
            }
            Section("Privacy and support") {
                Text("No sign-in, ads, tracking, or analytics SDK. Study records stay on your device. Export is initiated by you. Opening an external reference, support, or policy link uses your browser and the destination site's own privacy rules.")
                if let url = Bundle.main.url(forResource: "privacy", withExtension: "txt"), let text = try? String(contentsOf: url, encoding: .utf8) {
                    NavigationLink("Read privacy policy") { ScrollView { Text(text).padding(20).frame(maxWidth: 800, alignment: .leading).frame(maxWidth: .infinity) }.navigationTitle("Privacy policy").navigationBarTitleDisplayMode(.inline) }
                }
                if let support = Bundle.main.object(forInfoDictionaryKey: "CardioFocusSupportURL") as? String, let url = URL(string: support), url.scheme == "https" { Link("Contact support", destination: url) }
                Text("Question feedback can be saved during practice and included in an exported progress file. No feedback is transmitted automatically.").font(.caption)
            }
        }.navigationTitle("About & sources")
    }
}

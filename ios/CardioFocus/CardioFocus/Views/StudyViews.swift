import SwiftUI

struct StudyHomeView: View {
    @EnvironmentObject private var store: StudyStore
    @State private var search = ""
    private var matches: [StudyUnit] {
        store.curriculum.units.filter { unit in
            [unit.title, unit.mechanism, unit.case, unit.pitfall].joined(separator: " ").localizedCaseInsensitiveContains(search)
        }
    }
    var body: some View {
        List {
            if search.isEmpty {
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("KNOW THE HEART. UNDERSTAND WHY.").font(.caption.weight(.semibold))
                        Text("Learn the mechanism.\nConnect it to the case.").font(.title2.bold())
                        Text("240 focused units · 480 paired questions\n12 modules · Fully bundled for offline study").font(.subheadline)
                        if let next = store.curriculum.units.first(where: { !store.progress.completed.contains($0.id) }) {
                            NavigationLink { UnitDetailView(unit: next) } label: { Label("Continue learning", systemImage: "arrow.right.circle.fill") }
                                .buttonStyle(.borderedProminent).tint(.white).foregroundStyle(Theme.dark)
                                .accessibilityIdentifier("continueLearning")
                        }
                    }.padding(.vertical, 12).foregroundStyle(.white)
                }.listRowBackground(Theme.dark)
                Section("Your learning path") {
                    ForEach(store.curriculum.modules) { module in
                        NavigationLink { ModuleDetailView(module: module) } label: {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(module.title).font(.headline)
                                Text("\(store.completed(in: module))/20 units complete · 40 questions").font(.caption).foregroundStyle(.secondary)
                                ProgressView(value: Double(store.completed(in: module)), total: 20)
                                    .accessibilityLabel("Module completion")
                            }.padding(.vertical, 6)
                        }.accessibilityIdentifier("module-\(module.id)")
                    }
                }
            } else {
                Section("\(matches.count) matching units") {
                    ForEach(matches) { unit in NavigationLink { UnitDetailView(unit: unit) } label: { UnitRow(unit: unit) } }
                }
            }
            Section {
                Text("Independent educational study aid. Not affiliated with USMLE or NBME. Content awaits independent medical expert review; practice scores do not measure exam readiness.").font(.caption).foregroundStyle(.secondary)
            }
        }
        .navigationTitle("CardioFocus")
        .searchable(text: $search, prompt: "Search 240 units")
    }
}

struct UnitRow: View {
    @EnvironmentObject private var store: StudyStore
    let unit: StudyUnit
    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 5) {
                Text(unit.title).font(.headline)
                Text("Unit \(unit.number) · 2 paired questions").font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if store.progress.completed.contains(unit.id) { Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.green).accessibilityLabel("Completed") }
            if store.progress.bookmarks.contains(unit.id) { Image(systemName: "bookmark.fill").foregroundStyle(Theme.green).accessibilityLabel("Saved") }
        }.padding(.vertical, 4)
    }
}

struct ModuleDetailView: View {
    @EnvironmentObject private var store: StudyStore
    let module: StudyModule
    @State private var session: PracticeSession?
    var body: some View {
        List {
            Section {
                Text(module.description)
                Button("Practice this module") {
                    let pool = store.curriculum.questions.filter { $0.topic == module.id }
                    session = PracticeSession(questions: PracticeSession.sample(pool, count: 20), timed: false)
                }.buttonStyle(.borderedProminent)
            }
            Section("20 learning units") {
                ForEach(module.unitIds.compactMap(store.curriculum.unit)) { unit in
                    NavigationLink { UnitDetailView(unit: unit) } label: { UnitRow(unit: unit) }
                }
            }
        }
        .navigationTitle(module.title).navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(item: $session) { PracticeView(session: $0) }
    }
}

struct UnitDetailView: View {
    @EnvironmentObject private var store: StudyStore
    let unit: StudyUnit
    @State private var session: PracticeSession?
    @State private var revealRecall = false
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text(store.curriculum.module(unit.topic)?.title ?? "Cardiology").font(.caption).foregroundStyle(.secondary)
                Text(unit.title).font(.largeTitle.bold()).accessibilityAddTraits(.isHeader)
                Text(unit.objective).font(.subheadline).foregroundStyle(.secondary)
                LessonSection(title: "Core mechanism", text: unit.mechanism)
                LessonSection(title: "Teaching case", text: unit.case)
                VStack(alignment: .leading, spacing: 8) {
                    Label("Avoid the common trap", systemImage: "lightbulb").font(.headline)
                    Text(unit.pitfall)
                }.padding().frame(maxWidth: .infinity, alignment: .leading).background(Theme.pale.opacity(0.35), in: RoundedRectangle(cornerRadius: 14))
                VStack(alignment: .leading, spacing: 12) {
                    Text("Retrieve before you reread").font(.title3.bold())
                    Text("Explain the causal chain in your own words. Which finding supports this concept, and why does the caveat matter?")
                    Button(revealRecall ? "Hide explanation" : "Check your explanation") { revealRecall.toggle() }
                    if revealRecall { Text(unit.mechanism); Text(unit.pitfall) }
                }
                Button {
                    store.markComplete(unit.id)
                } label: { Label(store.progress.completed.contains(unit.id) ? "Unit complete" : "Mark unit complete", systemImage: "checkmark.circle") }
                    .buttonStyle(.borderedProminent).accessibilityIdentifier("markComplete")
                Button("Practice both questions") { session = PracticeSession(questions: store.curriculum.questions(for: unit), timed: false) }
                    .buttonStyle(.bordered).accessibilityIdentifier("practiceUnit")
                DisclosureGroup("Sources and review status") {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Original educational material. Independent medical expert review and complete item-level source verification are pending.").font(.caption)
                        ForEach(store.curriculum.references.filter { unit.references.contains($0.id) }) { reference in
                            if let url = URL(string: reference.url) {
                                Link(reference.title, destination: url)
                                Text(reference.role).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }.padding(.top, 12)
                }
            }.padding(20).frame(maxWidth: 780, alignment: .leading).frame(maxWidth: .infinity)
        }
        .navigationTitle("Unit \(unit.number) of 20").navigationBarTitleDisplayMode(.inline)
        .toolbar {
            Button { store.toggleBookmark(unit.id) } label: {
                Image(systemName: store.progress.bookmarks.contains(unit.id) ? "bookmark.fill" : "bookmark")
            }.accessibilityLabel(store.progress.bookmarks.contains(unit.id) ? "Remove saved unit" : "Save unit")
        }
        .fullScreenCover(item: $session) { PracticeView(session: $0) }
    }
}

struct LessonSection: View {
    let title: String
    let text: String
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.title3.bold()).accessibilityAddTraits(.isHeader)
            Text(text).lineSpacing(4).textSelection(.enabled)
        }
    }
}

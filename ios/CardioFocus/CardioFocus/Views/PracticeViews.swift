import SwiftUI

struct PracticeSetupView: View {
    @EnvironmentObject private var store: StudyStore
    @State private var mode: PracticeMode = .mixed
    @State private var moduleID = -1
    @State private var kind = "all"
    @State private var count = 20
    @State private var session: PracticeSession?
    @State private var emptySelection = false

    var body: some View {
        Form {
            Section {
                Text("480 questions, 240 concepts").font(.title2.bold())
                Text("Each concept has one case-recognition question and one mechanism question. These are educational concept exercises, not official exam items.").foregroundStyle(.secondary)
            }
            Section("Session") {
                Picker("Mode", selection: $mode) { ForEach(PracticeMode.allCases) { Text($0.rawValue).tag($0) } }
                Picker("Module", selection: $moduleID) {
                    Text("All modules").tag(-1)
                    ForEach(store.curriculum.modules) { Text($0.title).tag($0.id) }
                }
                Picker("Question type", selection: $kind) {
                    Text("Both types").tag("all")
                    Text("Case recognition").tag("application")
                    Text("Mechanism explanation").tag("mechanism")
                }
                Picker("Questions", selection: $count) {
                    Text("10").tag(10); Text("20").tag(20); Text("40").tag(40)
                }
                if mode == .timed { Text("90 seconds per question. Answers and explanations appear after the session. Unanswered questions count as incorrect.").font(.caption) }
                Button("Start practice") { start() }.buttonStyle(.borderedProminent).accessibilityIdentifier("startPractice")
            }
            Section("Learn from mistakes") {
                Text("\(store.progress.answers.values.filter { !$0.correct }.count) questions are currently marked for review.")
                Text("Practice results are not a validated measure of readiness for USMLE Step 1.").font(.caption).foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Practice")
        .alert("No matching questions", isPresented: $emptySelection) { Button("OK", role: .cancel) {} } message: { Text("Try a different filter, or complete some practice before reviewing mistakes.") }
        .fullScreenCover(item: $session) { PracticeView(session: $0) }
    }
    private func start() {
        let pool = store.curriculum.questions.filter { q in
            (moduleID == -1 || q.topic == moduleID) && (kind == "all" || q.kind == kind)
            && (mode != .mistakes || store.progress.answers[q.id]?.correct == false)
        }
        let selected = PracticeSession.sample(pool, count: count)
        if selected.isEmpty { emptySelection = true; return }
        session = PracticeSession(questions: selected, timed: mode == .timed)
    }
}

struct PracticeView: View {
    @EnvironmentObject private var store: StudyStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @ObservedObject var session: PracticeSession
    @State private var showExit = false
    @State private var noteQuestion: StudyQuestion?
    @State private var now = Date()
    private let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        NavigationStack {
            Group {
                if session.finished { SessionResultsView(session: session) }
                else if let question = session.current { questionBody(question) }
                else { ContentUnavailableView("No questions", systemImage: "questionmark.circle") }
            }
            .navigationTitle(session.finished ? "Session results" : "Practice")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(session.finished ? "Done" : "Exit") { if session.finished { dismiss() } else { showExit = true } }
                }
            }
            .confirmationDialog("Leave this session?", isPresented: $showExit, titleVisibility: .visible) {
                Button("Leave session", role: .destructive) { dismiss() }
                Button("Keep practicing", role: .cancel) {}
            } message: { Text("Immediate-feedback answers are already saved. Unfinished timed answers will not be scored.") }
            .sheet(item: $noteQuestion) { ReviewNoteView(question: $0) }
        }
        .interactiveDismissDisabled(!session.finished)
        .onReceive(ticker) { date in now = date; session.checkDeadline(store: store, now: date) }
        .onChange(of: scenePhase) { _, phase in if phase == .active { now = Date(); session.checkDeadline(store: store, now: now) } }
    }

    private func questionBody(_ question: StudyQuestion) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    Text("Question \(session.index + 1) of \(session.questions.count)")
                    Spacer()
                    if session.timed {
                        let seconds = session.secondsRemaining(now: now)
                        Text(String(format: "%d:%02d", seconds / 60, seconds % 60)).monospacedDigit().accessibilityLabel("Time remaining: \(seconds / 60) minutes and \(seconds % 60) seconds")
                    }
                }.font(.caption).foregroundStyle(.secondary)
                ProgressView(value: Double(session.index), total: Double(session.questions.count)).accessibilityLabel("Session progress")
                Text(question.kind == "application" ? "CASE RECOGNITION" : "MECHANISM EXPLANATION").font(.caption.weight(.semibold)).foregroundStyle(Theme.green)
                Text(question.q).font(.title3.weight(.semibold)).accessibilityIdentifier("questionStem")
                ForEach(Array(session.orders[session.index].enumerated()), id: \.element) { displayIndex, option in
                    answerButton(question, option: option, displayIndex: displayIndex)
                }
                if let selected = session.selections[question.id], !session.timed {
                    QuestionExplanationView(question: question, selected: selected)
                }
                HStack {
                    if session.timed && session.index > 0 { Button("Previous") { session.previous() }.buttonStyle(.bordered) }
                    Spacer()
                    Button(session.index + 1 == session.questions.count ? "Finish session" : "Next question") { session.next(store: store) }
                        .buttonStyle(.borderedProminent).disabled(session.selections[question.id] == nil).accessibilityIdentifier("nextQuestion")
                }
                Button("Flag question for review", systemImage: "flag") { noteQuestion = question }.font(.caption)
                Text(question.id).font(.caption2).foregroundStyle(.secondary)
            }.padding(20).frame(maxWidth: 860, alignment: .leading).frame(maxWidth: .infinity)
        }.id(question.id)
    }

    private func answerButton(_ question: StudyQuestion, option: Int, displayIndex: Int) -> some View {
        let choice = session.selections[question.id]
        let revealed = choice != nil && !session.timed
        let correct = option == question.correct
        let selected = choice == option
        let color: Color = revealed && correct ? Theme.green : revealed && selected ? .red : selected ? .blue : .secondary
        return Button { session.select(option, store: store) } label: {
            HStack(alignment: .top, spacing: 12) {
                Text(String(UnicodeScalar(65 + displayIndex)!)).font(.caption.bold()).padding(6).background(.thinMaterial, in: RoundedRectangle(cornerRadius: 5))
                Text(question.a[option]).frame(maxWidth: .infinity, alignment: .leading).fixedSize(horizontal: false, vertical: true)
                if revealed && correct { Image(systemName: "checkmark.circle.fill").accessibilityLabel("Correct answer") }
                else if revealed && selected { Image(systemName: "xmark.circle.fill").accessibilityLabel("Incorrect answer") }
                else if selected { Image(systemName: "circle.inset.filled").accessibilityLabel("Selected") }
            }
            .foregroundStyle(revealed || selected ? color : .primary)
            .padding(14).background(color.opacity(selected || (revealed && correct) ? 0.10 : 0.03), in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(color.opacity(selected || (revealed && correct) ? 0.8 : 0.3), lineWidth: 1))
        }
        .buttonStyle(.plain).disabled(revealed).accessibilityIdentifier("answer-\(displayIndex)")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

struct QuestionExplanationView: View {
    @EnvironmentObject private var store: StudyStore
    let question: StudyQuestion
    let selected: Int?
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Label(selected == question.correct ? "Correct" : "Key explanation", systemImage: selected == question.correct ? "checkmark.circle" : "lightbulb").font(.headline)
                Text(question.why)
            }.padding().frame(maxWidth: .infinity, alignment: .leading).background(Theme.pale.opacity(0.35), in: RoundedRectangle(cornerRadius: 12))
            DisclosureGroup("Why each option fits or does not fit") {
                VStack(alignment: .leading, spacing: 18) {
                    ForEach(question.a.indices, id: \.self) { index in
                        VStack(alignment: .leading, spacing: 6) {
                            Text((index == question.correct ? "Correct: " : "Alternative: ") + question.a[index]).font(.subheadline.bold())
                            Text(question.rationales[index]).font(.subheadline)
                        }
                    }
                }.padding(.top, 12)
            }
            if let unit = store.curriculum.unit(question.unitId) { NavigationLink("Review the learning unit") { UnitDetailView(unit: unit) } }
        }.accessibilityIdentifier("answerExplanation")
    }
}

struct SessionResultsView: View {
    @ObservedObject var session: PracticeSession
    var body: some View {
        List {
            Section {
                Text("\(session.score) of \(session.questions.count) correct").font(.title.bold())
                Text("\(session.percentage)% on this practice session").font(.headline)
                Text("Unanswered questions count as incorrect. This score is not a validated prediction of exam performance.").font(.caption).foregroundStyle(.secondary)
            }
            Section("Review your answers") {
                ForEach(session.questions) { question in
                    NavigationLink {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 20) {
                                Text(question.q).font(.title3.bold())
                                Text("Your answer: " + (session.selections[question.id].map { question.a[$0] } ?? "Unanswered"))
                                Text("Correct answer: " + question.a[question.correct]).font(.headline)
                                QuestionExplanationView(question: question, selected: session.selections[question.id])
                            }.padding(20)
                        }.navigationTitle("Answer review").navigationBarTitleDisplayMode(.inline)
                    } label: {
                        HStack(alignment: .top) {
                            Image(systemName: session.selections[question.id] == question.correct ? "checkmark.circle.fill" : "arrow.counterclockwise.circle").foregroundStyle(Theme.green)
                            VStack(alignment: .leading, spacing: 5) { Text(question.q).lineLimit(3); Text(question.id).font(.caption).foregroundStyle(.secondary) }
                        }
                    }
                }
            }
        }
    }
}

struct ReviewNoteView: View {
    @EnvironmentObject private var store: StudyStore
    @Environment(\.dismiss) private var dismiss
    let question: StudyQuestion
    @State private var note = ""
    var body: some View {
        NavigationStack {
            Form {
                Section(question.id) { Text(question.q) }
                Section("Note for a reviewer") { TextEditor(text: $note).frame(minHeight: 180) }
                Section { Text("Saved only on this device. Export progress from the Progress tab to include these notes. No report is sent automatically.").font(.caption) }
            }
            .navigationTitle("Review note").navigationBarTitleDisplayMode(.inline)
            .toolbar { Button("Save") { store.setNote(note, questionID: question.id); dismiss() } }
            .onAppear { note = store.progress.notes[question.id] ?? "" }
        }
    }
}

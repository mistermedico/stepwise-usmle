import Foundation
import Combine

enum PracticeMode: String, CaseIterable, Identifiable {
    case mixed = "Mixed practice", timed = "Timed practice", mistakes = "Review mistakes"
    var id: String { rawValue }
}

@MainActor
final class PracticeSession: ObservableObject, Identifiable {
    let id = UUID()
    let questions: [StudyQuestion]
    let timed: Bool
    let deadline: Date
    let orders: [[Int]]
    @Published private(set) var index = 0
    @Published private(set) var selections: [String: Int] = [:]
    @Published private(set) var finished = false

    init(questions: [StudyQuestion], timed: Bool, now: Date = Date()) {
        self.questions = questions
        self.timed = timed
        deadline = now.addingTimeInterval(Double(questions.count) * 90)
        orders = questions.map { _ in [0, 1, 2, 3].shuffled() }
    }
    var current: StudyQuestion? { questions.indices.contains(index) ? questions[index] : nil }
    var score: Int { questions.filter { selections[$0.id] == $0.correct }.count }
    var percentage: Int { questions.isEmpty ? 0 : Int((Double(score) / Double(questions.count) * 100).rounded()) }
    func secondsRemaining(now: Date = Date()) -> Int { max(0, Int(ceil(deadline.timeIntervalSince(now)))) }

    func select(_ option: Int, store: StudyStore, now: Date = Date()) {
        guard !finished, let question = current, question.a.indices.contains(option) else { return }
        if timed && secondsRemaining(now: now) == 0 { finish(store: store); return }
        if !timed && selections[question.id] != nil { return }
        selections[question.id] = option
        if !timed { store.record(question: question, selected: option) }
    }
    func next(store: StudyStore, now: Date = Date()) {
        guard !finished, let question = current else { return }
        if timed && secondsRemaining(now: now) == 0 { finish(store: store); return }
        guard selections[question.id] != nil else { return }
        if index + 1 < questions.count { index += 1 } else { finish(store: store) }
    }
    func previous() { if timed && !finished && index > 0 { index -= 1 } }
    func checkDeadline(store: StudyStore, now: Date = Date()) {
        if timed && !finished && secondsRemaining(now: now) == 0 { finish(store: store) }
    }
    func finish(store: StudyStore) {
        guard !finished else { return }
        finished = true
        for question in questions { store.record(question: question, selected: selections[question.id]) }
        store.finishSession()
    }
    static func sample(_ pool: [StudyQuestion], count: Int) -> [StudyQuestion] {
        var seen = Set<String>(), first: [StudyQuestion] = [], paired: [StudyQuestion] = []
        for question in pool.shuffled() {
            if seen.insert(question.unitId).inserted { first.append(question) }
            else { paired.append(question) }
        }
        return Array((first + paired).prefix(max(0, count)))
    }
}

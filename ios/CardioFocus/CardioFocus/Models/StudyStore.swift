import Foundation
import Combine

struct Attempt: Codable {
    let correct: Bool
    let date: Date
}

struct StudyProgress: Codable {
    var completed: Set<String> = []
    var bookmarks: Set<String> = []
    var answers: [String: Attempt] = [:]
    var sessions: Int = 0
    var notes: [String: String] = [:]
}

@MainActor
final class StudyStore: ObservableObject {
    let curriculum: Curriculum
    @Published private(set) var progress: StudyProgress
    @Published private(set) var persistenceWarning: String?
    private let defaults: UserDefaults
    private let storageKey = "cardiofocus.native.v1"

    init(curriculum: Curriculum, defaults: UserDefaults = .standard) {
        self.curriculum = curriculum
        self.defaults = defaults
        if let data = defaults.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode(StudyProgress.self, from: data) {
            let unitIDs = Set(curriculum.units.map(\.id))
            let questionIDs = Set(curriculum.questions.map(\.id))
            var cleaned = decoded
            cleaned.completed.formIntersection(unitIDs)
            cleaned.bookmarks.formIntersection(unitIDs)
            cleaned.answers = decoded.answers.filter { questionIDs.contains($0.key) }
            cleaned.notes = decoded.notes.filter { questionIDs.contains($0.key) }
            cleaned.sessions = max(0, decoded.sessions)
            progress = cleaned
        } else {
            progress = StudyProgress()
            if defaults.data(forKey: storageKey) != nil {
                persistenceWarning = "Saved progress could not be read. A fresh study record is being used."
            }
        }
    }

    var accuracy: Int {
        guard !progress.answers.isEmpty else { return 0 }
        return Int((Double(progress.answers.values.filter(\.correct).count) / Double(progress.answers.count) * 100).rounded())
    }
    var completion: Double { Double(progress.completed.count) / Double(curriculum.units.count) }
    func completed(in module: StudyModule) -> Int { module.unitIds.filter { progress.completed.contains($0) }.count }

    func markComplete(_ id: String) {
        guard curriculum.unit(id) != nil else { return }
        progress.completed.insert(id); persist()
    }
    func toggleBookmark(_ id: String) {
        guard curriculum.unit(id) != nil else { return }
        if progress.bookmarks.contains(id) { progress.bookmarks.remove(id) } else { progress.bookmarks.insert(id) }
        persist()
    }
    func record(question: StudyQuestion, selected: Int?) {
        progress.answers[question.id] = Attempt(correct: selected == question.correct, date: Date())
        persist()
    }
    func finishSession() { progress.sessions += 1; persist() }
    func setNote(_ value: String, questionID: String) {
        let note = String(value.prefix(10000))
        if note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { progress.notes.removeValue(forKey: questionID) }
        else { progress.notes[questionID] = note }
        persist()
    }
    func reset() { progress = StudyProgress(); persist() }
    func exportData() throws -> Data {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(progress)
    }
    private func persist() {
        do { defaults.set(try JSONEncoder().encode(progress), forKey: storageKey) }
        catch { persistenceWarning = "Progress could not be saved on this device." }
    }
}

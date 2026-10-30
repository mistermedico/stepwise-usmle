import XCTest
@testable import CardioFocus

@MainActor
final class CardioFocusTests: XCTestCase {
    private func store() throws -> StudyStore {
        let defaults = UserDefaults(suiteName: "CardioFocusTests-\(UUID().uuidString)")!
        return StudyStore(curriculum: try Curriculum.load(bundle: Bundle(for: Bootstrap.self)), defaults: defaults)
    }
    func testBundledCurriculumIsCompleteAndDistinct() throws {
        let c = try store().curriculum
        try c.validate()
        XCTAssertEqual(c.units.count, 240); XCTAssertEqual(c.questions.count, 480)
        XCTAssertEqual(Set(c.units.map(\.title)).count, 240)
        XCTAssertEqual(Set(c.questions.map(\.q)).count, 480)
        for q in c.questions { XCTAssertEqual(q.rationales.count, 4); XCTAssertFalse(q.why.isEmpty) }
    }
    func testPairedQuestionsAndUniqueConceptSampling() throws {
        let c = try store().curriculum
        let selection = PracticeSession.sample(c.questions, count: 40)
        XCTAssertEqual(selection.count, 40)
        XCTAssertEqual(Set(selection.map(\.unitId)).count, 40)
        for unit in c.units { XCTAssertEqual(c.questions(for: unit).count, 2) }
    }
    func testImmediateScoringLocksAnAnswerAndFinishesOnce() throws {
        let s = try store(), qs = Array(s.curriculum.questions.prefix(2))
        let session = PracticeSession(questions: qs, timed: false)
        session.select(qs[0].correct, store: s)
        session.select((qs[0].correct + 1) % 4, store: s)
        XCTAssertEqual(session.selections[qs[0].id], qs[0].correct)
        session.next(store: s); session.select((qs[1].correct + 1) % 4, store: s); session.next(store: s)
        XCTAssertTrue(session.finished); XCTAssertEqual(session.score, 1); XCTAssertEqual(s.progress.sessions, 1)
        session.finish(store: s); XCTAssertEqual(s.progress.sessions, 1)
    }
    func testTimedAnswersAreDeferredAndDeadlineScoresUnanswered() throws {
        let s = try store(), qs = Array(s.curriculum.questions.prefix(2)), start = Date(timeIntervalSince1970: 100)
        let session = PracticeSession(questions: qs, timed: true, now: start)
        session.select(qs[0].correct, store: s, now: start)
        XCTAssertTrue(s.progress.answers.isEmpty)
        XCTAssertEqual(session.secondsRemaining(now: start.addingTimeInterval(10)), 170)
        session.checkDeadline(store: s, now: start.addingTimeInterval(181))
        XCTAssertTrue(session.finished); XCTAssertEqual(session.score, 1)
        XCTAssertEqual(s.progress.answers[qs[1].id]?.correct, false)
    }
    func testExpiredSessionCannotAcceptLateAnswers() throws {
        let s = try store(), q = s.curriculum.questions[0], start = Date(timeIntervalSince1970: 100)
        let session = PracticeSession(questions: [q], timed: true, now: start)
        session.select(q.correct, store: s, now: start.addingTimeInterval(91))
        XCTAssertTrue(session.finished); XCTAssertEqual(session.score, 0)
    }
    func testLocalStateRoundTripAndExport() throws {
        let defaults = UserDefaults(suiteName: "CardioFocusRoundTrip-\(UUID().uuidString)")!
        let c = try Curriculum.load(bundle: Bundle(for: Bootstrap.self))
        let s = StudyStore(curriculum: c, defaults: defaults), unit = c.units[0]
        s.markComplete(unit.id); s.toggleBookmark(unit.id); s.setNote("Check source wording", questionID: c.questions[0].id)
        let restored = StudyStore(curriculum: c, defaults: defaults)
        XCTAssertTrue(restored.progress.completed.contains(unit.id)); XCTAssertTrue(restored.progress.bookmarks.contains(unit.id))
        let exported = try JSONSerialization.jsonObject(with: restored.exportData()) as? [String: Any]
        XCTAssertNotNil(exported?["notes"])
        restored.reset(); XCTAssertTrue(restored.progress.completed.isEmpty); XCTAssertTrue(restored.progress.notes.isEmpty)
    }
}

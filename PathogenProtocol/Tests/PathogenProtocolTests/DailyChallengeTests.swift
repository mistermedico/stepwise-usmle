import XCTest
@testable import PathogenProtocol

final class DailyChallengeTests: XCTestCase {

    func testSameDayProducesSameChallenge() {
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let a = DailyChallengeProvider.challenge(for: date)
        let b = DailyChallengeProvider.challenge(for: date)
        XCTAssertEqual(a, b)
    }

    func testSameCalendarDayAtDifferentTimesProducesSameChallenge() {
        let morning = Date(timeIntervalSince1970: 1_700_000_000)
        let evening = morning.addingTimeInterval(6 * 3600)
        let a = DailyChallengeProvider.challenge(for: morning)
        let b = DailyChallengeProvider.challenge(for: evening)
        XCTAssertEqual(a.calendarDay, b.calendarDay)
        XCTAssertEqual(a, b)
    }

    func testDifferentDaysCanProduceDifferentChallenges() {
        let day1 = Date(timeIntervalSince1970: 1_700_000_000)
        let day2 = day1.addingTimeInterval(24 * 3600)
        let a = DailyChallengeProvider.challenge(for: day1)
        let b = DailyChallengeProvider.challenge(for: day2)
        XCTAssertNotEqual(a.calendarDay, b.calendarDay)
    }

    func testNonNegativeModuloNeverNegative() {
        XCTAssertEqual((-1).nonNegativeModulo(3), 2)
        XCTAssertEqual((-3).nonNegativeModulo(3), 0)
        XCTAssertEqual(5.nonNegativeModulo(3), 2)
    }
}

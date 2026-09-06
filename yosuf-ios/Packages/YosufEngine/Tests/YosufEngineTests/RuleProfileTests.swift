import XCTest
@testable import YosufEngine

final class RuleProfileTests: XCTestCase {
    func testAllFivePresetsExist() {
        XCTAssertEqual(RuleProfile.allPresets.count, 5)
        XCTAssertEqual(Set(RuleProfile.allPresets.map(\.id)), Set(RuleProfile.ProfileKind.allCases))
    }

    func testClampedCustomProfileStaysWithinSaneBounds() {
        var custom = RuleProfile.defaultCustom
        custom.yosufThreshold = -50
        custom.asafPenalty = 10_000
        custom.maxScore = 1
        custom.minMeldSize = 1

        let clamped = custom.clamped()
        XCTAssertGreaterThanOrEqual(clamped.yosufThreshold, 0)
        XCTAssertLessThanOrEqual(clamped.asafPenalty, 100)
        XCTAssertGreaterThanOrEqual(clamped.maxScore, clamped.asafPenalty + 10)
        XCTAssertGreaterThanOrEqual(clamped.minMeldSize, 3)
    }

    func testGrandmaProfileUsesAceHighAndStricterThreshold() {
        XCTAssertTrue(RuleProfile.grandma.aceHigh)
        XCTAssertEqual(RuleProfile.grandma.yosufThreshold, 5)
    }

    func testOnlyStreetProfileEnablesEventCardsByDefault() {
        let withEvents = RuleProfile.allPresets.filter(\.eventCardsEnabled)
        XCTAssertEqual(withEvents.map(\.id), [.street])
    }
}

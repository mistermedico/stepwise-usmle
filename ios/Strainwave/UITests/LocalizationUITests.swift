import XCTest

/// Sections 6 and 8.7/8.8: the Hebrew build and the size extremes, driven by
/// the same script as the English one.
final class LocalizationUITests: UITestCase {

    func testHebrewBuildIsPlayable() {
        launch(language: "he")

        // The identifiers are language-independent, so the same script drives
        // both builds — only the visible text should differ.
        waitForHome()
        let start = app.buttons[A11y.Home.start]
        XCTAssertEqual(
            start.label, "התחל התפרצות",
            "The control panel is not showing Hebrew"
        )
        capture("10-home-hebrew")

        startRun()
        XCTAssertTrue(
            app.buttons[A11y.Game.abilities].waitForExistence(timeout: shortTimeout),
            "A run could not be started in Hebrew"
        )
        capture("11-board-hebrew")

        tap(app.buttons[A11y.Game.abilities])
        XCTAssertTrue(
            app.otherElements[A11y.Tree.root].waitForExistence(timeout: shortTimeout),
            "The ability map does not open in Hebrew"
        )
        capture("12-ability-map-hebrew")
    }

    func testTheLargestTextSizeKeepsControlsUsable() {
        launch(contentSize: "UICTContentSizeCategoryAccessibilityXXXL")
        waitForHome()

        let start = app.buttons[A11y.Home.start]
        XCTAssertTrue(start.isHittable, "The start control is unreachable at the largest text size")
        capture("13-home-largest-text")

        startRun()
        XCTAssertTrue(
            app.buttons[A11y.Game.abilities].isHittable,
            "The abilities control is unreachable at the largest text size"
        )
        capture("14-board-largest-text")
    }

    func testTheSmallestTextSizeStillFillsTheScreen() {
        launch(contentSize: "UICTContentSizeCategoryExtraSmall")
        waitForHome()
        XCTAssertTrue(app.buttons[A11y.Home.start].isHittable)
        capture("15-home-smallest-text")
    }

    /// Tap targets have to clear 44pt in both directions, on the smallest
    /// device, in both languages.
    func testPrimaryControlsMeetTheMinimumTapTarget() {
        launch()
        waitForHome()

        let minimum: CGFloat = 44
        let start = app.buttons[A11y.Home.start]
        XCTAssertGreaterThanOrEqual(start.frame.height, minimum, "Start control is too short")

        startRun()
        for identifier in [A11y.Game.abilities, A11y.Game.playPause, A11y.Game.speed] {
            let control = app.buttons[identifier]
            XCTAssertTrue(control.waitForExistence(timeout: shortTimeout), "\(identifier) is missing")
            XCTAssertGreaterThanOrEqual(control.frame.height, minimum, "\(identifier) is too short")
            XCTAssertGreaterThanOrEqual(control.frame.width, minimum, "\(identifier) is too narrow")
        }
    }
}

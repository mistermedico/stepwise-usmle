import XCTest

/// There is no Mac in this project's development environment to run the iOS Simulator
/// or VoiceOver by hand, so this suite is the substitute: it drives the real app on a
/// real (simulated) device in CI, attaches screenshots to the test report so a human
/// (or the agent reading the CI artifacts) can actually see the UI render, and runs
/// Apple's automated accessibility audit in place of a manual VoiceOver pass. The
/// workflow that drives this (`.github/workflows/pathogen-protocol-ios.yml`) runs it
/// once per device size (iPhone SE and a Pro Max-class device) to cover both screen
/// extremes called out in the design spec.
final class ScreenshotAndAccessibilityTests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = true
    }

    func testHomeScreenRendersAndPassesAccessibilityAudit() throws {
        let app = XCUIApplication()
        app.launch()

        let title = app.staticTexts["Pathogen Protocol"]
        XCTAssertTrue(title.waitForExistence(timeout: 15), "Home screen title never appeared")

        attachScreenshot(app, name: "01-Home")

        if #available(iOS 17.0, *) {
            try app.performAccessibilityAudit()
        }
    }

    func testStartingARunReachesTheGameScreen() throws {
        let app = XCUIApplication()
        app.launch()

        let startButton = app.buttons["Start Outbreak"]
        XCTAssertTrue(startButton.waitForExistence(timeout: 15), "Start Outbreak button never appeared")
        startButton.tap()

        // Give the map + HUD a moment to lay out and the first simulated day to run
        // before capturing, so the screenshot shows real (not placeholder-empty) state.
        Thread.sleep(forTimeInterval: 3.0)

        attachScreenshot(app, name: "02-GameScreen")
    }

    func testOpeningTheEvolutionTreeSheet() throws {
        let app = XCUIApplication()
        app.launch()

        let startButton = app.buttons["Start Outbreak"]
        XCTAssertTrue(startButton.waitForExistence(timeout: 15))
        startButton.tap()

        let evolveButton = app.buttons["Evolve"]
        XCTAssertTrue(evolveButton.waitForExistence(timeout: 15), "Evolve button never appeared")
        evolveButton.tap()

        Thread.sleep(forTimeInterval: 1.0)
        attachScreenshot(app, name: "03-EvolutionTree")
    }

    private func attachScreenshot(_ app: XCUIApplication, name: String) {
        let screenshot = app.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}

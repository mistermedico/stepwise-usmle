import XCTest

final class CardioFocusUITests: XCTestCase {
    @MainActor
    func testStudyPracticeAndNativeScreenshots() throws {
        let app = XCUIApplication(); app.launchArguments = ["--ui-testing"]; app.launch()
        XCTAssertTrue(app.navigationBars["CardioFocus"].waitForExistence(timeout: 20))
        attach("01-Learning-path", app: app)
        let module = app.buttons["module-0"]
        XCTAssertTrue(module.waitForExistence(timeout: 5)); module.tap()
        let first = app.staticTexts["Cardiac output"]
        XCTAssertTrue(first.waitForExistence(timeout: 5)); first.tap()
        XCTAssertTrue(app.buttons["practiceUnit"].waitForExistence(timeout: 5))
        attach("02-Learning-unit", app: app)
        app.buttons["practiceUnit"].tap()
        XCTAssertTrue(app.staticTexts["questionStem"].waitForExistence(timeout: 5))
        attach("03-Question-practice", app: app)
        app.buttons["answer-0"].tap()
        XCTAssertTrue(app.otherElements["answerExplanation"].exists || app.staticTexts["Key explanation"].exists || app.staticTexts["Correct"].exists)
        attach("04-Answer-explanation", app: app)
        app.buttons["Exit"].tap(); app.buttons["Leave session"].tap()
        XCTAssertTrue(app.buttons["practiceUnit"].waitForExistence(timeout: 10))
        tapTab("Cards", app: app)
        XCTAssertTrue(app.buttons["flashcard"].waitForExistence(timeout: 10)); attach("05-Flashcards", app: app)
        tapTab("Progress", app: app)
        XCTAssertTrue(app.navigationBars["Your progress"].waitForExistence(timeout: 10))
        attach("06-Progress", app: app)
    }
    @MainActor
    func testCaptureHomeScreen() throws {
        let app = XCUIApplication(); app.launchArguments = ["--ui-testing"]; app.launch()
        XCTAssertTrue(app.navigationBars["CardioFocus"].waitForExistence(timeout: 20))
        attach("01-Home-native", app: app)
    }
    @MainActor
    private func tapTab(_ name: String, app: XCUIApplication) {
        let button = app.tabBars.buttons[name].firstMatch
        XCTAssertTrue(button.waitForExistence(timeout: 10))
        let ready = XCTNSPredicateExpectation(predicate: NSPredicate(format: "isHittable == true"), object: button)
        XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 10), .completed)
        button.tap()
    }
    @MainActor
    private func attach(_ name: String, app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot()); attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
}

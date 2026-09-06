import XCTest

/// Shared launch and navigation helpers.
///
/// Every test starts from a wiped install with the consent prompts resolved, so
/// no test can inherit another's history and none of them wait on a system
/// alert they cannot dismiss.
class UITestCase: XCTestCase {

    var app: XCUIApplication!

    /// Generous, because a simulator under CI load is far slower than a device.
    let shortTimeout: TimeInterval = 20
    /// A whole run plays out inside this budget with the fast clock on. The
    /// simulator cannot keep up with the timer's nominal rate, so the budget is
    /// set from observed throughput rather than from the interval.
    let runTimeout: TimeInterval = 300

    override func setUpWithError() throws {
        try super.setUpWithError()
        continueAfterFailure = false
    }

    override func tearDown() {
        app = nil
        super.tearDown()
    }

    /// Launches the app. `language` switches the whole UI, which is how the
    /// Hebrew and right-to-left checks run the very same script.
    @discardableResult
    func launch(
        language: String? = nil,
        contentSize: String? = nil,
        fastClock: Bool = true
    ) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += [
            A11y.LaunchArgument.resetState,
            A11y.LaunchArgument.skipConsent
        ]
        if fastClock {
            app.launchArguments.append(A11y.LaunchArgument.fastClock)
        }
        if let language {
            app.launchArguments += ["-AppleLanguages", "(\(language))", "-AppleLocale", language]
        }
        if let contentSize {
            app.launchArguments += ["-UIPreferredContentSizeCategoryName", contentSize]
        }
        app.launch()
        self.app = app
        return app
    }

    // MARK: Navigation

    func waitForHome(file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(
            app.buttons[A11y.Home.start].waitForExistence(timeout: shortTimeout),
            "The control panel never appeared",
            file: file, line: line
        )
    }

    /// Scrolls the given element into view, then taps it.
    func tap(
        _ element: XCUIElement,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertTrue(
            element.waitForExistence(timeout: shortTimeout),
            "\(element) never appeared", file: file, line: line
        )
        if !element.isHittable {
            app.swipeUp()
        }
        XCTAssertTrue(element.isHittable, "\(element) was not tappable", file: file, line: line)
        element.tap()
    }

    /// Starts a run on the given tier and waits for the board.
    func startRun(difficulty: String = "lethal", file: StaticString = #filePath, line: UInt = #line) {
        waitForHome(file: file, line: line)
        tap(app.buttons[A11y.Home.difficulty(difficulty)], file: file, line: line)
        tap(app.buttons[A11y.Home.start], file: file, line: line)
        XCTAssertTrue(
            app.buttons[A11y.Game.abilities].waitForExistence(timeout: shortTimeout),
            "The board never appeared", file: file, line: line
        )
    }

    /// Saves a screenshot into the result bundle. These double as the raw
    /// material for the App Store listing.
    func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}

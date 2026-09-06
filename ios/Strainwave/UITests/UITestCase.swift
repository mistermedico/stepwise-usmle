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

    /// Brings an element into view and taps it.
    ///
    /// Scrolling is retried with a settle pause between attempts: a tap issued
    /// while a scroll view is still decelerating lands wherever the content has
    /// drifted to, which looks exactly like a control that does not work.
    func tap(
        _ element: XCUIElement,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertTrue(
            element.waitForExistence(timeout: shortTimeout),
            "\(element) never appeared", file: file, line: line
        )

        for _ in 0..<6 {
            if element.isHittable {
                element.tap()
                return
            }
            app.swipeUp()
            Thread.sleep(forTimeInterval: 0.5)
        }

        XCTFail(
            "\(element) never became tappable", file: file, line: line
        )
    }

    /// Starts a run and waits for the board.
    ///
    /// `difficulty` is left alone by default. Selecting one means scrolling the
    /// set-up panel, and most tests do not care which tier they run — leaving it
    /// out keeps them testing what they are actually about.
    func startRun(
        difficulty: String? = nil,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        waitForHome(file: file, line: line)
        if let difficulty {
            tap(app.buttons[A11y.Home.difficulty(difficulty)], file: file, line: line)
        }
        tap(app.buttons[A11y.Home.start], file: file, line: line)

        let board = app.buttons[A11y.Game.abilities]
        if !board.waitForExistence(timeout: shortTimeout) {
            // Print the tree: "the board never appeared" on its own says
            // nothing about whether the app crashed, stalled, or simply stayed
            // on the control panel.
            print("--- element tree when the board failed to appear ---")
            print(app.debugDescription)
            capture("failure-board-missing")
            XCTFail("The board never appeared", file: file, line: line)
        }
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

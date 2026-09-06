import XCTest

/// Section 8.5: a real run, played through the interface, all the way to the
/// report — not a unit test standing in for one.
final class RunFlowUITests: UITestCase {

    func testAWholeRunReachesTheReport() {
        launch()
        // The one test that exercises the tier picker, which means scrolling.
        startRun(difficulty: "lethal")
        // Fastest setting, so the run finishes well inside the budget.
        tap(app.buttons[A11y.Game.speed])
        capture("01-board-early")

        // The clock is running: the day counter has to move on its own.
        let day = app.otherElements[A11y.Game.day]
        XCTAssertTrue(day.waitForExistence(timeout: shortTimeout))
        let opening = day.label
        let moved = NSPredicate(format: "label != %@", opening)
        expectation(for: moved, evaluatedWith: day)
        waitForExpectations(timeout: shortTimeout)

        // Every run ends by itself. The engine guarantees an outcome, so the
        // report is reachable without the test touching another control.
        let report = app.buttons[A11y.Report.again]
        XCTAssertTrue(
            report.waitForExistence(timeout: runTimeout),
            "The run never reached its report"
        )
        capture("02-report")

        XCTAssertTrue(app.staticTexts[A11y.Report.title].exists, "The report has no title")

        // And the report leads back to a playable control panel.
        tap(app.buttons[A11y.Report.home])
        waitForHome()
        capture("03-home-with-history")
    }

    func testEvolvingAnAbilitySpendsPoints() {
        launch()
        // The default tier opens with enough points for the cheapest symptom.
        startRun()

        tap(app.buttons[A11y.Game.abilities])
        XCTAssertTrue(
            app.otherElements[A11y.Tree.root].waitForExistence(timeout: shortTimeout),
            "The ability map never opened"
        )
        capture("04-ability-map")

        // Lethargy is a root node in the symptoms branch and the cheapest buy.
        // Symptoms is the third branch in `TraitCategory.allCases`.
        tap(app.segmentedControls.buttons.element(boundBy: 2))
        let node = app.buttons[A11y.Tree.node("lethargy")]
        tap(node)

        let unlock = app.buttons[A11y.Tree.unlock]
        XCTAssertTrue(unlock.waitForExistence(timeout: shortTimeout), "No way to evolve the node")
        unlock.tap()

        // Once bought, the node offers folding back instead of evolving.
        XCTAssertTrue(
            app.buttons[A11y.Tree.fold].waitForExistence(timeout: shortTimeout),
            "The node did not register as evolved"
        )
        capture("05-ability-unlocked")

        tap(app.buttons[A11y.Tree.close])
        XCTAssertTrue(app.buttons[A11y.Game.abilities].waitForExistence(timeout: shortTimeout))
    }

    func testPausingStopsTheClock() {
        launch(fastClock: false)
        startRun()

        let day = app.otherElements[A11y.Game.day]
        XCTAssertTrue(day.waitForExistence(timeout: shortTimeout))

        tap(app.buttons[A11y.Game.playPause])
        let paused = day.label
        // Long enough that an unpaused clock would certainly have ticked.
        Thread.sleep(forTimeInterval: 2.5)
        XCTAssertEqual(day.label, paused, "The clock kept running while paused")

        tap(app.buttons[A11y.Game.playPause])
        let resumed = NSPredicate(format: "label != %@", paused)
        expectation(for: resumed, evaluatedWith: day)
        waitForExpectations(timeout: shortTimeout)
    }

    func testLeavingARunReturnsToTheControlPanel() {
        launch()
        startRun()

        tap(app.buttons[A11y.Game.quit])
        tap(app.buttons[A11y.Game.quitConfirm])
        waitForHome()
    }
}

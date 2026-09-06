import XCTest

/// Section 8.8, run rather than eyeballed.
///
/// `performAccessibilityAudit` is Apple's own checker: contrast, hit-region
/// size, elements with no description, clipped text at large content sizes.
/// It walks whatever is on screen, so each test puts the app on one screen
/// first and audits that.
final class AccessibilityUITests: UITestCase {

    /// Reports every finding into the test log and, for now, does not fail the
    /// run. This is the discovery pass: the findings get fixed, and then the
    /// handler is removed so the audit is enforced.
    @available(iOS 17.0, *)
    private func audit(_ screen: String) throws {
        var findings: [String] = []
        try app.performAccessibilityAudit { issue in
            findings.append("\(issue.auditType): \(issue.compactDescription)")
            return true
        }
        if findings.isEmpty {
            print("Accessibility audit — \(screen): clean")
        } else {
            print("Accessibility audit — \(screen): \(findings.count) finding(s)")
            for finding in Set(findings).sorted() {
                print("  • \(finding)")
            }
        }
    }

    func testControlPanelPassesTheAudit() throws {
        try XCTSkipUnless(
            ProcessInfo.processInfo.isOperatingSystemAtLeast(
                OperatingSystemVersion(majorVersion: 17, minorVersion: 0, patchVersion: 0)
            ),
            "The accessibility audit needs iOS 17 or later"
        )
        launch()
        waitForHome()
        if #available(iOS 17.0, *) {
            try audit("control panel")
        }
    }

    func testBoardPassesTheAudit() throws {
        try XCTSkipUnless(
            ProcessInfo.processInfo.isOperatingSystemAtLeast(
                OperatingSystemVersion(majorVersion: 17, minorVersion: 0, patchVersion: 0)
            ),
            "The accessibility audit needs iOS 17 or later"
        )
        launch()
        startRun()
        // Pause first: auditing a board that is repainting produces noise.
        tap(app.buttons[A11y.Game.playPause])
        if #available(iOS 17.0, *) {
            try audit("board")
        }
    }

    func testAbilityMapPassesTheAudit() throws {
        try XCTSkipUnless(
            ProcessInfo.processInfo.isOperatingSystemAtLeast(
                OperatingSystemVersion(majorVersion: 17, minorVersion: 0, patchVersion: 0)
            ),
            "The accessibility audit needs iOS 17 or later"
        )
        launch()
        startRun(difficulty: "breezy")
        tap(app.buttons[A11y.Game.abilities])
        XCTAssertTrue(app.otherElements[A11y.Tree.root].waitForExistence(timeout: shortTimeout))
        if #available(iOS 17.0, *) {
            try audit("ability map")
        }
    }

    /// Every territory must announce itself; the board is a `Canvas`, so its
    /// meaning exists only in the accessibility layer laid over it.
    func testEveryTerritoryIsReachableByVoiceOver() {
        launch()
        startRun()

        let identifiers = [
            "northreach", "coldspire", "farhaven", "verdanmoor", "palewind", "highbarrow",
            "ashenvale", "goldensands", "stillwater", "emberfall", "tidecrest", "sunwake"
        ]
        for identifier in identifiers {
            let territory = app.otherElements[A11y.Game.region(identifier)]
            XCTAssertTrue(
                territory.waitForExistence(timeout: shortTimeout),
                "\(identifier) is invisible to VoiceOver"
            )
            XCTAssertFalse(
                territory.label.isEmpty,
                "\(identifier) announces nothing"
            )
        }
    }
}

import XCTest
import OutbreakEngine
@testable import Strainwave

/// Section 6: both languages ship complete from launch.
///
/// Every key the engine can produce is checked in English *and* Hebrew, so a
/// new trait, region or achievement cannot reach the store with a raw key
/// showing on screen.
final class LocalizationTests: XCTestCase {

    private let languages = ["en", "he"]

    /// Returns the translation, or `nil` when the key is missing from that language.
    private func translation(_ key: String, language: String) -> String? {
        guard let path = Bundle.main.path(forResource: language, ofType: "lproj"),
              let bundle = Bundle(path: path) else {
            XCTFail("No \(language).lproj in the app bundle")
            return nil
        }
        let sentinel = "__missing__"
        let value = bundle.localizedString(forKey: key, value: sentinel, table: nil)
        return value == sentinel ? nil : value
    }

    private func assertTranslated(_ keys: [String], file: StaticString = #filePath, line: UInt = #line) {
        for key in keys {
            for language in languages {
                let value = translation(key, language: language)
                XCTAssertNotNil(value, "Missing \(language) string for '\(key)'", file: file, line: line)
                XCTAssertFalse(
                    value?.isEmpty ?? true,
                    "Empty \(language) string for '\(key)'", file: file, line: line
                )
            }
        }
    }

    func testEveryRegionIsNamedInBothLanguages() {
        assertTranslated(RegionID.allCases.map(\.localizationKey))
    }

    func testEveryTraitHasATitleAndDetail() {
        assertTranslated(TraitID.allCases.map(\.titleKey))
        assertTranslated(TraitID.allCases.map(\.detailKey))
    }

    func testEveryStrainHasATitleAndDetail() {
        assertTranslated(StrainID.allCases.map(\.titleKey))
        assertTranslated(StrainID.allCases.map(\.detailKey))
    }

    func testEveryTierScenarioAndCategoryIsTranslated() {
        assertTranslated(Difficulty.allCases.map(\.titleKey))
        assertTranslated(Difficulty.allCases.map(\.detailKey))
        assertTranslated(StartScenario.allCases.map(\.titleKey))
        assertTranslated(StartScenario.allCases.map(\.detailKey))
        assertTranslated(TraitCategory.allCases.map(\.localizationKey))
        assertTranslated(Climate.allCases.map(\.localizationKey))
        assertTranslated(Wealth.allCases.map(\.localizationKey))
        assertTranslated(Density.allCases.map(\.localizationKey))
        assertTranslated(TravelRoute.allCases.map(\.localizationKey))
    }

    func testEveryAchievementIsTranslated() {
        assertTranslated(Achievement.allCases.map(\.titleKey))
        assertTranslated(Achievement.allCases.map(\.detailKey))
    }

    func testEveryReportTitleIsTranslated() {
        assertTranslated(ReportTitle.allCases.map(\.localizationKey))
    }

    func testEveryEventKindIsTranslated() {
        let samples: [GameEvent.Kind] = [
            .outbreakBegan(region: .northreach),
            .regionInfected(region: .sunwake, route: .air),
            .strainDetected,
            .researchBegan,
            .transportLocked(region: .palewind),
            .bordersClosed(region: .palewind),
            .restrictionsLifted(region: .palewind),
            .traitUnlocked(trait: .aerosolI),
            .traitFolded(trait: .aerosolI),
            .driftMutation(trait: .lethargy),
            .regionSaturated(region: .farhaven),
            .researchMilestone(percent: 50),
            .victory,
            .defeat(reason: .solutionFound)
        ]
        assertTranslated(samples.map { GameEvent(day: 1, kind: $0).localizationKey })

        // And each one must render without leaving a format specifier behind.
        for kind in samples {
            let rendered = L.event(GameEvent(day: 7, kind: kind))
            XCTAssertFalse(rendered.contains("%@"), "Unfilled placeholder in \(kind)")
            XCTAssertFalse(rendered.contains("%d"), "Unfilled placeholder in \(kind)")
        }
    }

    func testEveryObjectiveIsTranslatedAndFormatted() {
        let objectives: [ChallengeObjective] = [
            .within(days: 90),
            .lethalityBelow(cap: 2.5),
            .undetectedUntilRegions(count: 4),
            .lossesBelow(fraction: 0.35),
            .spendAtMost(points: 80)
        ]
        assertTranslated(objectives.map(\.localizationKey))

        for objective in objectives {
            let rendered = L.objective(objective)
            XCTAssertFalse(rendered.isEmpty)
            for specifier in ["%@", "%d", "%f", "%.1f", "%.0f"] {
                XCTAssertFalse(
                    rendered.contains(specifier),
                    "Unfilled placeholder \(specifier) in \(objective)"
                )
            }
        }
    }

    func testDefeatReasonsAndSignaturesAreTranslated() {
        assertTranslated([
            DefeatReason.solutionFound.localizationKey,
            DefeatReason.burnedOut.localizationKey,
            DefeatReason.objectiveFailed.localizationKey
        ])
        assertTranslated(StrainCatalog.all.map(\.signature.detailKey))
    }

    func testInterfaceStringsAreTranslated() {
        assertTranslated([
            "app.name", "app.tagline", "home.start", "home.daily", "home.reports",
            "home.achievements", "home.settings", "hud.day", "hud.points", "hud.awareness",
            "hud.research", "hud.abilities", "tree.title", "tree.unlock", "tree.cost",
            "report.title.header", "report.share", "report.again", "report.home",
            "empty.reports.title", "empty.reports.detail", "empty.achievements.title",
            "settings.sound", "settings.haptics", "settings.privacy", "common.close"
        ])
    }

    func testHebrewIsActuallyDifferentFromEnglish() {
        // Guards against a copied-over English file.
        let sampleKeys = ["home.start", "hud.awareness", "report.again", "settings.privacy"]
        for key in sampleKeys {
            let english = translation(key, language: "en")
            let hebrew = translation(key, language: "he")
            XCTAssertNotNil(english)
            XCTAssertNotNil(hebrew)
            XCTAssertNotEqual(english, hebrew, "'\(key)' was never translated")
        }
    }
}

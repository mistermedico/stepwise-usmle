import Foundation
import OutbreakEngine

/// Bridges engine identifiers to localised text.
///
/// The engine deliberately knows nothing about language — it only carries keys.
/// Every string the player reads is resolved here, which keeps the Hebrew and
/// English builds identical apart from the strings table.
enum L {

    /// Looks up a key in the app bundle. Falls back to the key itself so a
    /// missing string is loud in a screenshot rather than silently blank.
    static func string(_ key: String) -> String {
        NSLocalizedString(key, tableName: nil, bundle: .main, value: key, comment: "")
    }

    static func format(_ key: String, _ arguments: CVarArg...) -> String {
        String(format: string(key), arguments: arguments)
    }

    // MARK: Engine vocabulary

    static func region(_ id: RegionID) -> String { string(id.localizationKey) }
    static func climate(_ value: Climate) -> String { string(value.localizationKey) }
    static func wealth(_ value: Wealth) -> String { string(value.localizationKey) }
    static func density(_ value: Density) -> String { string(value.localizationKey) }
    static func route(_ value: TravelRoute) -> String { string(value.localizationKey) }
    static func category(_ value: TraitCategory) -> String { string(value.localizationKey) }

    static func traitTitle(_ id: TraitID) -> String { string(id.titleKey) }
    static func traitDetail(_ id: TraitID) -> String { string(id.detailKey) }
    static func strainTitle(_ id: StrainID) -> String { string(id.titleKey) }
    static func strainDetail(_ id: StrainID) -> String { string(id.detailKey) }
    static func signature(_ value: StrainSignature) -> String { string(value.detailKey) }
    static func difficultyTitle(_ value: Difficulty) -> String { string(value.titleKey) }
    static func difficultyDetail(_ value: Difficulty) -> String { string(value.detailKey) }
    static func scenarioTitle(_ value: StartScenario) -> String { string(value.titleKey) }
    static func scenarioDetail(_ value: StartScenario) -> String { string(value.detailKey) }
    static func reportTitle(_ value: ReportTitle) -> String { string(value.localizationKey) }
    static func defeatReason(_ value: DefeatReason) -> String { string(value.localizationKey) }
    static func achievementTitle(_ value: Achievement) -> String { string(value.titleKey) }
    static func achievementDetail(_ value: Achievement) -> String { string(value.detailKey) }

    /// One line of the news ticker / report timeline.
    static func event(_ event: GameEvent) -> String {
        switch event.kind {
        case .outbreakBegan(let region):
            return format(event.localizationKey, self.region(region))
        case .regionInfected(let region, let route):
            return format(event.localizationKey, self.region(region), self.route(route))
        case .strainDetected, .researchBegan, .victory:
            return string(event.localizationKey)
        case .defeat(let reason):
            return "\(string(event.localizationKey)) — \(defeatReason(reason))"
        case .transportLocked(let region),
             .bordersClosed(let region),
             .restrictionsLifted(let region),
             .regionSaturated(let region):
            return format(event.localizationKey, self.region(region))
        case .traitUnlocked(let trait), .traitFolded(let trait), .driftMutation(let trait):
            return format(event.localizationKey, traitTitle(trait))
        case .researchMilestone(let percent):
            return format(event.localizationKey, percent)
        }
    }

    /// The daily challenge's extra condition, as a sentence.
    static func objective(_ objective: ChallengeObjective) -> String {
        switch objective {
        case .within(let days):
            return format(objective.localizationKey, days)
        case .lethalityBelow(let cap):
            return format(objective.localizationKey, cap)
        case .undetectedUntilRegions(let count):
            return format(objective.localizationKey, count)
        case .lossesBelow(let fraction):
            return format(objective.localizationKey, fraction * 100)
        case .spendAtMost(let points):
            return format(objective.localizationKey, points)
        }
    }

    /// Prerequisite list for a locked ability node.
    static func prerequisites(_ ids: [TraitID]) -> String {
        let names = ids.map(traitTitle)
        return format("tree.locked", ListFormatter.localizedString(byJoining: names))
    }
}

/// Number formatting shared by the control panel and the report.
enum Figures {

    /// Compact population figure: `4.2B`, `310M`, `18K`.
    static func people(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 1
        formatter.locale = .current

        let magnitude = abs(value)
        let (scaled, suffix): (Double, String)
        switch magnitude {
        case 1_000_000_000...: (scaled, suffix) = (value / 1_000_000_000, "B")
        case 1_000_000...: (scaled, suffix) = (value / 1_000_000, "M")
        case 1_000...: (scaled, suffix) = (value / 1_000, "K")
        default: (scaled, suffix) = (value, "")
        }
        formatter.maximumFractionDigits = suffix.isEmpty ? 0 : 1
        let number = formatter.string(from: NSNumber(value: scaled)) ?? "0"
        return number + suffix
    }

    /// Percentage with one decimal, e.g. `62.4%`.
    static func percent(_ fraction: Double, decimals: Int = 1) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .percent
        formatter.maximumFractionDigits = decimals
        formatter.minimumFractionDigits = decimals
        formatter.locale = .current
        return formatter.string(from: NSNumber(value: min(1, max(0, fraction)))) ?? "0%"
    }

    static func integer(_ value: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = .current
        return formatter.string(from: NSNumber(value: value)) ?? String(value)
    }

    static func date(_ value: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.locale = .current
        return formatter.string(from: value)
    }
}

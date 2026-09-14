import Foundation

/// The three upgrade branches described in the design spec: how the pathogen moves,
/// how well it hides, and the lethality/spread-ease trade-off of its symptoms.
public enum UpgradeCategory: String, CaseIterable, Codable, Identifiable, Hashable {
    case transmission
    case resistance
    case symptoms

    public var id: String { rawValue }
}

/// The net gameplay effect a single upgrade node grants once unlocked.
public struct UpgradeEffect: Codable, Equatable, Hashable {
    /// Added to the pathogen's effective transmission rate.
    public var transmissionRateBonus: Double = 0
    /// Reduces how quickly global/regional awareness grows from this pathogen's presence.
    public var detectionResistanceBonus: Double = 0
    /// Allows continued spread across a locked-down border (bypasses the lockdown rule).
    public var bypassesLockdown: Bool = false
    /// Added to lethality (drives report scoring and, in part, awareness growth).
    public var lethalityBonus: Double = 0
    /// Added to symptom severity (visibility). Higher severity raises detection speed
    /// but is what lets `lethalityBonus` be nonzero in the symptom branch — the
    /// stealth/kill trade-off called for in the spec.
    public var severityBonus: Double = 0

    public init(
        transmissionRateBonus: Double = 0,
        detectionResistanceBonus: Double = 0,
        bypassesLockdown: Bool = false,
        lethalityBonus: Double = 0,
        severityBonus: Double = 0
    ) {
        self.transmissionRateBonus = transmissionRateBonus
        self.detectionResistanceBonus = detectionResistanceBonus
        self.bypassesLockdown = bypassesLockdown
        self.lethalityBonus = lethalityBonus
        self.severityBonus = severityBonus
    }
}

public struct UpgradeNode: Identifiable, Codable, Equatable, Hashable {
    public let id: String
    public let category: UpgradeCategory
    /// 1-based position within its category; also the visual "ring" in the neural-path tree.
    public let tier: Int
    public let cost: Int
    /// Node that must be unlocked first, or nil for a category's root node.
    public let prerequisiteID: String?
    public let nameKey: String
    public let descriptionKey: String
    public let effect: UpgradeEffect

    public init(
        id: String,
        category: UpgradeCategory,
        tier: Int,
        cost: Int,
        prerequisiteID: String?,
        nameKey: String,
        descriptionKey: String,
        effect: UpgradeEffect
    ) {
        self.id = id
        self.category = category
        self.tier = tier
        self.cost = cost
        self.prerequisiteID = prerequisiteID
        self.nameKey = nameKey
        self.descriptionKey = descriptionKey
        self.effect = effect
    }
}

/// Static catalog of every upgrade node in the game. Three branches, four tiers each.
public enum UpgradeCatalog {
    public static let allNodes: [UpgradeNode] = transmissionBranch + resistanceBranch + symptomsBranch

    public static func node(_ id: String) -> UpgradeNode? {
        allNodes.first { $0.id == id }
    }

    private static let transmissionBranch: [UpgradeNode] = [
        UpgradeNode(id: "transmission.1", category: .transmission, tier: 1, cost: 10, prerequisiteID: nil,
                    nameKey: "upgrade.transmission.1.name", descriptionKey: "upgrade.transmission.1.desc",
                    effect: UpgradeEffect(transmissionRateBonus: 0.04)),
        UpgradeNode(id: "transmission.2", category: .transmission, tier: 2, cost: 18, prerequisiteID: "transmission.1",
                    nameKey: "upgrade.transmission.2.name", descriptionKey: "upgrade.transmission.2.desc",
                    effect: UpgradeEffect(transmissionRateBonus: 0.06)),
        UpgradeNode(id: "transmission.3", category: .transmission, tier: 3, cost: 30, prerequisiteID: "transmission.2",
                    nameKey: "upgrade.transmission.3.name", descriptionKey: "upgrade.transmission.3.desc",
                    effect: UpgradeEffect(transmissionRateBonus: 0.09)),
        UpgradeNode(id: "transmission.4", category: .transmission, tier: 4, cost: 45, prerequisiteID: "transmission.3",
                    nameKey: "upgrade.transmission.4.name", descriptionKey: "upgrade.transmission.4.desc",
                    effect: UpgradeEffect(transmissionRateBonus: 0.13)),
    ]

    private static let resistanceBranch: [UpgradeNode] = [
        UpgradeNode(id: "resistance.1", category: .resistance, tier: 1, cost: 10, prerequisiteID: nil,
                    nameKey: "upgrade.resistance.1.name", descriptionKey: "upgrade.resistance.1.desc",
                    effect: UpgradeEffect(detectionResistanceBonus: 0.05)),
        UpgradeNode(id: "resistance.2", category: .resistance, tier: 2, cost: 18, prerequisiteID: "resistance.1",
                    nameKey: "upgrade.resistance.2.name", descriptionKey: "upgrade.resistance.2.desc",
                    effect: UpgradeEffect(detectionResistanceBonus: 0.08)),
        UpgradeNode(id: "resistance.3", category: .resistance, tier: 3, cost: 30, prerequisiteID: "resistance.2",
                    nameKey: "upgrade.resistance.3.name", descriptionKey: "upgrade.resistance.3.desc",
                    effect: UpgradeEffect(detectionResistanceBonus: 0.10)),
        UpgradeNode(id: "resistance.4", category: .resistance, tier: 4, cost: 50, prerequisiteID: "resistance.3",
                    nameKey: "upgrade.resistance.4.name", descriptionKey: "upgrade.resistance.4.desc",
                    effect: UpgradeEffect(detectionResistanceBonus: 0.12, bypassesLockdown: true)),
    ]

    private static let symptomsBranch: [UpgradeNode] = [
        UpgradeNode(id: "symptoms.1", category: .symptoms, tier: 1, cost: 10, prerequisiteID: nil,
                    nameKey: "upgrade.symptoms.1.name", descriptionKey: "upgrade.symptoms.1.desc",
                    effect: UpgradeEffect(lethalityBonus: 0.04, severityBonus: 0.05)),
        UpgradeNode(id: "symptoms.2", category: .symptoms, tier: 2, cost: 18, prerequisiteID: "symptoms.1",
                    nameKey: "upgrade.symptoms.2.name", descriptionKey: "upgrade.symptoms.2.desc",
                    effect: UpgradeEffect(lethalityBonus: 0.07, severityBonus: 0.08)),
        UpgradeNode(id: "symptoms.3", category: .symptoms, tier: 3, cost: 30, prerequisiteID: "symptoms.2",
                    nameKey: "upgrade.symptoms.3.name", descriptionKey: "upgrade.symptoms.3.desc",
                    effect: UpgradeEffect(lethalityBonus: 0.11, severityBonus: 0.12)),
        UpgradeNode(id: "symptoms.4", category: .symptoms, tier: 4, cost: 45, prerequisiteID: "symptoms.3",
                    nameKey: "upgrade.symptoms.4.name", descriptionKey: "upgrade.symptoms.4.desc",
                    effect: UpgradeEffect(lethalityBonus: 0.16, severityBonus: 0.16)),
    ]
}

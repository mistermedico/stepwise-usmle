import Foundation

/// A selectable fictional pathogen archetype. Purely a gameplay curve modifier —
/// no real-world disease is modeled or referenced.
public struct StrainDefinition: Identifiable, Codable, Equatable, Hashable {
    public let id: String
    public let nameKey: String
    public let taglineKey: String
    public let baseTransmissionRate: Double
    public let baseLethality: Double
    public let baseDetectionResistance: Double
    /// Flat bonus to daily evolution point income, this strain's signature trait.
    public let evolutionPointBonus: Double

    public init(
        id: String,
        nameKey: String,
        taglineKey: String,
        baseTransmissionRate: Double,
        baseLethality: Double,
        baseDetectionResistance: Double,
        evolutionPointBonus: Double
    ) {
        self.id = id
        self.nameKey = nameKey
        self.taglineKey = taglineKey
        self.baseTransmissionRate = baseTransmissionRate
        self.baseLethality = baseLethality
        self.baseDetectionResistance = baseDetectionResistance
        self.evolutionPointBonus = evolutionPointBonus
    }
}

public enum StrainCatalog {
    public static let balanced = StrainDefinition(
        id: "strain.balanced", nameKey: "strain.balanced.name", taglineKey: "strain.balanced.tagline",
        baseTransmissionRate: 0.16, baseLethality: 0.05, baseDetectionResistance: 0.05, evolutionPointBonus: 0
    )
    public static let silent = StrainDefinition(
        id: "strain.silent", nameKey: "strain.silent.name", taglineKey: "strain.silent.tagline",
        baseTransmissionRate: 0.12, baseLethality: 0.02, baseDetectionResistance: 0.16, evolutionPointBonus: 0
    )
    public static let virulent = StrainDefinition(
        id: "strain.virulent", nameKey: "strain.virulent.name", taglineKey: "strain.virulent.tagline",
        baseTransmissionRate: 0.14, baseLethality: 0.12, baseDetectionResistance: 0, evolutionPointBonus: 0.3
    )
    public static let opportunist = StrainDefinition(
        id: "strain.opportunist", nameKey: "strain.opportunist.name", taglineKey: "strain.opportunist.tagline",
        baseTransmissionRate: 0.22, baseLethality: 0.03, baseDetectionResistance: 0.02, evolutionPointBonus: 0
    )

    public static let all: [StrainDefinition] = [balanced, silent, virulent, opportunist]

    public static func strain(_ id: String) -> StrainDefinition {
        all.first { $0.id == id } ?? balanced
    }
}

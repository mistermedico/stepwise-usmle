import Foundation

/// Stable identifier for a `Region`. Regions are fictional, abstract landmasses —
/// never real countries — so the game stays clearly a piece of light sci-fi fiction.
public typealias RegionID = String

/// A single abstract territory on the world map graph. Static definition only;
/// mutable per-game data lives in `RegionState`.
public struct Region: Identifiable, Codable, Equatable, Hashable {
    public let id: RegionID
    /// Localization key, e.g. "region.meridian_delta.name"
    public let nameKey: String
    /// Abstract population weight (not a real-world figure), used to size the spread curve.
    public let population: Double
    /// Base 0...1 friction the pathogen must overcome to spread *within* this region
    /// once seeded. Lower = spreads internally faster.
    public let internalResistance: Double
    /// 0...1 — how strongly this region function as a transport hub. Hubs accelerate
    /// spread to neighbors but are also first to raise global awareness once infected.
    public let hubFactor: Double
    /// Adjacent regions this one can spread to directly.
    public let neighborIDs: [RegionID]

    public init(
        id: RegionID,
        nameKey: String,
        population: Double,
        internalResistance: Double,
        hubFactor: Double,
        neighborIDs: [RegionID]
    ) {
        self.id = id
        self.nameKey = nameKey
        self.population = population
        self.internalResistance = internalResistance
        self.hubFactor = hubFactor
        self.neighborIDs = neighborIDs
    }
}

/// Mutable per-game state tracked for each region as the outbreak evolves.
public struct RegionState: Codable, Equatable, Hashable {
    public var infectionLevel: Double = 0 // 0...1
    public var awarenessLevel: Double = 0 // 0...1
    public var isLockedDown: Bool = false
    public var isDiscovered: Bool = false

    public init(
        infectionLevel: Double = 0,
        awarenessLevel: Double = 0,
        isLockedDown: Bool = false,
        isDiscovered: Bool = false
    ) {
        self.infectionLevel = infectionLevel
        self.awarenessLevel = awarenessLevel
        self.isLockedDown = isLockedDown
        self.isDiscovered = isDiscovered
    }

    public static let clean = RegionState()
}

import Foundation

/// A starting-world layout: the abstract region graph plus where patient zero appears.
public struct WorldScenario: Identifiable, Codable, Equatable, Hashable {
    public let id: String
    public let nameKey: String
    public let descriptionKey: String
    public let regions: [Region]
    public let startingRegionID: RegionID

    public init(id: String, nameKey: String, descriptionKey: String, regions: [Region], startingRegionID: RegionID) {
        self.id = id
        self.nameKey = nameKey
        self.descriptionKey = descriptionKey
        self.regions = regions
        self.startingRegionID = startingRegionID
    }

    public func region(_ id: RegionID) -> Region? {
        regions.first { $0.id == id }
    }
}

public enum ScenarioCatalog {
    /// Slow but safe: an isolated starting region with few, weak connections.
    public static let isolatedTerritory = WorldScenario(
        id: "scenario.isolated",
        nameKey: "scenario.isolated.name",
        descriptionKey: "scenario.isolated.desc",
        regions: [
            Region(id: "outland", nameKey: "region.outland.name", population: 0.6,
                   internalResistance: 0.35, hubFactor: 0.05, neighborIDs: ["gatecross"]),
            Region(id: "gatecross", nameKey: "region.gatecross.name", population: 1.0,
                   internalResistance: 0.3, hubFactor: 0.2, neighborIDs: ["outland", "meridianDelta"]),
            Region(id: "meridianDelta", nameKey: "region.meridian_delta.name", population: 1.6,
                   internalResistance: 0.25, hubFactor: 0.4, neighborIDs: ["gatecross", "harborReach", "duskvale"]),
            Region(id: "harborReach", nameKey: "region.harbor_reach.name", population: 1.4,
                   internalResistance: 0.2, hubFactor: 0.55, neighborIDs: ["meridianDelta", "cinderplex"]),
            Region(id: "duskvale", nameKey: "region.duskvale.name", population: 1.1,
                   internalResistance: 0.28, hubFactor: 0.25, neighborIDs: ["meridianDelta", "cinderplex"]),
            Region(id: "cinderplex", nameKey: "region.cinderplex.name", population: 2.0,
                   internalResistance: 0.15, hubFactor: 0.8, neighborIDs: ["harborReach", "duskvale"]),
        ],
        startingRegionID: "outland"
    )

    /// Fast but exposed: patient zero starts in the world's busiest transport hub.
    public static let transportHub = WorldScenario(
        id: "scenario.hub",
        nameKey: "scenario.hub.name",
        descriptionKey: "scenario.hub.desc",
        regions: [
            Region(id: "cinderplex", nameKey: "region.cinderplex.name", population: 2.0,
                   internalResistance: 0.15, hubFactor: 0.8, neighborIDs: ["harborReach", "duskvale", "meridianDelta"]),
            Region(id: "harborReach", nameKey: "region.harbor_reach.name", population: 1.4,
                   internalResistance: 0.2, hubFactor: 0.55, neighborIDs: ["cinderplex", "meridianDelta"]),
            Region(id: "duskvale", nameKey: "region.duskvale.name", population: 1.1,
                   internalResistance: 0.28, hubFactor: 0.25, neighborIDs: ["cinderplex", "meridianDelta"]),
            Region(id: "meridianDelta", nameKey: "region.meridian_delta.name", population: 1.6,
                   internalResistance: 0.25, hubFactor: 0.4, neighborIDs: ["cinderplex", "harborReach", "duskvale", "gatecross"]),
            Region(id: "gatecross", nameKey: "region.gatecross.name", population: 1.0,
                   internalResistance: 0.3, hubFactor: 0.2, neighborIDs: ["meridianDelta", "outland"]),
            Region(id: "outland", nameKey: "region.outland.name", population: 0.6,
                   internalResistance: 0.35, hubFactor: 0.05, neighborIDs: ["gatecross"]),
        ],
        startingRegionID: "cinderplex"
    )

    public static let all: [WorldScenario] = [isolatedTerritory, transportHub]

    public static func scenario(_ id: String) -> WorldScenario {
        all.first { $0.id == id } ?? isolatedTerritory
    }
}

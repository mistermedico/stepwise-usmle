import Foundation

/// The board. Twelve invented territories laid out as interlocking geometric
/// pieces on a normalised `0...1` canvas — deliberately not a map of anywhere.
public enum RegionCatalog {

    public static let all: [RegionBlueprint] = [
        RegionBlueprint(
            id: .northreach, population: 340_000_000, climate: .frigid,
            wealth: .affluent, density: .urban,
            neighbors: [.coldspire, .verdanmoor],
            hasAirport: true, hasSeaport: true, isStartCandidate: true,
            mapCenter: MapPoint(0.23, 0.14),
            mapShape: piece(0.10, 0.04, 0.36, 0.24, variant: 0)
        ),
        RegionBlueprint(
            id: .coldspire, population: 145_000_000, climate: .frigid,
            wealth: .developing, density: .rural,
            neighbors: [.northreach, .palewind],
            hasAirport: true, hasSeaport: true, isStartCandidate: true,
            mapCenter: MapPoint(0.51, 0.14),
            mapShape: piece(0.40, 0.04, 0.62, 0.24, variant: 1)
        ),
        RegionBlueprint(
            id: .farhaven, population: 95_000_000, climate: .frigid,
            wealth: .affluent, density: .rural,
            neighbors: [],
            hasAirport: true, hasSeaport: true, isStartCandidate: true,
            mapCenter: MapPoint(0.88, 0.14),
            mapShape: piece(0.80, 0.04, 0.96, 0.24, variant: 2)
        ),
        RegionBlueprint(
            id: .verdanmoor, population: 520_000_000, climate: .temperate,
            wealth: .affluent, density: .urban,
            neighbors: [.northreach, .palewind, .ashenvale],
            hasAirport: true, hasSeaport: true, isStartCandidate: true,
            mapCenter: MapPoint(0.18, 0.37),
            mapShape: piece(0.06, 0.27, 0.30, 0.47, variant: 3)
        ),
        RegionBlueprint(
            id: .palewind, population: 210_000_000, climate: .temperate,
            wealth: .developing, density: .rural,
            neighbors: [.coldspire, .verdanmoor, .highbarrow, .goldensands],
            hasAirport: false, hasSeaport: true, isStartCandidate: true,
            mapCenter: MapPoint(0.45, 0.37),
            mapShape: piece(0.34, 0.27, 0.56, 0.47, variant: 0)
        ),
        RegionBlueprint(
            id: .highbarrow, population: 1_300_000_000, climate: .temperate,
            wealth: .developing, density: .urban,
            neighbors: [.palewind, .stillwater],
            hasAirport: true, hasSeaport: true, isStartCandidate: true,
            mapCenter: MapPoint(0.76, 0.37),
            mapShape: piece(0.60, 0.27, 0.92, 0.47, variant: 1)
        ),
        RegionBlueprint(
            id: .ashenvale, population: 430_000_000, climate: .arid,
            wealth: .developing, density: .rural,
            neighbors: [.verdanmoor, .goldensands, .emberfall],
            hasAirport: true, hasSeaport: true, isStartCandidate: true,
            mapCenter: MapPoint(0.20, 0.60),
            mapShape: piece(0.08, 0.50, 0.32, 0.70, variant: 2)
        ),
        RegionBlueprint(
            id: .goldensands, population: 380_000_000, climate: .arid,
            wealth: .developing, density: .rural,
            neighbors: [.palewind, .ashenvale, .stillwater, .tidecrest],
            hasAirport: true, hasSeaport: true, isStartCandidate: true,
            mapCenter: MapPoint(0.47, 0.60),
            mapShape: piece(0.36, 0.50, 0.58, 0.70, variant: 3)
        ),
        RegionBlueprint(
            id: .stillwater, population: 1_150_000_000, climate: .tropical,
            wealth: .developing, density: .urban,
            neighbors: [.highbarrow, .goldensands, .sunwake],
            hasAirport: true, hasSeaport: true, isStartCandidate: true,
            mapCenter: MapPoint(0.78, 0.60),
            mapShape: piece(0.62, 0.50, 0.94, 0.70, variant: 0)
        ),
        RegionBlueprint(
            id: .emberfall, population: 610_000_000, climate: .tropical,
            wealth: .developing, density: .urban,
            neighbors: [.ashenvale, .tidecrest],
            hasAirport: true, hasSeaport: true, isStartCandidate: true,
            mapCenter: MapPoint(0.24, 0.835),
            mapShape: piece(0.12, 0.73, 0.36, 0.94, variant: 1)
        ),
        RegionBlueprint(
            id: .tidecrest, population: 290_000_000, climate: .tropical,
            wealth: .developing, density: .rural,
            neighbors: [.goldensands, .emberfall, .sunwake],
            hasAirport: false, hasSeaport: true, isStartCandidate: true,
            mapCenter: MapPoint(0.50, 0.835),
            mapShape: piece(0.40, 0.73, 0.60, 0.94, variant: 2)
        ),
        RegionBlueprint(
            id: .sunwake, population: 260_000_000, climate: .tropical,
            wealth: .affluent, density: .urban,
            neighbors: [.stillwater, .tidecrest],
            hasAirport: true, hasSeaport: true, isStartCandidate: true,
            mapCenter: MapPoint(0.77, 0.835),
            mapShape: piece(0.64, 0.73, 0.90, 0.94, variant: 3)
        )
    ]

    private static let index: [RegionID: RegionBlueprint] = {
        Dictionary(uniqueKeysWithValues: all.map { ($0.id, $0) })
    }()

    /// Blueprint lookup. Every `RegionID` has exactly one blueprint — guarded by
    /// `RegionCatalogTests.testEveryRegionHasABlueprint`.
    public static func blueprint(_ id: RegionID) -> RegionBlueprint {
        guard let found = index[id] else {
            preconditionFailure("Missing blueprint for region \(id.rawValue)")
        }
        return found
    }

    public static let worldPopulation: Int = all.reduce(0) { $0 + $1.population }

    public static func initialStates() -> [RegionID: RegionState] {
        Dictionary(uniqueKeysWithValues: all.map {
            ($0.id, RegionState(id: $0.id, population: $0.population))
        })
    }

    /// Territories with the fewest links — the quiet start.
    public static var lowConnectivityStarts: [RegionID] {
        [.farhaven, .tidecrest, .coldspire]
    }

    /// Territories with the most links — the loud start.
    public static var hubStarts: [RegionID] {
        [.highbarrow, .stillwater, .verdanmoor, .goldensands]
    }

    /// Picks patient-zero ground for a scenario. Deterministic for a given seed.
    public static func startRegion(
        for scenario: StartScenario,
        using generator: inout SeededGenerator
    ) -> RegionID {
        let pool: [RegionID]
        switch scenario {
        case .isolatedIsland: pool = lowConnectivityStarts
        case .transitHub: pool = hubStarts
        case .wildcard: pool = all.filter(\.isStartCandidate).map(\.id)
        }
        return generator.pick(pool) ?? .highbarrow
    }

    /// Builds an eight-sided piece inside the given bounds. `variant` only
    /// changes how the corners are cut, which is what gives the board its
    /// hand-cut, interlocking look without any geographic outline.
    static func piece(
        _ x0: Double, _ y0: Double, _ x1: Double, _ y1: Double, variant: Int
    ) -> [MapPoint] {
        let width = x1 - x0
        let height = y1 - y0
        let cuts = [0.10, 0.16, 0.22, 0.13]
        let cut = cuts[((variant % cuts.count) + cuts.count) % cuts.count]
        let cx = width * cut
        let cy = height * cut
        return [
            MapPoint(x0 + cx, y0),
            MapPoint(x1 - cx * 0.6, y0),
            MapPoint(x1, y0 + cy),
            MapPoint(x1, y1 - cy * 0.8),
            MapPoint(x1 - cx, y1),
            MapPoint(x0 + cx * 0.7, y1),
            MapPoint(x0, y1 - cy),
            MapPoint(x0, y0 + cy * 0.9)
        ]
    }
}

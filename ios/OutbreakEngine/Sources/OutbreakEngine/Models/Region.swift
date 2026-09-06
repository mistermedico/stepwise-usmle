import Foundation

/// The twelve abstract territories of the fictional board.
///
/// These are invented places on an invented world. They deliberately do not map
/// onto real countries, borders or populations.
public enum RegionID: String, CaseIterable, Codable, Hashable, Identifiable, Sendable {
    case northreach
    case coldspire
    case verdanmoor
    case palewind
    case highbarrow
    case ashenvale
    case goldensands
    case emberfall
    case tidecrest
    case stillwater
    case sunwake
    case farhaven

    public var id: String { rawValue }

    /// Key into `Localizable.strings` (`region.northreach` …).
    public var localizationKey: String { "region.\(rawValue)" }
}

/// Environmental band of a territory. Drives the climate tolerance trade-off.
public enum Climate: String, CaseIterable, Codable, Hashable, Sendable {
    case frigid
    case temperate
    case arid
    case tropical

    /// How hostile the band is to an unadapted strain, as an additive modifier
    /// on the spread coefficient. Documented here because the balance tests
    /// assert against these exact numbers.
    public var baseSpreadModifier: Double {
        switch self {
        case .frigid: return -0.35
        case .temperate: return 0.0
        case .arid: return -0.25
        case .tropical: return 0.10
        }
    }

    public var localizationKey: String { "climate.\(rawValue)" }
}

/// Infrastructure tier. Wealthy territories notice and research faster;
/// developing ones spread faster.
public enum Wealth: String, CaseIterable, Codable, Hashable, Sendable {
    case affluent
    case developing

    public var awarenessMultiplier: Double {
        switch self {
        case .affluent: return 1.35
        case .developing: return 0.80
        }
    }

    public var researchWeight: Double {
        switch self {
        case .affluent: return 1.6
        case .developing: return 0.5
        }
    }

    public var spreadMultiplier: Double {
        switch self {
        case .affluent: return 0.85
        case .developing: return 1.15
        }
    }

    public var localizationKey: String { "wealth.\(rawValue)" }
}

/// Settlement pattern. Urban territories amplify contact spread.
public enum Density: String, CaseIterable, Codable, Hashable, Sendable {
    case urban
    case rural

    public var spreadMultiplier: Double {
        switch self {
        case .urban: return 1.20
        case .rural: return 0.85
        }
    }

    public var localizationKey: String { "density.\(rawValue)" }
}

/// Immutable description of a territory. Loaded once from `RegionCatalog`.
public struct RegionBlueprint: Equatable, Hashable, Sendable {
    public let id: RegionID
    public let population: Int
    public let climate: Climate
    public let wealth: Wealth
    public let density: Density
    /// Land routes. Always symmetric — `RegionCatalog` has a test that proves it.
    public let neighbors: [RegionID]
    public let hasAirport: Bool
    public let hasSeaport: Bool
    /// Whether the territory may be chosen as patient-zero ground.
    public let isStartCandidate: Bool
    /// Normalised centre on the abstract map, `0...1` in both axes.
    public let mapCenter: MapPoint
    /// Convex-ish outline used by the map renderer, normalised `0...1`.
    public let mapShape: [MapPoint]

    public init(
        id: RegionID,
        population: Int,
        climate: Climate,
        wealth: Wealth,
        density: Density,
        neighbors: [RegionID],
        hasAirport: Bool,
        hasSeaport: Bool,
        isStartCandidate: Bool,
        mapCenter: MapPoint,
        mapShape: [MapPoint]
    ) {
        self.id = id
        self.population = population
        self.climate = climate
        self.wealth = wealth
        self.density = density
        self.neighbors = neighbors
        self.hasAirport = hasAirport
        self.hasSeaport = hasSeaport
        self.isStartCandidate = isStartCandidate
        self.mapCenter = mapCenter
        self.mapShape = mapShape
    }
}

/// A point in normalised map space. Declared here (rather than using `CGPoint`)
/// so the engine stays free of platform frameworks.
public struct MapPoint: Equatable, Hashable, Codable, Sendable {
    public let x: Double
    public let y: Double

    public init(_ x: Double, _ y: Double) {
        self.x = x
        self.y = y
    }
}

/// Mutable per-territory state for one run.
public struct RegionState: Equatable, Codable, Sendable {
    public let id: RegionID
    public let population: Int

    /// People currently carrying the strain.
    public var infected: Double
    /// Cumulative losses.
    public var lost: Double
    /// Local response awareness, `0...100`.
    public var awareness: Double
    /// Air and sea links suspended.
    public var transportLocked: Bool
    /// Land routes suspended. Always implies `transportLocked`.
    public var bordersClosed: Bool
    /// Day the territory first registered a carrier, `nil` while untouched.
    public var firstInfectedDay: Int?

    public init(id: RegionID, population: Int) {
        self.id = id
        self.population = population
        self.infected = 0
        self.lost = 0
        self.awareness = 0
        self.transportLocked = false
        self.bordersClosed = false
        self.firstInfectedDay = nil
    }

    /// People never touched by the strain.
    public var healthy: Double {
        max(0, Double(population) - infected - lost)
    }

    /// Share of the original population currently carrying the strain, `0...1`.
    public var infectedFraction: Double {
        population > 0 ? min(1, infected / Double(population)) : 0
    }

    /// Share of the original population already lost, `0...1`.
    public var lostFraction: Double {
        population > 0 ? min(1, lost / Double(population)) : 0
    }

    /// Share of the population no longer healthy, `0...1`.
    public var touchedFraction: Double {
        population > 0 ? min(1, (infected + lost) / Double(population)) : 0
    }

    public var isInfected: Bool { infected >= 1 || lost >= 1 }

    /// A territory counts as fully consumed once effectively nobody is healthy.
    public var isSaturated: Bool { healthy < max(1, Double(population) * 0.0005) }
}

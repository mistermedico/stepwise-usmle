import Foundation

/// A notable moment produced by the simulation. Events drive the news ticker
/// during play and the timeline on the summary screen.
public struct GameEvent: Equatable, Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public let day: Int
    public let kind: Kind

    public init(id: UUID = UUID(), day: Int, kind: Kind) {
        self.id = id
        self.day = day
        self.kind = kind
    }

    public enum Kind: Equatable, Codable, Hashable, Sendable {
        case outbreakBegan(region: RegionID)
        case regionInfected(region: RegionID, route: TravelRoute)
        case strainDetected
        case researchBegan
        case transportLocked(region: RegionID)
        case bordersClosed(region: RegionID)
        case restrictionsLifted(region: RegionID)
        case traitUnlocked(trait: TraitID)
        case traitFolded(trait: TraitID)
        case driftMutation(trait: TraitID)
        case regionSaturated(region: RegionID)
        case researchMilestone(percent: Int)
        case victory
        case defeat(reason: DefeatReason)

        /// Weight used to decide what makes it onto the report timeline.
        public var isMilestone: Bool {
            switch self {
            case .outbreakBegan, .strainDetected, .researchBegan,
                 .researchMilestone, .victory, .defeat:
                return true
            default:
                return false
            }
        }
    }

    public var localizationKey: String {
        switch kind {
        case .outbreakBegan: return "event.outbreakBegan"
        case .regionInfected: return "event.regionInfected"
        case .strainDetected: return "event.strainDetected"
        case .researchBegan: return "event.researchBegan"
        case .transportLocked: return "event.transportLocked"
        case .bordersClosed: return "event.bordersClosed"
        case .restrictionsLifted: return "event.restrictionsLifted"
        case .traitUnlocked: return "event.traitUnlocked"
        case .traitFolded: return "event.traitFolded"
        case .driftMutation: return "event.driftMutation"
        case .regionSaturated: return "event.regionSaturated"
        case .researchMilestone: return "event.researchMilestone"
        case .victory: return "event.victory"
        case .defeat: return "event.defeat"
        }
    }
}

/// How the strain reached a new territory.
public enum TravelRoute: String, Codable, Hashable, CaseIterable, Sendable {
    case land
    case air
    case sea

    public var localizationKey: String { "route.\(rawValue)" }
}

public enum DefeatReason: String, Codable, Hashable, Sendable {
    /// The response found a solution first.
    case solutionFound
    /// The strain burned out before reaching everyone.
    case burnedOut
    /// A daily-challenge condition was broken.
    case objectiveFailed

    public var localizationKey: String { "defeat.\(rawValue)" }
}

/// A collectable point cluster surfaced on the map.
public struct PointBubble: Equatable, Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public let region: RegionID
    public let value: Int
    public let spawnedOnDay: Int
    /// Bubble disappears after this day.
    public let expiresOnDay: Int
    /// Position within the territory outline, normalised `0...1`.
    public let offset: MapPoint

    public init(
        id: UUID = UUID(),
        region: RegionID,
        value: Int,
        spawnedOnDay: Int,
        expiresOnDay: Int,
        offset: MapPoint
    ) {
        self.id = id
        self.region = region
        self.value = value
        self.spawnedOnDay = spawnedOnDay
        self.expiresOnDay = expiresOnDay
        self.offset = offset
    }
}

import Foundation

public enum GameOutcome: String, Codable, Equatable {
    case victory
    case defeat
}

/// One day's worth of world state, recorded for the end-of-run report timeline.
public struct DaySnapshot: Codable, Equatable, Hashable {
    public let day: Int
    public let globalInfectionFraction: Double
    public let globalAwareness: Double
    public let researchProgress: Double
    public let regionsInfected: Int
    public let regionsLockedDown: Int

    public init(
        day: Int,
        globalInfectionFraction: Double,
        globalAwareness: Double,
        researchProgress: Double,
        regionsInfected: Int,
        regionsLockedDown: Int
    ) {
        self.day = day
        self.globalInfectionFraction = globalInfectionFraction
        self.globalAwareness = globalAwareness
        self.researchProgress = researchProgress
        self.regionsInfected = regionsInfected
        self.regionsLockedDown = regionsLockedDown
    }
}

/// Descriptive title assigned to a finished run for the shareable report screen.
/// Determined purely from the recorded timeline, matching spec section 2.5.
public enum OutbreakCharacter: String, Codable, Equatable, Hashable {
    case silentOutbreak       // "Silent Outbreak" — won with low peak awareness
    case lightningOutbreak    // "Lightning Outbreak" — won very quickly
    case grindingSiege        // won, but slowly and with heavy lockdowns
    case containedEarly       // lost, snuffed out before it spread far
    case nearMiss             // lost, but infection was nearly total

    public var titleKey: String { "report.character.\(rawValue)" }
}

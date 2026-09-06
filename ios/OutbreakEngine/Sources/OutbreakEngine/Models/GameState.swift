import Foundation

public enum GameOutcome: Equatable, Codable, Hashable, Sendable {
    case victory
    case defeat(DefeatReason)
}

/// The complete, serialisable state of one run.
///
/// Everything the simulation needs lives here; `SimulationEngine` is a pure
/// function of `(GameState, player action)`. That is what makes the rule tests
/// possible without a simulator.
public struct GameState: Equatable, Codable, Sendable {

    // MARK: Set-up

    public let setup: GameSetup
    public let originRegion: RegionID

    // MARK: Clock

    public private(set) var day: Int

    // MARK: Player resources

    public var evolutionPoints: Int
    /// Fractional income carried between days so slow strains still earn.
    public var pointRemainder: Double
    public private(set) var pointsSpent: Int
    public private(set) var unlockedTraits: Set<TraitID>

    // MARK: Board

    public var regions: [RegionID: RegionState]

    // MARK: Global response

    /// Population-weighted awareness, `0...100`.
    public var globalAwareness: Double
    /// Progress toward a solution, `0...100`. At 100 the run is lost.
    public var researchProgress: Double
    public var isDetected: Bool
    public var detectionDay: Int?
    public var researchStartDay: Int?

    // MARK: Bookkeeping

    public var events: [GameEvent]
    public var bubbles: [PointBubble]
    public var outcome: GameOutcome?
    /// Highest summed lethality reached, for objective checking and the report.
    public var peakLethality: Double
    /// Territories that had a carrier at any point.
    public var touchedRegions: Set<RegionID>
    /// Number of territories infected at the moment of detection.
    public var regionsAtDetection: Int?
    public var generator: SeededGenerator

    // MARK: Init

    public init(setup: GameSetup, originRegion: RegionID, generator: SeededGenerator) {
        self.setup = setup
        self.originRegion = originRegion
        self.day = 0
        self.evolutionPoints = setup.difficulty.startingPoints
        self.pointRemainder = 0
        self.pointsSpent = 0
        self.unlockedTraits = []
        self.regions = RegionCatalog.initialStates()
        self.globalAwareness = 0
        self.researchProgress = 0
        self.isDetected = false
        self.detectionDay = nil
        self.researchStartDay = nil
        self.events = []
        self.bubbles = []
        self.outcome = nil
        self.peakLethality = 0
        self.touchedRegions = []
        self.regionsAtDetection = nil
        self.generator = generator
    }

    // MARK: Derived board figures

    public var worldPopulation: Int { RegionCatalog.worldPopulation }

    public var totalInfected: Double {
        regions.values.reduce(0) { $0 + $1.infected }
    }

    public var totalLost: Double {
        regions.values.reduce(0) { $0 + $1.lost }
    }

    public var totalHealthy: Double {
        max(0, Double(worldPopulation) - totalInfected - totalLost)
    }

    /// Share of the world no longer healthy, `0...1`.
    public var worldTouchedFraction: Double {
        guard worldPopulation > 0 else { return 0 }
        return min(1, (totalInfected + totalLost) / Double(worldPopulation))
    }

    public var infectedRegionCount: Int {
        regions.values.filter(\.isInfected).count
    }

    public var lockedRegionCount: Int {
        regions.values.filter(\.transportLocked).count
    }

    public var isFinished: Bool { outcome != nil }

    /// The strain as it stands today: innate package plus every unlocked trait.
    public var profile: EvolutionProfile {
        var summed = StrainCatalog.strain(setup.strain).innateEffects
        for id in unlockedTraits {
            summed = summed + TraitCatalog.trait(id).effects
        }
        return EvolutionProfile(effects: summed)
    }

    // MARK: Mutation helpers (kept here so invariants stay in one place)

    public mutating func advanceClock() {
        day += 1
    }

    public mutating func record(_ kind: GameEvent.Kind) {
        events.append(GameEvent(day: day, kind: kind))
    }

    /// Unlocks a node, charging the player. Callers must check `canUnlock` first;
    /// this is a no-op when the node is not affordable or not open.
    @discardableResult
    public mutating func unlock(_ id: TraitID) -> Bool {
        guard canUnlock(id) else { return false }
        let trait = TraitCatalog.trait(id)
        evolutionPoints -= trait.cost
        pointsSpent += trait.cost
        unlockedTraits.insert(id)
        record(.traitUnlocked(trait: id))
        peakLethality = max(peakLethality, profile.lethality)
        return true
    }

    /// Folds a node back, refunding part of its cost. Blocked while another
    /// unlocked node still depends on it.
    @discardableResult
    public mutating func fold(_ id: TraitID) -> Bool {
        guard canFold(id) else { return false }
        let trait = TraitCatalog.trait(id)
        evolutionPoints += trait.refund
        pointsSpent = max(0, pointsSpent - trait.refund)
        unlockedTraits.remove(id)
        record(.traitFolded(trait: id))
        return true
    }

    /// A drift mutation granted by the strain signature — free, and not chosen
    /// by the player.
    public mutating func applyDriftMutation(_ id: TraitID) {
        guard !unlockedTraits.contains(id) else { return }
        unlockedTraits.insert(id)
        record(.driftMutation(trait: id))
        peakLethality = max(peakLethality, profile.lethality)
    }

    public func isUnlocked(_ id: TraitID) -> Bool { unlockedTraits.contains(id) }

    /// Prerequisites satisfied — the node is visible and reachable.
    public func isAvailable(_ id: TraitID) -> Bool {
        guard !unlockedTraits.contains(id) else { return false }
        return TraitCatalog.trait(id).prerequisites.allSatisfy { unlockedTraits.contains($0) }
    }

    public func canUnlock(_ id: TraitID) -> Bool {
        guard !isFinished else { return false }
        guard isAvailable(id) else { return false }
        return evolutionPoints >= TraitCatalog.trait(id).cost
    }

    /// A node can be folded only when nothing unlocked depends on it.
    public func canFold(_ id: TraitID) -> Bool {
        guard !isFinished, unlockedTraits.contains(id) else { return false }
        let dependents = TraitCatalog.all.filter { $0.prerequisites.contains(id) }
        return !dependents.contains { unlockedTraits.contains($0.id) }
    }

    /// Collects a bubble, if it is still on the board.
    @discardableResult
    public mutating func collectBubble(_ bubbleID: UUID) -> Int {
        guard let index = bubbles.firstIndex(where: { $0.id == bubbleID }) else { return 0 }
        let value = bubbles[index].value
        bubbles.remove(at: index)
        evolutionPoints += value
        return value
    }
}

import Foundation

/// Drives one full day of simulation: spread, world response, scoring, and the
/// win/lose check. Pure `GameState -> GameState`, so it can be exercised in unit
/// tests with zero UI, timers, or a simulator (spec section 8.2).
public enum OutbreakSimulationEngine {

    /// Advances the game by exactly one day and returns the resulting state.
    /// No-op (returns state unchanged) once the run already has an outcome.
    public static func advanceOneDay(_ state: GameState) -> GameState {
        guard state.isRunning else { return state }
        var next = state
        next.day += 1

        spreadInfection(&next)
        WorldResponseEngine.updateAwareness(&next)
        WorldResponseEngine.updateResearch(&next)
        WorldResponseEngine.applyLockdowns(&next)
        awardEvolutionPoints(&next)

        next.outcome = WorldResponseEngine.evaluateOutcome(next)
        next.history.append(snapshot(of: next))
        return next
    }

    /// Applies an upgrade purchase. Returns the state unchanged if the node is
    /// unaffordable, already unlocked, or its prerequisite is missing.
    public static func purchaseUpgrade(_ state: GameState, nodeID: String) -> GameState {
        guard let node = UpgradeCatalog.node(nodeID) else { return state }
        guard !state.unlockedUpgradeIDs.contains(nodeID) else { return state }
        guard state.evolutionPoints >= Double(node.cost) else { return state }
        if let prerequisite = node.prerequisiteID, !state.unlockedUpgradeIDs.contains(prerequisite) {
            return state
        }
        var next = state
        next.evolutionPoints -= Double(node.cost)
        next.unlockedUpgradeIDs.insert(nodeID)
        return next
    }

    // MARK: - Internal steps

    private static func spreadInfection(_ state: inout GameState) {
        let transmissionRate = state.effectiveTransmissionRate
        var deltas: [RegionID: Double] = [:]

        for region in state.scenario.regions {
            guard let sourceState = state.regionStates[region.id], sourceState.infectionLevel > 0 else { continue }

            // Internal growth: an infected region keeps saturating toward 1.0.
            let headroom = 1 - sourceState.infectionLevel
            let internalGrowth = headroom * WorldResponseRules.baseInternalGrowthRate
                * (1 - region.internalResistance) * (1 + transmissionRate)
            deltas[region.id, default: 0] += internalGrowth

            guard !sourceState.isLockedDown || state.hasLockdownBypass else { continue }

            // Cross-border spread to neighbors, weighted by hub factor and how
            // saturated the source region already is (more carriers, more spread).
            for neighborID in region.neighborIDs {
                guard let neighborRegion = state.scenario.region(neighborID),
                      let neighborState = state.regionStates[neighborID] else { continue }
                if neighborState.isLockedDown && !state.hasLockdownBypass { continue }

                let neighborHeadroom = 1 - neighborState.infectionLevel
                let spreadChance = transmissionRate * sourceState.infectionLevel
                    * (1 + region.hubFactor) * (1 - neighborRegion.internalResistance)
                let seedGrowth = neighborHeadroom * spreadChance * 0.5
                deltas[neighborID, default: 0] += seedGrowth
            }
        }

        for (regionID, delta) in deltas {
            guard var regionState = state.regionStates[regionID] else { continue }
            regionState.infectionLevel = min(1, max(0, regionState.infectionLevel + delta))
            state.regionStates[regionID] = regionState
        }
    }

    private static func awardEvolutionPoints(_ state: inout GameState) {
        state.evolutionPoints += state.difficulty.baseEvolutionPointsPerDay + state.strain.evolutionPointBonus
    }

    private static func snapshot(of state: GameState) -> DaySnapshot {
        DaySnapshot(
            day: state.day,
            globalInfectionFraction: state.globalInfectionFraction,
            globalAwareness: state.globalAwareness,
            researchProgress: state.researchProgress,
            regionsInfected: state.regionsInfectedCount,
            regionsLockedDown: state.regionsLockedDownCount
        )
    }
}

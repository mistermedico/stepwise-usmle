import Foundation

/// The "Global Response System" mentioned in the design spec: a small set of explicit,
/// deterministic rule functions that react to what is currently *visible* about the
/// outbreak. No machine learning, no hidden state — every rule is a pure function of
/// the current `GameState` and is covered by `WorldResponseEngineTests`.
public enum WorldResponseEngine {

    /// Rule 1 + 2: raises global and per-region awareness from visible infection × lethality.
    public static func updateAwareness(_ state: inout GameState) {
        let resistance = state.effectiveDetectionResistance
        let lethality = max(state.effectiveLethality, 0.01) // a fully asymptomatic strain still leaves faint traces

        for region in state.scenario.regions {
            guard var regionState = state.regionStates[region.id], regionState.infectionLevel > 0 else { continue }

            if !regionState.isDiscovered, regionState.infectionLevel > 0.05 {
                regionState.isDiscovered = true
            }

            if regionState.isDiscovered {
                let visibility = regionState.infectionLevel * lethality * (1 + region.hubFactor)
                let rawDelta = visibility * WorldResponseRules.awarenessGainCoefficient
                    * state.difficulty.awarenessGrowthMultiplier
                let dampedDelta = rawDelta * (1 - resistance)
                regionState.awarenessLevel = min(1, regionState.awarenessLevel + max(0, dampedDelta))
            }

            state.regionStates[region.id] = regionState
        }

        let discoveredRegions = state.scenario.regions.filter { state.regionStates[$0.id]?.isDiscovered == true }
        if !discoveredRegions.isEmpty {
            let averageAwareness = discoveredRegions.reduce(0.0) { sum, region in
                sum + (state.regionStates[region.id]?.awarenessLevel ?? 0)
            } / Double(discoveredRegions.count)
            // Global awareness only ever climbs — the world doesn't forget what it has seen.
            state.globalAwareness = min(1, max(state.globalAwareness, averageAwareness))
        }
    }

    /// Rule 3: activates research once global awareness crosses the threshold, then
    /// accrues it at a fixed, difficulty-defined daily rate — never randomized, so
    /// `GameState.projectedCureDay` is always exact.
    public static func updateResearch(_ state: inout GameState) {
        if !state.isResearchActive && state.globalAwareness >= WorldResponseRules.researchActivationThreshold {
            state.isResearchActive = true
            state.researchActivatedOnDay = state.day
        }
        guard state.isResearchActive else { return }
        state.researchProgress = min(
            state.difficulty.researchCompletionThreshold,
            state.researchProgress + state.difficulty.dailyResearchRate
        )
    }

    /// Rule 4: locks down any region whose own awareness crosses the difficulty's
    /// lockdown threshold, unless the pathogen has unlocked a bypass upgrade.
    public static func applyLockdowns(_ state: inout GameState) {
        guard !state.hasLockdownBypass else { return }
        let threshold = state.difficulty.lockdownAwarenessThreshold
        for region in state.scenario.regions {
            guard var regionState = state.regionStates[region.id] else { continue }
            if regionState.awarenessLevel >= threshold {
                regionState.isLockedDown = true
                state.regionStates[region.id] = regionState
            }
        }
    }

    /// Rule 5: evaluates the fixed win/lose thresholds. Returns nil while the run continues.
    public static func evaluateOutcome(_ state: GameState) -> GameOutcome? {
        if state.globalInfectionFraction >= WorldResponseRules.victoryInfectionFraction {
            return .victory
        }
        if state.researchProgress >= WorldResponseRules.defeatResearchProgress {
            return .defeat
        }
        return nil
    }
}

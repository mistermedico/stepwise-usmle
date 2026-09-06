import Foundation
import Combine

/// Drives one active run: owns the `GameState`, advances it once per tick on a timer,
/// and forwards sound/haptic/persistence side effects for events the pure engine can't
/// know about (spec sections 4 "key animations" and 5 "sound").
@MainActor
public final class GameViewModel: ObservableObject {
    @Published public private(set) var state: GameState
    @Published public var isPaused: Bool = false
    @Published public var pendingLockdownWarnings: Set<RegionID> = []
    @Published public private(set) var newlyUnlockedAchievementIDs: Set<String> = []

    /// Seconds of real time per simulated day. Slow enough to read the map, fast
    /// enough that a full run stays a short session.
    public var secondsPerDay: TimeInterval = 1.6

    private var timerCancellable: AnyCancellable?
    private let soundManager: SoundManager
    private let historyStore: GameHistoryStore
    private let achievementManager: AchievementManager

    public init(
        scenario: WorldScenario,
        strain: StrainDefinition,
        difficulty: DifficultyLevel,
        soundManager: SoundManager = .shared,
        historyStore: GameHistoryStore = .shared,
        achievementManager: AchievementManager = .shared
    ) {
        self.state = GameState(scenario: scenario, strain: strain, difficulty: difficulty)
        self.soundManager = soundManager
        self.historyStore = historyStore
        self.achievementManager = achievementManager
    }

    public func start() {
        guard timerCancellable == nil else { return }
        timerCancellable = Timer.publish(every: secondsPerDay, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in self?.tick() }
    }

    public func stop() {
        timerCancellable?.cancel()
        timerCancellable = nil
    }

    public func tick() {
        guard !isPaused, state.isRunning else { return }

        updateLockdownWarnings()

        let previousAwareness = state.globalAwareness
        let next = OutbreakSimulationEngine.advanceOneDay(state)
        state = next

        soundManager.play(.ambientPulse)
        if next.globalAwareness - previousAwareness > 0.12 {
            soundManager.play(.awarenessSpike)
        }

        if let outcome = next.outcome {
            finish(outcome: outcome)
        }
    }

    public func purchaseUpgrade(_ nodeID: String) {
        let before = state.unlockedUpgradeIDs
        state = OutbreakSimulationEngine.purchaseUpgrade(state, nodeID: nodeID)
        if state.unlockedUpgradeIDs != before {
            soundManager.play(.upgradeUnlocked)
        }
    }

    public func togglePause() {
        isPaused.toggle()
    }

    /// Regions about to lock down (awareness within 10% of the threshold) get flagged
    /// so the map can start its amber "blink" warning ahead of the actual lockdown
    /// (spec section 4, "התראת סגר מתקרב").
    private func updateLockdownWarnings() {
        let threshold = state.difficulty.lockdownAwarenessThreshold
        var warnings: Set<RegionID> = []
        for region in state.scenario.regions {
            guard let regionState = state.regionStates[region.id], !regionState.isLockedDown else { continue }
            if regionState.awarenessLevel >= threshold - 0.1 {
                warnings.insert(region.id)
            }
        }
        pendingLockdownWarnings = warnings
    }

    private func finish(outcome: GameOutcome) {
        stop()
        soundManager.play(outcome == .victory ? .victory : .defeat)
        historyStore.save(finalState: state)
        newlyUnlockedAchievementIDs = achievementManager.recordFinishedRun(state)
    }
}

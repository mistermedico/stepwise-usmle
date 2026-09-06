import Foundation
import SwiftUI
import Combine
import OutbreakEngine

/// Drives one run: owns the engine, the clock, and everything the game screen
/// binds to. All simulation work happens in `OutbreakEngine`; this type only
/// schedules it and translates the result into presentation state.
@MainActor
final class GameViewModel: ObservableObject {

    enum Speed: Int, CaseIterable, Identifiable {
        case paused
        case normal
        case fast

        var id: Int { rawValue }

        /// Seconds of real time per simulated day.
        var interval: TimeInterval? {
            switch self {
            case .paused: return nil
            case .normal: return 0.55
            case .fast: return 0.22
            }
        }

        var symbolName: String {
            switch self {
            case .paused: return "play.fill"
            case .normal: return "forward.fill"
            case .fast: return "forward.end.fill"
            }
        }
    }

    // MARK: Published state

    @Published private(set) var state: GameState
    @Published var speed: Speed = .normal {
        didSet { restartClock() }
    }
    /// Territories flashing amber because restrictions are close.
    @Published private(set) var warningRegions: Set<RegionID> = []
    /// The most recent events, newest first, for the ticker.
    @Published private(set) var ticker: [GameEvent] = []
    /// Set when the run ends; drives the summary screen.
    @Published private(set) var finishedReport: EpidemicReport?
    @Published private(set) var freshAchievements: [Achievement] = []
    @Published var isAbilityMapPresented = false
    /// A short-lived flourish: the node just unlocked, for the pulse animation.
    @Published private(set) var lastUnlockedTrait: TraitID?

    // MARK: Dependencies

    private var engine: SimulationEngine
    private let feedback: FeedbackProviding
    private let store: ReportStore
    private let ads: AdManager
    private var clock: Timer?
    /// Guards against filing the same run twice if two ticks race.
    private var hasFiledReport = false

    init(
        setup: GameSetup,
        feedback: FeedbackProviding,
        store: ReportStore,
        ads: AdManager
    ) {
        let engine = SimulationEngine(setup: setup)
        self.engine = engine
        self.state = engine.state
        self.feedback = feedback
        self.store = store
        self.ads = ads
        self.ticker = engine.state.events.reversed()
        AppLogger.game.info(
            "Run started: \(setup.strain.rawValue)/\(setup.difficulty.rawValue)/\(setup.scenario.rawValue)"
        )
    }

    deinit {
        clock?.invalidate()
    }

    // MARK: Clock

    func start() {
        guard !state.isFinished else { return }
        restartClock()
        feedback.startOutbreakPulse()
    }

    func pause() {
        speed = .paused
    }

    func stop() {
        clock?.invalidate()
        clock = nil
        feedback.stopOutbreakPulse()
    }

    private func restartClock() {
        clock?.invalidate()
        clock = nil

        guard let interval = speed.interval, !state.isFinished else {
            feedback.stopOutbreakPulse()
            return
        }
        feedback.startOutbreakPulse()

        let timer = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
        RunLoop.main.add(timer, forMode: .common)
        clock = timer
    }

    /// Advances one day and folds the result into presentation state.
    private func tick() {
        guard !state.isFinished else {
            stop()
            return
        }

        let previousEventCount = engine.state.events.count
        let wasDetected = engine.state.isDetected

        engine.advanceDay()
        state = engine.state

        let newEvents = Array(engine.state.events.dropFirst(previousEventCount))
        if !newEvents.isEmpty {
            ticker = Array((Array(newEvents.reversed()) + ticker).prefix(40))
            reactTo(newEvents)
        }
        if !wasDetected, engine.state.isDetected {
            feedback.play(.awarenessSpike)
        }

        refreshWarnings()

        if let outcome = engine.state.outcome {
            finish(outcome)
        }
    }

    private func reactTo(_ events: [GameEvent]) {
        for event in events {
            switch event.kind {
            case .transportLocked, .bordersClosed:
                feedback.play(.restrictionImposed)
            default:
                break
            }
        }
    }

    /// Territories about to be restricted get the amber warning treatment.
    private func refreshWarnings() {
        let difficulty = state.setup.difficulty
        let imminent = state.regions.values
            .filter { GlobalResponseEngine.isRestrictionImminent(state: $0, difficulty: difficulty) }
            .map(\.id)
        let updated = Set(imminent)
        if updated != warningRegions {
            if !updated.subtracting(warningRegions).isEmpty {
                feedback.play(.awarenessSpike)
            }
            warningRegions = updated
        }
    }

    // MARK: Player actions

    func unlock(_ id: TraitID) {
        guard engine.state.canUnlock(id) else {
            feedback.play(.tap)
            return
        }
        engine.unlock(id)
        state = engine.state
        lastUnlockedTrait = id
        feedback.play(.abilityUnlocked)
        AppLogger.game.debug("Unlocked \(id.rawValue)")
    }

    func fold(_ id: TraitID) {
        guard engine.state.canFold(id) else { return }
        engine.fold(id)
        state = engine.state
        feedback.play(.abilityFolded)
    }

    func collect(_ bubble: PointBubble) {
        let value = engine.collectBubble(bubble.id)
        guard value > 0 else { return }
        state = engine.state
        feedback.play(.bubbleCollected)
    }

    /// Rewarded placement: extra evolution points.
    func watchForPoints() {
        ads.presentRewarded { [weak self] granted in
            Task { @MainActor in
                guard let self, granted else { return }
                self.engine.grantBonusPoints(AdPolicy.rewardedPoints)
                self.state = self.engine.state
                self.feedback.play(.bubbleCollected)
            }
        }
    }

    // MARK: Finishing

    private func finish(_ outcome: GameOutcome) {
        guard !hasFiledReport else { return }
        hasFiledReport = true
        stop()

        let report = EpidemicReport(state: engine.state)
        freshAchievements = store.save(report)
        finishedReport = report
        ads.recordFinishedRun()
        feedback.play(outcome == .victory ? .victory : .defeat)
        AppLogger.game.info("Run finished on day \(report.days): \(report.title.rawValue)")
    }

    // MARK: Derived presentation values

    var solutionCountdown: Int? {
        GlobalResponseEngine.daysUntilSolution(state)
    }

    var objectivePressure: Double? {
        state.setup.objective.map { ObjectiveEvaluator.pressure($0, state: state) }
    }

    var isObjectiveIntact: Bool? {
        state.setup.objective.map { ObjectiveEvaluator.isSatisfied($0, state: state) }
    }

    /// Fraction of the world reached, for the headline meter.
    var reachFraction: Double { state.worldTouchedFraction }

    func regionState(_ id: RegionID) -> RegionState {
        state.regions[id] ?? RegionState(id: id, population: RegionCatalog.blueprint(id).population)
    }

    /// Ability nodes in a branch, with their current status, for the map.
    func nodes(in category: TraitCategory) -> [TraitNode] {
        TraitCatalog.traits(in: category).map { trait in
            let status: NodeStatus
            if state.isUnlocked(trait.id) {
                status = .unlocked
            } else if state.canUnlock(trait.id) {
                status = .affordable
            } else if state.isAvailable(trait.id) {
                status = .available
            } else {
                status = .locked
            }
            return TraitNode(trait: trait, status: status)
        }
    }
}

/// One ability node ready for the map: its definition plus how to draw it.
struct TraitNode: Identifiable, Equatable {
    let trait: Trait
    let status: NodeStatus
    var id: TraitID { trait.id }
}

/// How an ability node should be drawn.
enum NodeStatus {
    /// Already part of the strain.
    case unlocked
    /// Reachable and affordable right now.
    case affordable
    /// Reachable but too expensive today.
    case available
    /// Prerequisites not met.
    case locked
}

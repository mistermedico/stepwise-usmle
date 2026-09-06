import Foundation
import AVFoundation
import UIKit

/// Feedback layer for the whole app (section 5).
///
/// There is no music and no bundled audio: the app uses built-in iOS system
/// sounds plus haptics, wrapped behind this abstraction so a view never touches
/// `AudioServices` or a feedback generator directly.
protocol FeedbackProviding: AnyObject {
    var isSoundEnabled: Bool { get set }
    var isHapticsEnabled: Bool { get set }

    func play(_ cue: FeedbackCue)
    /// Starts the slow background pulse that runs while an outbreak is live.
    func startOutbreakPulse()
    func stopOutbreakPulse()
}

/// Every moment in the game that produces feedback.
enum FeedbackCue {
    case tap
    case abilityUnlocked
    case abilityFolded
    case bubbleCollected
    case awarenessSpike
    case restrictionImposed
    case victory
    case defeat
}

final class SoundManager: FeedbackProviding {

    static let shared = SoundManager()

    var isSoundEnabled: Bool {
        didSet { Settings.isSoundEnabled = isSoundEnabled }
    }

    var isHapticsEnabled: Bool {
        didSet {
            Settings.isHapticsEnabled = isHapticsEnabled
            if !isHapticsEnabled { stopOutbreakPulse() }
        }
    }

    private var pulseTimer: Timer?
    private let notificationGenerator = UINotificationFeedbackGenerator()
    private let lightImpact = UIImpactFeedbackGenerator(style: .light)
    private let mediumImpact = UIImpactFeedbackGenerator(style: .medium)
    private let selection = UISelectionFeedbackGenerator()

    private init() {
        self.isSoundEnabled = Settings.isSoundEnabled
        self.isHapticsEnabled = Settings.isHapticsEnabled
    }

    deinit {
        pulseTimer?.invalidate()
    }

    func play(_ cue: FeedbackCue) {
        haptic(for: cue)
        if isSoundEnabled, let sound = systemSound(for: cue) {
            AudioServicesPlaySystemSound(sound)
        }
    }

    /// A slow, gentle beat under an active outbreak — the "breath" of the run.
    /// Deliberately quiet: haptics only, never a sound, so it can run for
    /// minutes without becoming irritating.
    func startOutbreakPulse() {
        guard isHapticsEnabled, pulseTimer == nil else { return }
        let timer = Timer(timeInterval: 2.6, repeats: true) { [weak self] _ in
            guard let self, self.isHapticsEnabled else { return }
            self.lightImpact.impactOccurred(intensity: 0.35)
        }
        RunLoop.main.add(timer, forMode: .common)
        pulseTimer = timer
        AppLogger.audio.debug("Outbreak pulse started")
    }

    func stopOutbreakPulse() {
        pulseTimer?.invalidate()
        pulseTimer = nil
    }

    // MARK: Mapping

    private func haptic(for cue: FeedbackCue) {
        guard isHapticsEnabled else { return }
        switch cue {
        case .tap:
            selection.selectionChanged()
        case .abilityUnlocked:
            mediumImpact.impactOccurred()
        case .abilityFolded, .bubbleCollected:
            lightImpact.impactOccurred()
        case .awarenessSpike, .restrictionImposed:
            notificationGenerator.notificationOccurred(.warning)
        case .victory:
            notificationGenerator.notificationOccurred(.success)
        case .defeat:
            notificationGenerator.notificationOccurred(.error)
        }
    }

    /// Built-in iOS system sound identifiers. Kept in one place so the mapping
    /// can be re-tuned without hunting through views.
    private func systemSound(for cue: FeedbackCue) -> SystemSoundID? {
        switch cue {
        case .tap: return nil                       // haptic only — taps are frequent
        case .abilityUnlocked: return 1103          // begin recording
        case .abilityFolded: return 1104            // end recording
        case .bubbleCollected: return 1105
        case .awarenessSpike: return 1256
        case .restrictionImposed: return 1257
        case .victory: return 1025
        case .defeat: return 1073
        }
    }
}

/// A no-op provider for previews and unit tests.
final class SilentFeedback: FeedbackProviding {
    var isSoundEnabled = false
    var isHapticsEnabled = false
    func play(_ cue: FeedbackCue) {}
    func startOutbreakPulse() {}
    func stopOutbreakPulse() {}
}

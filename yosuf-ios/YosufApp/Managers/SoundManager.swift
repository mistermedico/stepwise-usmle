import AudioToolbox
import os

/// Plays short UI sounds using iOS's built-in System Sound Services, so the
/// app ships with zero bundled audio assets (per spec: "built-in iOS system
/// sounds"). Every call site goes through here, never `AudioServicesPlaySystemSound`
/// directly, so sound can be globally muted from Settings in one place.
final class SoundManager {
    static let shared = SoundManager()
    private init() {}

    private let logger = Logger(subsystem: "com.yosuf.game", category: "sound")
    var isEnabled = true

    /// Well-known system sound IDs (iOS's public "UI Sounds" set).
    private enum SystemSound: SystemSoundID {
        case tock = 1104          // used for the card-deal "flick"
        case tink = 1103          // single card discard
        case beginRecording = 1113 // rising tone, used to build tension pre-reveal
        case anticipate = 1051     // short positive chime for a completed meld
        case success = 1025        // Yosuf win
        case failure = 1053        // Asaf catch
        case rankUp = 1026         // achievement / rank up
    }

    private func play(_ sound: SystemSound) {
        guard isEnabled else { return }
        AudioServicesPlaySystemSound(sound.rawValue)
    }

    func dealCard() { play(.tock) }
    func discard() { play(.tink) }
    func meldCompleted() { play(.anticipate) }
    func preRevealTension() { play(.beginRecording) }
    func yosufWin() { play(.success) }
    func asafCaught() { play(.failure) }
    func rankUp() { play(.rankUp) }
}

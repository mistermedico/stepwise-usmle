import Foundation
import os

/// Structured logging (section 8.6 — no stray `print` anywhere in the app).
///
/// Categories map to the app's subsystems so a console filter shows exactly one
/// concern at a time.
enum AppLogger {

    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.strainwave.app"

    static let lifecycle = Logger(subsystem: subsystem, category: "lifecycle")
    static let game = Logger(subsystem: subsystem, category: "game")
    static let persistence = Logger(subsystem: subsystem, category: "persistence")
    static let ads = Logger(subsystem: subsystem, category: "ads")
    static let audio = Logger(subsystem: subsystem, category: "audio")
    static let consent = Logger(subsystem: subsystem, category: "consent")
}

import SwiftUI

extension Color {
    /// Builds a `Color` from a `"#RRGGBB"` or `"RRGGBB"` hex string, as used by `Puzzle.colorHex`.
    /// Falls back to a neutral gray for any malformed value rather than crashing on bad content.
    init(hex: String) {
        var sanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if sanitized.hasPrefix("#") { sanitized.removeFirst() }

        var value: UInt64 = 0
        guard sanitized.count == 6, Scanner(string: sanitized).scanHexInt64(&value) else {
            self = .gray
            return
        }

        let red = Double((value & 0xFF0000) >> 16) / 255
        let green = Double((value & 0x00FF00) >> 8) / 255
        let blue = Double(value & 0x0000FF) / 255
        self = Color(red: red, green: green, blue: blue)
    }
}

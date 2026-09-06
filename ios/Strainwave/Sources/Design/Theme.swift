import SwiftUI
import UIKit

/// The visual language: a digital laboratory that is clean and scientific, but
/// warm rather than sterile. Every colour, radius and duration used anywhere in
/// the app is declared here — no view invents its own.
enum Theme {

    // MARK: Palette

    enum Palette {
        /// Page ground. Very light blue-grey by day, deep blue-charcoal by night.
        static let background = Color(light: 0xF1F4F9, dark: 0x0E141D)
        /// Raised surfaces: cards, sheets, the control panel.
        static let surface = Color(light: 0xFFFFFF, dark: 0x18222F)
        /// A surface sitting on top of another surface.
        static let surfaceRaised = Color(light: 0xF7F9FC, dark: 0x1F2C3C)
        /// Hairlines and dividers.
        static let outline = Color(light: 0xD8DFE9, dark: 0x2C3B4E)

        static let textPrimary = Color(light: 0x121A25, dark: 0xF0F4FA)
        static let textSecondary = Color(light: 0x5A687C, dark: 0x9AAABF)
        static let textTertiary = Color(light: 0x8B98AB, dark: 0x6B7D93)

        /// The signature spread colour: a glowing purple-magenta. Deliberately
        /// not blood red — the whole point is that this reads as a lab dye.
        static let spread = Color(light: 0xB02FD6, dark: 0xCB50EE)
        static let spreadSoft = Color(light: 0xE7C4F5, dark: 0x4A1F5E)
        static let spreadGlow = Color(light: 0xD86BF0, dark: 0xE080FF)

        /// The global response: a cool scientific cyan.
        static let response = Color(light: 0x1E9DBE, dark: 0x3FC6E8)
        static let responseSoft = Color(light: 0xC2E7F1, dark: 0x14384A)

        /// A healthy, untouched territory.
        static let healthy = Color(light: 0xC9D4E2, dark: 0x2A3A4D)

        static let success = Color(light: 0x2E9E6B, dark: 0x54D39B)
        static let warning = Color(light: 0xD08A17, dark: 0xF0B44E)

        /// Branch accents on the ability map.
        static func branch(_ category: TraitBranchStyle) -> Color {
            switch category {
            case .transmission: return Color(light: 0x2E7BD6, dark: 0x5AA6F5)
            case .resilience: return Color(light: 0x2E9E6B, dark: 0x54D39B)
            case .symptoms: return spread
            }
        }
    }

    // MARK: Typography

    /// One switch point for the whole app's type. Custom faces (a geometric
    /// technical face for figures, with a matching Hebrew geometric face) can be
    /// dropped into `Resources/Fonts` and wired up here without touching a view.
    enum Typography {
        static let displayName: String? = nil
        static let figureName: String? = nil

        static func display(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
            if let displayName {
                return .custom(displayName, size: size).weight(weight)
            }
            return .system(size: size, weight: weight, design: .rounded)
        }

        /// Figures on the control panel: evolution points, percentages, the day
        /// counter. Monospaced digits so numbers never jitter as they tick.
        static func figure(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
            if let figureName {
                return .custom(figureName, size: size).weight(weight)
            }
            return .system(size: size, weight: weight, design: .rounded).monospacedDigit()
        }

        static let title = display(28, weight: .bold)
        static let heading = display(20, weight: .semibold)
        static let subheading = display(16, weight: .semibold)
        static let body = Font.system(.body)
        static let callout = Font.system(.callout)
        static let caption = Font.system(.caption)
        static let readout = figure(34, weight: .bold)
        static let readoutSmall = figure(17, weight: .semibold)
    }

    // MARK: Metrics

    enum Metrics {
        static let cornerRadiusSmall: CGFloat = 10
        static let cornerRadius: CGFloat = 18
        static let cornerRadiusLarge: CGFloat = 26
        static let hairline: CGFloat = 1
        static let spacingTight: CGFloat = 6
        static let spacing: CGFloat = 12
        static let spacingWide: CGFloat = 20
        static let spacingSection: CGFloat = 28
        /// Minimum tap target, per the accessibility pass in section 8.8.
        static let minimumTapTarget: CGFloat = 44
    }

    // MARK: Motion

    /// Shared timings so every screen moves at the same tempo.
    enum Motion {
        static let quick = Animation.easeOut(duration: 0.18)
        static let standard = Animation.easeInOut(duration: 0.32)
        static let screen = Animation.easeInOut(duration: 0.42)
        /// The slow breath under an active outbreak.
        static let pulse = Animation.easeInOut(duration: 1.8).repeatForever(autoreverses: true)
        /// The amber flash warning that restrictions are imminent.
        static let alert = Animation.easeInOut(duration: 0.7).repeatForever(autoreverses: true)
        static let unlockPulse = Animation.easeOut(duration: 0.55)
    }
}

/// Mirrors `TraitCategory` for styling without importing the engine into the
/// palette itself.
enum TraitBranchStyle {
    case transmission
    case resilience
    case symptoms
}

extension Color {
    /// Builds a colour that resolves per appearance, so every token is defined
    /// once for light and once for dark.
    init(light: UInt32, dark: UInt32) {
        self.init(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(rgb: dark)
                : UIColor(rgb: light)
        })
    }
}

private extension UIColor {
    convenience init(rgb: UInt32) {
        self.init(
            red: CGFloat((rgb >> 16) & 0xFF) / 255,
            green: CGFloat((rgb >> 8) & 0xFF) / 255,
            blue: CGFloat(rgb & 0xFF) / 255,
            alpha: 1
        )
    }
}

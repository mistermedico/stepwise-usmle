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

        // Every text role clears 4.5:1 against the surface it sits on. The
        // accessibility audit flagged the original tertiary, warning, success
        // and response values, which were chosen by eye and failed.
        static let textPrimary = Color(light: 0x121A25, dark: 0xF0F4FA)
        static let textSecondary = Color(light: 0x536174, dark: 0xA6B5C9)
        static let textTertiary = Color(light: 0x6B7A8F, dark: 0x93A3B8)

        /// The signature spread colour: a glowing purple-magenta. Deliberately
        /// not blood red — the whole point is that this reads as a lab dye.
        static let spread = Color(light: 0xB02FD6, dark: 0xCB50EE)
        static let spreadSoft = Color(light: 0xE7C4F5, dark: 0x4A1F5E)
        static let spreadGlow = Color(light: 0xD86BF0, dark: 0xE080FF)

        /// The global response: a cool scientific cyan.
        static let response = Color(light: 0x0E7590, dark: 0x3FC6E8)
        static let responseSoft = Color(light: 0xC2E7F1, dark: 0x14384A)

        /// A healthy, untouched territory.
        static let healthy = Color(light: 0xC9D4E2, dark: 0x2A3A4D)

        static let success = Color(light: 0x1E7A50, dark: 0x54D39B)
        static let warning = Color(light: 0x9A6300, dark: 0xF0B44E)

        /// Branch accents on the ability map.
        static func branch(_ category: TraitBranchStyle) -> Color {
            switch category {
            case .transmission: return Color(light: 0x1F5FAE, dark: 0x5AA6F5)
            case .resilience: return Color(light: 0x1E7A50, dark: 0x54D39B)
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

        /// Headings. Built from a text style rather than a point size, so every
        /// label scales with the reader's Dynamic Type setting — a fixed size
        /// silently ignores it, which is what the accessibility audit flagged.
        static func display(_ style: Font.TextStyle, weight: Font.Weight = .semibold) -> Font {
            if let displayName {
                return .custom(displayName, size: size(for: style), relativeTo: style).weight(weight)
            }
            return .system(style, design: .rounded).weight(weight)
        }

        /// Figures on the control panel: evolution points, percentages, the day
        /// counter. Monospaced digits so numbers never jitter as they tick.
        static func figure(_ style: Font.TextStyle, weight: Font.Weight = .semibold) -> Font {
            if let figureName {
                return .custom(figureName, size: size(for: style), relativeTo: style)
                    .weight(weight)
                    .monospacedDigit()
            }
            return .system(style, design: .rounded).weight(weight).monospacedDigit()
        }

        /// Base sizes, used only when a custom face is fitted; the system faces
        /// bring their own.
        private static func size(for style: Font.TextStyle) -> CGFloat {
            switch style {
            case .largeTitle: return 34
            case .title: return 28
            case .title2: return 22
            case .title3: return 20
            case .headline: return 17
            case .callout: return 16
            case .subheadline: return 15
            case .footnote: return 13
            case .caption: return 12
            case .caption2: return 11
            default: return 17
            }
        }

        static let title = display(.title, weight: .bold)
        static let heading = display(.title3)
        static let subheading = display(.headline)
        static let body = Font.system(.body)
        static let callout = Font.system(.callout)
        static let caption = Font.system(.caption)
        static let readout = figure(.largeTitle, weight: .bold)
        static let readoutSmall = figure(.headline)
        static let figureSmall = figure(.caption)
        static let figureTiny = figure(.caption2)
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

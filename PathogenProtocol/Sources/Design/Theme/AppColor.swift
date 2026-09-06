import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// The "digital laboratory" palette (spec section 4). Every color is defined once here
/// as an adaptive light/dark pair — no hardcoded hex scattered through views, and no
/// asset-catalog color sets to keep in sync by hand.
public enum AppColor {
    #if canImport(UIKit)
    private static func adaptive(light: UIColor, dark: UIColor) -> Color {
        Color(UIColor { traits in traits.userInterfaceStyle == .dark ? dark : light })
    }
    #endif

    /// Screen background — a near-white blue-gray in light mode, a deep charcoal-blue
    /// "lab monitor" tone in dark mode.
    public static var labBackground: Color {
        #if canImport(UIKit)
        adaptive(
            light: UIColor(red: 0.94, green: 0.96, blue: 0.98, alpha: 1),
            dark: UIColor(red: 0.06, green: 0.09, blue: 0.14, alpha: 1)
        )
        #else
        Color(red: 0.94, green: 0.96, blue: 0.98)
        #endif
    }

    /// Raised card / panel surface, one step lighter (or darker) than the background.
    public static var labSurface: Color {
        #if canImport(UIKit)
        adaptive(
            light: UIColor.white,
            dark: UIColor(red: 0.10, green: 0.14, blue: 0.20, alpha: 1)
        )
        #else
        Color.white
        #endif
    }

    /// The pathogen's signature color — glowing purple-magenta. Deliberately not red,
    /// so infection reads as "strange sci-fi bloom" rather than blood/gore.
    public static var contagion: Color {
        Color(red: 0.72, green: 0.24, blue: 0.92)
    }

    public static var contagionGlow: Color {
        Color(red: 0.85, green: 0.45, blue: 1.0)
    }

    /// The Global Response System's color — cool cyan, the "science pushing back" side.
    public static var response: Color {
        Color(red: 0.20, green: 0.70, blue: 0.86)
    }

    public static var success: Color {
        Color(red: 0.35, green: 0.78, blue: 0.55)
    }

    public static var warning: Color {
        Color(red: 0.95, green: 0.68, blue: 0.28)
    }

    public static var textPrimary: Color {
        #if canImport(UIKit)
        adaptive(
            light: UIColor(red: 0.08, green: 0.10, blue: 0.14, alpha: 1),
            dark: UIColor(red: 0.93, green: 0.95, blue: 0.98, alpha: 1)
        )
        #else
        Color.primary
        #endif
    }

    public static var textSecondary: Color {
        Color.secondary
    }

    public static var divider: Color {
        Color.primary.opacity(0.08)
    }
}

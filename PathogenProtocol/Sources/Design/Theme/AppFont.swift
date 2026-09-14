import SwiftUI

/// Typography scale (spec section 4). Headlines and numeric readouts use a rounded,
/// geometric "control panel" weight — SF Rounded ships on every iOS device, so it's
/// used in place of a bundled third-party font (avoids adding font files/licensing).
/// Body text stays on the system default for maximum legibility and full RTL shaping.
public enum AppFont {
    public static func dashboard(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }

    public static var largeStat: Font { dashboard(34, weight: .bold) }
    public static var stat: Font { dashboard(20, weight: .semibold) }
    public static var screenTitle: Font { dashboard(28, weight: .bold) }
    public static var cardTitle: Font { dashboard(17, weight: .semibold) }

    public static func body(_ size: CGFloat = 15, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .default)
    }
}

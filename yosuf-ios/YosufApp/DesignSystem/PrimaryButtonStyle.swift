import SwiftUI

/// The one button style used for every primary call-to-action across the
/// app (Play, Declare Yosuf, Confirm) so buttons never look ad hoc.
struct PrimaryButtonStyle: ButtonStyle {
    var tint: Color = Theme.accentGold
    var isDestructive: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 17, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .padding(.vertical, Theme.spacingM)
            .padding(.horizontal, Theme.spacingL)
            .frame(maxWidth: .infinity)
            .background(isDestructive ? Theme.dangerRed : tint)
            .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadiusMedium, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .semibold, design: .rounded))
            .foregroundStyle(Theme.textPrimary)
            .padding(.vertical, Theme.spacingS + 4)
            .padding(.horizontal, Theme.spacingM)
            .frame(maxWidth: .infinity)
            .background(Theme.surfaceElevated)
            .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadiusMedium, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.cornerRadiusMedium, style: .continuous)
                    .strokeBorder(Theme.textSecondary.opacity(0.25), lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == PrimaryButtonStyle {
    static var primary: PrimaryButtonStyle { PrimaryButtonStyle() }
    static var destructive: PrimaryButtonStyle { PrimaryButtonStyle(isDestructive: true) }
}

extension ButtonStyle where Self == SecondaryButtonStyle {
    static var secondary: SecondaryButtonStyle { SecondaryButtonStyle() }
}

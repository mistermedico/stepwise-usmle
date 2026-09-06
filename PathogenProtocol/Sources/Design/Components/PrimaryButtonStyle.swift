import SwiftUI

/// The single bold "Start Outbreak" call-to-action style used throughout the app
/// (spec section 4, home screen).
public struct PrimaryButtonStyle: ButtonStyle {
    var tint: Color = AppColor.contagion

    public init(tint: Color = AppColor.contagion) {
        self.tint = tint
    }

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppFont.dashboard(17, weight: .bold))
            .foregroundStyle(.white)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity)
            .background(
                LinearGradient(colors: [tint, tint.opacity(0.75)], startPoint: .leading, endPoint: .trailing)
            )
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.9 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

public struct SecondaryButtonStyle: ButtonStyle {
    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppFont.dashboard(15, weight: .semibold))
            .foregroundStyle(AppColor.textPrimary)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background(AppColor.labSurface)
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(AppColor.divider, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

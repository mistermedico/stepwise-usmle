import SwiftUI

/// The "sample card" look used to present a selectable strain — a circular dish with
/// a soft contagion-colored culture inside, per spec section 4 ("כרטיסי מדגם").
public struct PetriDishCard: View {
    let title: String
    let subtitle: String
    let isSelected: Bool
    let action: () -> Void

    public init(title: String, subtitle: String, isSelected: Bool, action: @escaping () -> Void) {
        self.title = title
        self.subtitle = subtitle
        self.isSelected = isSelected
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            VStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(AppColor.labSurface)
                        .overlay(Circle().stroke(AppColor.divider, lineWidth: 2))
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [AppColor.contagionGlow, AppColor.contagion.opacity(0.15)],
                                center: .center, startRadius: 2, endRadius: 34
                            )
                        )
                        .padding(14)
                        .blur(radius: 1)
                }
                .frame(width: 84, height: 84)
                .overlay(
                    Circle()
                        .stroke(isSelected ? AppColor.contagion : .clear, lineWidth: 3)
                        .padding(-4)
                )

                Text(title)
                    .font(AppFont.cardTitle)
                    .foregroundStyle(AppColor.textPrimary)
                    .lineLimit(1)
                Text(subtitle)
                    .font(AppFont.body(12))
                    .foregroundStyle(AppColor.textSecondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }
            .padding(12)
            .frame(width: 140)
            .background(AppColor.labSurface)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .shadow(color: .black.opacity(isSelected ? 0.12 : 0.05), radius: isSelected ? 10 : 4, y: 4)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

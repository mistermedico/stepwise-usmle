import SwiftUI

/// A single node in the neural-pathway upgrade tree. Glows and pops on unlock
/// (spec section 4: "נקודה נפתחת עם 'דופק' קצר של אור ... לפני שהיא נדלקת").
struct UpgradeNodeView: View {
    let node: UpgradeNode
    let isUnlocked: Bool
    let isAvailable: Bool
    let canAfford: Bool
    let action: () -> Void

    private var tint: Color {
        switch node.category {
        case .transmission: return AppColor.contagion
        case .resistance: return AppColor.response
        case .symptoms: return AppColor.warning
        }
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                ZStack {
                    Circle()
                        .fill(isUnlocked ? tint : AppColor.labSurface)
                        .frame(width: 46, height: 46)
                        .overlay(
                            Circle().stroke(isAvailable || isUnlocked ? tint : AppColor.divider, lineWidth: 2)
                        )
                        .shadow(color: isUnlocked ? tint.opacity(0.6) : .clear, radius: 10)

                    Image(systemName: isUnlocked ? "checkmark" : (isAvailable ? "lock.open.fill" : "lock.fill"))
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(isUnlocked ? .white : (isAvailable ? tint : AppColor.textSecondary))
                }
                .scaleEffect(isUnlocked ? 1.0 : 0.92)
                .animation(.spring(response: 0.4, dampingFraction: 0.55), value: isUnlocked)

                Text("\(node.cost)")
                    .font(AppFont.body(10, weight: .semibold))
                    .foregroundStyle(AppColor.textSecondary)
            }
        }
        .buttonStyle(.plain)
        .disabled(isUnlocked || !isAvailable || !canAfford)
        .opacity(isAvailable || isUnlocked ? 1 : 0.45)
        .accessibilityLabel(Text(LocalizedStringKey(node.nameKey)))
        .accessibilityHint(Text(LocalizedStringKey(node.descriptionKey)))
        .accessibilityAddTraits(isUnlocked ? [.isSelected] : [])
    }
}

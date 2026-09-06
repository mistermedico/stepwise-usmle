import SwiftUI

/// Three branching "neural pathway" columns — transmission, resistance, symptoms —
/// each a connected chain of `UpgradeNodeView`s (spec section 4).
struct UpgradeTreeView: View {
    let unlockedUpgradeIDs: Set<String>
    let evolutionPoints: Double
    let onPurchase: (String) -> Void

    var body: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 28) {
                ForEach(UpgradeCategory.allCases) { category in
                    branch(for: category)
                }
            }
            .padding(20)
        }
    }

    private func branch(for category: UpgradeCategory) -> some View {
        let nodes = UpgradeCatalog.allNodes.filter { $0.category == category }.sorted { $0.tier < $1.tier }
        return VStack(alignment: .leading, spacing: 12) {
            Text(LocalizedStringKey("upgrade.category.\(category.rawValue)"))
                .font(AppFont.cardTitle)
                .foregroundStyle(AppColor.textPrimary)

            HStack(spacing: 0) {
                ForEach(Array(nodes.enumerated()), id: \.element.id) { index, node in
                    let isUnlocked = unlockedUpgradeIDs.contains(node.id)
                    let prerequisiteMet = node.prerequisiteID.map { unlockedUpgradeIDs.contains($0) } ?? true
                    let canAfford = evolutionPoints >= Double(node.cost)

                    if index > 0 {
                        Rectangle()
                            .fill(isUnlocked ? branchTint(category) : AppColor.divider)
                            .frame(height: 2)
                            .frame(minWidth: 16, maxWidth: 30)
                    }

                    UpgradeNodeView(
                        node: node,
                        isUnlocked: isUnlocked,
                        isAvailable: prerequisiteMet,
                        canAfford: canAfford,
                        action: { onPurchase(node.id) }
                    )
                }
            }

            if let activeDescription = nextUnlockableDescription(nodes: nodes) {
                Text(LocalizedStringKey(activeDescription))
                    .font(AppFont.body(12))
                    .foregroundStyle(AppColor.textSecondary)
            }
        }
        .padding(16)
        .background(AppColor.labSurface)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func branchTint(_ category: UpgradeCategory) -> Color {
        switch category {
        case .transmission: return AppColor.contagion
        case .resistance: return AppColor.response
        case .symptoms: return AppColor.warning
        }
    }

    private func nextUnlockableDescription(nodes: [UpgradeNode]) -> String? {
        nodes.first { !unlockedUpgradeIDs.contains($0.id) }?.descriptionKey
    }
}

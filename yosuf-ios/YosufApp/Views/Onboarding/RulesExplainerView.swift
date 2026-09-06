import SwiftUI

struct RulesExplainerView: View {
    @Environment(\.dismiss) private var dismiss
    private let stepKeys = [
        ("suit.spade.fill", "howToPlay.step1.title", "howToPlay.step1.body"),
        ("arrow.triangle.2.circlepath", "howToPlay.step2.title", "howToPlay.step2.body"),
        ("exclamationmark.bubble.fill", "howToPlay.step3.title", "howToPlay.step3.body"),
        ("crown.fill", "howToPlay.step4.title", "howToPlay.step4.body")
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.spacingL) {
                    ForEach(stepKeys, id: \.1) { icon, titleKey, bodyKey in
                        HStack(alignment: .top, spacing: Theme.spacingM) {
                            Image(systemName: icon)
                                .font(.title2)
                                .foregroundStyle(Theme.accentGold)
                                .frame(width: 32)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(LocalizedStringKey(titleKey)).font(.headline)
                                Text(LocalizedStringKey(bodyKey)).font(.subheadline).foregroundStyle(Theme.textSecondary)
                            }
                        }
                        .themedSurface()
                        .padding(.horizontal)
                    }
                }
                .padding(.vertical, Theme.spacingL)
            }
            .navigationTitle(String(localized: "home.howToPlay"))
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "common.done")) { dismiss() }
                }
            }
        }
    }
}

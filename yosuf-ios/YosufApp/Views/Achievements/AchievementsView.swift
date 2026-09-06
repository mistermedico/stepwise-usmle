import SwiftUI

struct AchievementsView: View {
    @StateObject private var viewModel = AchievementsViewModel()

    var body: some View {
        Group {
            if viewModel.rows.allSatisfy({ !$0.isUnlocked }) {
                EmptyStateView(
                    systemImage: "rosette",
                    titleKey: "achievements.empty.title",
                    messageKey: "achievements.empty.message"
                )
            } else {
                List(viewModel.rows) { row in
                    HStack(spacing: Theme.spacingM) {
                        Image(systemName: row.isUnlocked ? "rosette" : "lock.fill")
                            .font(.title3)
                            .foregroundStyle(row.isUnlocked ? Theme.accentGold : Theme.textSecondary)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(LocalizedStringKey(row.id.titleKey))
                                .font(.headline)
                                .foregroundStyle(row.isUnlocked ? Theme.textPrimary : Theme.textSecondary)
                            Text(LocalizedStringKey(row.id.descriptionKey))
                                .font(.caption)
                                .foregroundStyle(Theme.textSecondary)
                        }
                    }
                    .opacity(row.isUnlocked ? 1 : 0.5)
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle(String(localized: "home.achievements"))
        .background(Theme.tableFelt.ignoresSafeArea())
        .onAppear { viewModel.load() }
    }
}

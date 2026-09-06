import SwiftUI

/// Lists every achievement in `AchievementCatalog`; unlocked ones show full color and detail,
/// locked ones are grayed down to just their icon so the player knows more exist to chase.
struct AchievementsView: View {
    @EnvironmentObject private var appViewModel: AppViewModel

    var body: some View {
        NavigationStack {
            List(AchievementCatalog.all) { achievement in
                let unlocked = appViewModel.progress.unlockedAchievementIDs.contains(achievement.id)
                HStack(spacing: 16) {
                    Image(systemName: achievement.iconSystemName)
                        .font(.system(size: 24))
                        .foregroundColor(unlocked ? .accentColor : .secondary)
                        .frame(width: 36)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(achievement.title.localized(for: appViewModel.localization.languageCode))
                            .font(.headline)
                            .foregroundColor(unlocked ? Color("TextPrimary") : .secondary)
                        if unlocked {
                            Text(achievement.detail.localized(for: appViewModel.localization.languageCode))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        } else {
                            Text(appViewModel.localization.string("achievements.locked"))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    Spacer()

                    if unlocked {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    }
                }
                .opacity(unlocked ? 1.0 : 0.5)
                .padding(.vertical, 4)
            }
            .listStyle(.plain)
            .background(Color("BackgroundPrimary"))
            .navigationTitle(appViewModel.localization.string("tab.achievements"))
        }
    }
}

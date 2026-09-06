import SwiftUI
import YosufEngine

struct HistoryView: View {
    @StateObject private var viewModel = HistoryViewModel()

    var body: some View {
        Group {
            if viewModel.matches.isEmpty {
                EmptyStateView(
                    systemImage: "clock.arrow.circlepath",
                    titleKey: "history.empty.title",
                    messageKey: "history.empty.message"
                )
            } else {
                List(viewModel.matches) { match in
                    HStack(spacing: Theme.spacingM) {
                        Image(systemName: match.didWin ? "checkmark.seal.fill" : "xmark.seal.fill")
                            .foregroundStyle(match.didWin ? Theme.accentGold : Theme.textSecondary)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(LocalizedStringKey(RuleProfile(from: match.rulesProfileID).displayNameKey))
                                .font(.headline)
                            Text(match.opponentSummary)
                                .font(.caption)
                                .foregroundStyle(Theme.textSecondary)
                        }
                        Spacer()
                        Text(match.date, style: .date)
                            .font(.caption2)
                            .foregroundStyle(Theme.textSecondary)
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle(String(localized: "home.history"))
        .background(Theme.tableFelt.ignoresSafeArea())
        .onAppear { viewModel.load() }
    }
}

private extension RuleProfile {
    init(from kind: RuleProfile.ProfileKind) {
        self = RuleProfile.allPresets.first { $0.id == kind } ?? .classic
    }
}

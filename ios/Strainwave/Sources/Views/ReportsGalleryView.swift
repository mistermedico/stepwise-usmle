import SwiftUI
import OutbreakEngine

/// The shelf of filed reports.
struct ReportsGalleryView: View {

    let reports: [EpidemicReport]

    @Environment(\.dismiss) private var dismiss
    @State private var selected: EpidemicReport?

    private let columns = [
        GridItem(.adaptive(minimum: 150), spacing: Theme.Metrics.spacing)
    ]

    var body: some View {
        NavigationStack {
            Group {
                if reports.isEmpty {
                    EmptyStateView(
                        title: L.string("empty.reports.title"),
                        detail: L.string("empty.reports.detail"),
                        illustration: .shelf
                    )
                    .padding(Theme.Metrics.spacingWide)
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: Theme.Metrics.spacing) {
                            ForEach(reports) { report in
                                Button { selected = report } label: {
                                    ReportCard(report: report)
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(Theme.Metrics.spacingWide)
                    }
                }
            }
            .background(Theme.Palette.background.ignoresSafeArea())
            .navigationTitle(L.string("home.reports"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L.string("common.close")) { dismiss() }
                }
            }
            .sheet(item: $selected) { report in
                ReportView(
                    report: report,
                    freshAchievements: [],
                    onPlayAgain: { selected = nil },
                    onHome: { selected = nil }
                )
            }
        }
    }
}

/// The achievement board.
struct AchievementsView: View {

    let earned: Set<Achievement>

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if earned.isEmpty {
                    ScrollView {
                        VStack(spacing: Theme.Metrics.spacingWide) {
                            EmptyStateView(
                                title: L.string("empty.achievements.title"),
                                detail: L.string("empty.achievements.detail"),
                                illustration: .board
                            )
                            list
                        }
                        .padding(Theme.Metrics.spacingWide)
                    }
                } else {
                    ScrollView {
                        list.padding(Theme.Metrics.spacingWide)
                    }
                }
            }
            .background(Theme.Palette.background.ignoresSafeArea())
            .navigationTitle(L.string("home.achievements"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L.string("common.close")) { dismiss() }
                }
            }
        }
    }

    private var list: some View {
        VStack(spacing: Theme.Metrics.spacing) {
            ForEach(Achievement.allCases, id: \.self) { achievement in
                let isEarned = earned.contains(achievement)
                HStack(spacing: Theme.Metrics.spacing) {
                    Image(systemName: isEarned ? "rosette" : "lock.fill")
                        .font(.title3)
                        .foregroundStyle(isEarned ? Theme.Palette.success : Theme.Palette.textTertiary)
                        .frame(width: 32)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(L.achievementTitle(achievement))
                            .font(Theme.Typography.callout.weight(.semibold))
                            .foregroundStyle(
                                isEarned ? Theme.Palette.textPrimary : Theme.Palette.textSecondary
                            )
                        Text(L.achievementDetail(achievement))
                            .font(Theme.Typography.caption)
                            .foregroundStyle(Theme.Palette.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                }
                .padding(Theme.Metrics.spacing)
                .background(
                    RoundedRectangle(cornerRadius: Theme.Metrics.cornerRadiusSmall, style: .continuous)
                        .fill(Theme.Palette.surface)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Metrics.cornerRadiusSmall, style: .continuous)
                        .strokeBorder(Theme.Palette.outline, lineWidth: Theme.Metrics.hairline)
                )
                .opacity(isEarned ? 1 : 0.72)
                .accessibilityElement(children: .combine)
                .accessibilityValue(Text(isEarned ? L.string("tree.unlocked") : L.string("picker.locked")))
            }
        }
    }
}

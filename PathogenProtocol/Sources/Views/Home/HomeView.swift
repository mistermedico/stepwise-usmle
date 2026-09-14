import SwiftUI

/// The home dashboard (spec section 4): start button, strain "petri dish" picker,
/// scenario/difficulty pickers, today's daily challenge card, and a gallery of past
/// reports. This is the control-panel first impression of the whole app.
struct HomeView: View {
    @StateObject var viewModel = HomeViewModel()
    let onStart: (GameViewModel) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                header
                dailyChallengeCard
                strainPicker
                scenarioAndDifficultyPickers
                startButton
                reportsGallery
            }
            .padding(20)
        }
        .background(AppColor.labBackground.ignoresSafeArea())
        .onAppear { viewModel.refresh() }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("app.name")
                .font(AppFont.screenTitle)
                .foregroundStyle(AppColor.textPrimary)
            HStack(spacing: 6) {
                Image(systemName: "rosette")
                    .foregroundStyle(AppColor.response)
                Text("home.achievements_count \(viewModel.unlockedAchievementCount) \(AchievementCatalog.all.count)")
                    .font(AppFont.body(13))
                    .foregroundStyle(AppColor.textSecondary)
            }
        }
    }

    private var dailyChallengeCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "bolt.fill").foregroundStyle(AppColor.warning)
                Text("home.daily_challenge_title")
                    .font(AppFont.cardTitle)
                    .foregroundStyle(AppColor.textPrimary)
                Spacer()
            }
            Text(LocalizedStringKey(viewModel.dailyChallenge.objective.titleKey))
                .font(AppFont.body(13))
                .foregroundStyle(AppColor.textSecondary)

            Button {
                onStart(viewModel.makeGameViewModel(usingDailyChallenge: true))
            } label: {
                Text("home.play_daily")
            }
            .buttonStyle(SecondaryButtonStyle())
        }
        .padding(16)
        .background(AppColor.labSurface)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var strainPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("home.select_strain")
                .font(AppFont.cardTitle)
                .foregroundStyle(AppColor.textPrimary)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(viewModel.strains) { strain in
                        PetriDishCard(
                            title: NSLocalizedString(strain.nameKey, comment: ""),
                            subtitle: NSLocalizedString(strain.taglineKey, comment: ""),
                            isSelected: viewModel.selectedStrain.id == strain.id,
                            action: { viewModel.selectedStrain = strain }
                        )
                    }
                }
            }
        }
    }

    private var scenarioAndDifficultyPickers: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("home.select_scenario")
                    .font(AppFont.cardTitle)
                    .foregroundStyle(AppColor.textPrimary)
                Picker("home.select_scenario", selection: $viewModel.selectedScenario) {
                    ForEach(viewModel.scenarios) { scenario in
                        Text(LocalizedStringKey(scenario.nameKey)).tag(scenario)
                    }
                }
                .pickerStyle(.segmented)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("home.select_difficulty")
                    .font(AppFont.cardTitle)
                    .foregroundStyle(AppColor.textPrimary)
                Picker("home.select_difficulty", selection: $viewModel.selectedDifficulty) {
                    ForEach(viewModel.difficulties) { difficulty in
                        Text(LocalizedStringKey("difficulty.\(difficulty.rawValue)")).tag(difficulty)
                    }
                }
                .pickerStyle(.segmented)
            }
        }
    }

    private var startButton: some View {
        Button {
            onStart(viewModel.makeGameViewModel(usingDailyChallenge: false))
        } label: {
            Text("home.start_outbreak")
        }
        .buttonStyle(PrimaryButtonStyle())
    }

    private var reportsGallery: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("home.past_reports")
                .font(AppFont.cardTitle)
                .foregroundStyle(AppColor.textPrimary)

            if viewModel.pastReports.isEmpty {
                EmptyStateView(
                    symbolName: "tray",
                    title: NSLocalizedString("home.empty_reports_title", comment: ""),
                    message: NSLocalizedString("home.empty_reports_message", comment: "")
                )
            } else {
                VStack(spacing: 10) {
                    ForEach(viewModel.pastReports) { report in
                        PastReportRow(report: report)
                    }
                }
            }
        }
    }
}

private struct PastReportRow: View {
    let report: SavedOutbreakReport

    var body: some View {
        HStack {
            Image(systemName: report.outcome == .victory ? "checkmark.seal.fill" : "xmark.seal.fill")
                .foregroundStyle(report.outcome == .victory ? AppColor.success : AppColor.warning)
            VStack(alignment: .leading, spacing: 2) {
                Text(LocalizedStringKey(report.character.titleKey))
                    .font(AppFont.body(14, weight: .semibold))
                    .foregroundStyle(AppColor.textPrimary)
                Text("report.day_count \(report.day)")
                    .font(AppFont.body(12))
                    .foregroundStyle(AppColor.textSecondary)
            }
            Spacer()
        }
        .padding(12)
        .background(AppColor.labSurface)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

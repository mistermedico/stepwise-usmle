import SwiftUI
import YosufEngine

struct HomeView: View {
    @EnvironmentObject private var viewModel: HomeViewModel
    @State private var showRuleProfiles = false
    @State private var showDailyChallenge = false
    @State private var showAchievements = false
    @State private var showHistory = false
    @State private var showSettings = false
    @State private var showRulesExplainer = false

    var body: some View {
        ZStack {
            AnimatedFeltBackground()

            ScrollView {
                VStack(spacing: Theme.spacingL) {
                    header
                    rankCard
                    primaryActions
                    secondaryActions
                }
                .padding(Theme.spacingL)
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { viewModel.refresh() }
        .navigationDestination(isPresented: $showRuleProfiles) { RuleProfileSelectionView() }
        .navigationDestination(isPresented: $showDailyChallenge) { DailyChallengeView() }
        .navigationDestination(isPresented: $showAchievements) { AchievementsView() }
        .navigationDestination(isPresented: $showHistory) { HistoryView() }
        .navigationDestination(isPresented: $showSettings) { SettingsView() }
        .sheet(isPresented: $showRulesExplainer) { RulesExplainerView() }
    }

    private var header: some View {
        VStack(spacing: Theme.spacingXS) {
            Text("app.name")
                .font(.system(size: 34, weight: .heavy, design: .rounded))
                .foregroundStyle(Theme.accentGold)
            Text("home.tagline")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.85))
        }
        .padding(.top, Theme.spacingXL)
    }

    private var rankCard: some View {
        VStack(spacing: Theme.spacingS) {
            HStack {
                Text(LocalizedStringKey(viewModel.profile.rankTier.displayNameKey))
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                Spacer()
                Text("\(viewModel.profile.skillRating)")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.accentGold)
            }
            ProgressView(value: viewModel.rankProgressFraction)
                .tint(Theme.accentGold)
            HStack {
                Text(String(format: String(localized: "home.gamesPlayedFormat"), viewModel.profile.gamesPlayed))
                Spacer()
                Text(String(format: String(localized: "home.gamesWonFormat"), viewModel.profile.gamesWon))
            }
            .font(.caption)
            .foregroundStyle(Theme.textSecondary)
        }
        .padding(Theme.spacingM)
        .themedSurface()
    }

    private var primaryActions: some View {
        VStack(spacing: Theme.spacingM) {
            Button {
                showRuleProfiles = true
            } label: {
                Label(String(localized: "home.play"), systemImage: "play.fill")
            }
            .buttonStyle(.primary)

            Button {
                showDailyChallenge = true
            } label: {
                HStack {
                    Label(String(localized: "home.dailyChallenge"), systemImage: "calendar")
                    if viewModel.showDailyChallengeBadge {
                        Circle().fill(Theme.dangerRed).frame(width: 8, height: 8)
                    }
                }
            }
            .buttonStyle(.secondary)
        }
    }

    private var secondaryActions: some View {
        HStack(spacing: Theme.spacingM) {
            iconAction(titleKey: "home.achievements", systemImage: "rosette") { showAchievements = true }
            iconAction(titleKey: "home.history", systemImage: "clock.arrow.circlepath") { showHistory = true }
            iconAction(titleKey: "home.settings", systemImage: "gearshape.fill") { showSettings = true }
            iconAction(titleKey: "home.howToPlay", systemImage: "questionmark.circle.fill") { showRulesExplainer = true }
        }
    }

    private func iconAction(titleKey: LocalizedStringKey, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: Theme.spacingXS) {
                Image(systemName: systemImage).font(.title2)
                Text(titleKey).font(.caption2)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Theme.spacingS)
        }
        .buttonStyle(.secondary)
    }
}

/// A gently animated felt-table backdrop for the home screen — subtle
/// breathing light, never distracting, per the "polished home screen" spec.
private struct AnimatedFeltBackground: View {
    @State private var animate = false

    var body: some View {
        ZStack {
            Theme.tableFelt.ignoresSafeArea()
            RadialGradient(
                colors: [Theme.accentGold.opacity(animate ? 0.18 : 0.08), .clear],
                center: .center, startRadius: 20, endRadius: 420
            )
            .ignoresSafeArea()
            .animation(.easeInOut(duration: 4).repeatForever(autoreverses: true), value: animate)
        }
        .onAppear { animate = true }
    }
}

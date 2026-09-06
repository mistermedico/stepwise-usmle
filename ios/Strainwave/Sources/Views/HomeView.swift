import SwiftUI
import OutbreakEngine

/// The control panel. Everything a run needs is chosen here, and everything a
/// finished run produced is filed here.
///
/// This outer view exists only to build the model from the shared services —
/// `@EnvironmentObject` is not readable inside `View.init` — and hands the real
/// screen the objects it must observe directly.
struct HomeView: View {

    let onStart: (GameSetup) -> Void

    @EnvironmentObject private var environment: AppEnvironment
    @StateObject private var host = HomeHost()

    var body: some View {
        Group {
            if let model = host.model {
                HomeContent(
                    model: model,
                    store: environment.store,
                    ads: environment.ads,
                    onStart: onStart
                )
            } else {
                Theme.Palette.background
            }
        }
        .onAppear { host.makeIfNeeded(environment: environment) }
    }
}

/// Keeps the home model alive across re-renders.
@MainActor
private final class HomeHost: ObservableObject {
    @Published private(set) var model: HomeViewModel?

    func makeIfNeeded(environment: AppEnvironment) {
        guard model == nil else { return }
        model = environment.makeHomeViewModel()
    }
}

private struct HomeContent: View {

    @ObservedObject var model: HomeViewModel
    /// Observed directly: a nested `ObservableObject` does not forward its
    /// changes through `AppEnvironment`.
    @ObservedObject var store: ReportStore
    @ObservedObject var ads: AdManager
    let onStart: (GameSetup) -> Void

    @EnvironmentObject private var environment: AppEnvironment
    @State private var showsReports = false
    @State private var showsAchievements = false
    @State private var showsSettings = false

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Metrics.spacingSection) {
                masthead
                startPanel
                dailyPanel
                shelf
                footer
            }
            .padding(.horizontal, Theme.Metrics.spacingWide)
            .padding(.vertical, Theme.Metrics.spacingWide)
        }
        .background(Theme.Palette.background.ignoresSafeArea())
        .safeAreaInset(edge: .bottom) { bottomBar }
        .sheet(isPresented: $showsReports) {
            ReportsGalleryView(reports: store.reports)
        }
        .sheet(isPresented: $showsAchievements) {
            AchievementsView(earned: store.earnedAchievements)
        }
        .sheet(isPresented: $showsSettings) {
            SettingsView()
        }
        .onAppear { model.normaliseSelection() }
    }

    // MARK: Masthead

    private var masthead: some View {
        VStack(spacing: Theme.Metrics.spacing) {
            PathogenGlyph(unlockedTraits: [], innateArms: 6)
                .frame(width: 120, height: 120)
            VStack(spacing: 2) {
                Text(L.string("app.name"))
                    .font(Theme.Typography.title)
                    .foregroundStyle(Theme.Palette.textPrimary)
                Text(L.string("app.tagline"))
                    .font(Theme.Typography.callout)
                    .foregroundStyle(Theme.Palette.textSecondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, Theme.Metrics.spacing)
    }

    // MARK: Start

    private var startPanel: some View {
        Panel {
            VStack(alignment: .leading, spacing: Theme.Metrics.spacingWide) {
                SectionHeader(title: L.string("home.strain"))
                sampleRow

                SectionHeader(title: L.string("home.difficulty"))
                optionRow(
                    options: Difficulty.allCases,
                    selection: model.difficulty,
                    identifier: { A11y.Home.difficulty($0.rawValue) },
                    title: { L.difficultyTitle($0) },
                    detail: { L.difficultyDetail($0) },
                    select: { model.difficulty = $0 }
                )

                SectionHeader(title: L.string("home.scenario"))
                optionRow(
                    options: StartScenario.allCases,
                    selection: model.scenario,
                    identifier: { A11y.Home.scenario($0.rawValue) },
                    title: { L.scenarioTitle($0) },
                    detail: { L.scenarioDetail($0) },
                    select: { model.scenario = $0 }
                )

            }
        }
    }

    /// The primary action lives in a pinned bar rather than at the end of the
    /// scroll. At the largest text sizes the set-up panel is taller than the
    /// screen, and a "Begin Outbreak" the reader has to hunt for is a control
    /// that is, for them, missing.
    private var bottomBar: some View {
        VStack(spacing: Theme.Metrics.spacing) {
            PrimaryButton(title: L.string("home.start"), systemImage: "bolt.fill") {
                environment.feedback.play(.tap)
                onStart(model.makeSetup())
            }
            .accessibilityIdentifier(A11y.Home.start)
            .padding(.horizontal, Theme.Metrics.spacingWide)
            .padding(.top, Theme.Metrics.spacing)

            bannerSlot
        }
        // Opaque rather than a material: text scrolling underneath a
        // translucent bar loses contrast against it, which the accessibility
        // audit reads — correctly — as unreadable.
        .background(
            Theme.Palette.surface
                .overlay(alignment: .top) {
                    Rectangle()
                        .fill(Theme.Palette.outline)
                        .frame(height: Theme.Metrics.hairline)
                }
                .ignoresSafeArea(edges: .bottom)
        )
    }

    /// Samples are presented as petri-dish cards — a circular culture with the
    /// strain's own glyph inside.
    private var sampleRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Theme.Metrics.spacing) {
                ForEach(StrainCatalog.all) { strain in
                    SampleCard(
                        strain: strain,
                        isSelected: model.strain == strain.id,
                        isPlayable: model.isPlayable(strain.id)
                    ) {
                        if model.isPlayable(strain.id) {
                            model.strain = strain.id
                            environment.feedback.play(.tap)
                        } else {
                            model.unlockStrain(strain.id)
                        }
                    }
                    .accessibilityIdentifier(A11y.Home.sample(strain.id.rawValue))
                }
            }
            .padding(.horizontal, 2)
            .padding(.vertical, 4)
        }
    }

    /// A row of mutually exclusive choices, used for both tier and starting world.
    private func optionRow<Option: Hashable>(
        options: [Option],
        selection: Option,
        identifier: @escaping (Option) -> String,
        title: @escaping (Option) -> String,
        detail: @escaping (Option) -> String,
        select: @escaping (Option) -> Void
    ) -> some View {
        VStack(spacing: Theme.Metrics.spacingTight) {
            ForEach(options, id: \.self) { option in
                Button {
                    select(option)
                    environment.feedback.play(.tap)
                } label: {
                    HStack(alignment: .top, spacing: Theme.Metrics.spacing) {
                        Image(systemName: option == selection ? "largecircle.fill.circle" : "circle")
                            .foregroundStyle(
                                option == selection ? Theme.Palette.spread : Theme.Palette.textTertiary
                            )
                        VStack(alignment: .leading, spacing: 2) {
                            Text(title(option))
                                .font(Theme.Typography.callout.weight(.semibold))
                                .foregroundStyle(Theme.Palette.textPrimary)
                            Text(detail(option))
                                .font(Theme.Typography.caption)
                                .foregroundStyle(Theme.Palette.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 0)
                    }
                    .frame(minHeight: Theme.Metrics.minimumTapTarget)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier(identifier(option))
                .accessibilityAddTraits(option == selection ? [.isSelected, .isButton] : .isButton)
            }
        }
    }

    // MARK: Daily challenge

    private var dailyPanel: some View {
        let challenge = model.todaysChallenge
        return Panel(tint: Theme.Palette.surfaceRaised) {
            VStack(alignment: .leading, spacing: Theme.Metrics.spacing) {
                HStack {
                    SectionHeader(title: L.string("home.daily"))
                    if model.hasPlayedTodaysChallenge {
                        Chip(
                            text: L.string("home.dailyPlayed"),
                            systemImage: "checkmark.seal.fill",
                            tint: Theme.Palette.success
                        )
                    }
                }

                Text(L.objective(challenge.objective))
                    .font(Theme.Typography.callout)
                    .foregroundStyle(Theme.Palette.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: Theme.Metrics.spacingTight) {
                    Chip(text: L.strainTitle(challenge.setup.strain), systemImage: "circle.hexagonpath")
                    Chip(text: L.difficultyTitle(challenge.setup.difficulty), systemImage: "gauge.medium")
                    Chip(text: L.scenarioTitle(challenge.setup.scenario), systemImage: "globe")
                }

                SecondaryButton(title: L.string("home.start"), systemImage: "calendar") {
                    environment.feedback.play(.tap)
                    onStart(challenge.setup)
                }
                .accessibilityIdentifier(A11y.Home.dailyStart)
            }
        }
    }

    // MARK: Shelf

    private var shelf: some View {
        Panel {
            VStack(alignment: .leading, spacing: Theme.Metrics.spacing) {
                SectionHeader(title: L.string("home.reports")) {
                    Button(L.string("home.seeAll")) { showsReports = true }
                        .font(Theme.Typography.caption.weight(.semibold))
                        .foregroundStyle(Theme.Palette.spread)
                        .frame(minHeight: Theme.Metrics.minimumTapTarget)
                }

                if store.reports.isEmpty {
                    EmptyStateView(
                        title: L.string("empty.reports.title"),
                        detail: L.string("empty.reports.detail"),
                        illustration: .shelf
                    )
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: Theme.Metrics.spacing) {
                            ForEach(Array(store.reports.prefix(8))) { report in
                                ReportCard(report: report)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
        }
    }

    private var footer: some View {
        HStack(spacing: Theme.Metrics.spacing) {
            SecondaryButton(title: L.string("home.achievements"), systemImage: "rosette") {
                showsAchievements = true
            }
            .accessibilityIdentifier(A11y.Home.achievements)
            SecondaryButton(title: L.string("home.settings"), systemImage: "gearshape.fill") {
                showsSettings = true
            }
            .accessibilityIdentifier(A11y.Home.settings)
        }
    }

    /// The optional home-screen banner slot. Nothing is reserved until an ad is
    /// actually available, so the layout never shows a grey gap.
    @ViewBuilder
    private var bannerSlot: some View {
        if ads.isBannerEnabled {
            BannerAdView()
                .frame(height: 50)
                .background(Theme.Palette.surface)
        }
    }
}

/// A petri-dish sample card.
private struct SampleCard: View {

    let strain: Strain
    let isSelected: Bool
    let isPlayable: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: Theme.Metrics.spacingTight) {
                ZStack {
                    // The dish: two concentric rings and a tinted culture.
                    Circle()
                        .fill(Theme.Palette.surfaceRaised)
                    Circle()
                        .strokeBorder(
                            isSelected ? Theme.Palette.spread : Theme.Palette.outline,
                            lineWidth: isSelected ? 3 : 1.5
                        )
                    Circle()
                        .fill(Theme.Palette.spreadSoft.opacity(0.45))
                        .padding(10)

                    if isPlayable {
                        PathogenGlyph(
                            unlockedTraits: [],
                            innateArms: 5,
                            isPulsing: isSelected
                        )
                        .padding(16)
                    } else {
                        Image(systemName: "lock.fill")
                            .font(.title3)
                            .foregroundStyle(Theme.Palette.textTertiary)
                    }
                }
                .frame(width: 96, height: 96)

                Text(L.strainTitle(strain.id))
                    .font(Theme.Typography.callout.weight(.semibold))
                    .foregroundStyle(Theme.Palette.textPrimary)

                Text(isPlayable ? L.signature(strain.signature) : L.string("picker.unlockWithAd"))
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Palette.textSecondary)
                    .multilineTextAlignment(.center)
                    // No line limit and no fixed height: the card grows instead
                    // of cutting the sentence off.
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(width: 128)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(L.strainTitle(strain.id)))
        .accessibilityValue(Text(L.strainDetail(strain.id)))
        .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : .isButton)
    }
}

/// A filed report, as it appears on the shelf.
struct ReportCard: View {

    let report: EpidemicReport

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: report.isVictory ? "checkmark.seal.fill" : "xmark.seal.fill")
                    .foregroundStyle(report.isVictory ? Theme.Palette.success : Theme.Palette.textTertiary)
                Text(L.reportTitle(report.title))
                    .font(Theme.Typography.callout.weight(.semibold))
                    .foregroundStyle(Theme.Palette.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Text(L.format("report.durationValue", report.days))
                .font(Theme.Typography.caption)
                .foregroundStyle(Theme.Palette.textSecondary)
            Meter(value: report.reachFraction, tint: Theme.Palette.spread, height: 4)
            Text(Figures.percent(report.reachFraction))
                .font(Theme.Typography.figureSmall)
                .monospacedDigit()
                .foregroundStyle(Theme.Palette.spread)
        }
        .padding(Theme.Metrics.spacing)
        .frame(width: 168, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: Theme.Metrics.cornerRadiusSmall, style: .continuous)
                .fill(Theme.Palette.surfaceRaised)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Metrics.cornerRadiusSmall, style: .continuous)
                .strokeBorder(Theme.Palette.outline, lineWidth: Theme.Metrics.hairline)
        )
        .accessibilityElement(children: .combine)
    }
}

import SwiftUI
import Foundation
import OutbreakEngine

/// The run itself: control panel, board, ticker.
struct GameView: View {

    @ObservedObject var model: GameViewModel
    let onQuit: () -> Void
    /// Called once the run reaches an outcome. Declared here because this is
    /// the view that observes the model.
    var onFinished: (EpidemicReport, [Achievement]) -> Void = { _, _ in }

    @State private var selectedRegion: RegionID?
    @State private var showQuitConfirmation = false

    var body: some View {
        VStack(spacing: Theme.Metrics.spacing) {
            topBar
            ScrollView {
                VStack(spacing: Theme.Metrics.spacing) {
                    readoutRow
                    mapSection
                    tickerSection
                }
            }
        }
        .padding(.horizontal, Theme.Metrics.spacing)
        .background(Theme.Palette.background.ignoresSafeArea())
        // Pinned: on the smallest screen at the largest text size the readouts
        // and board are taller than the display, and controls the player cannot
        // reach are controls the app does not have.
        .safeAreaInset(edge: .bottom) {
            controlRow
                .padding(.horizontal, Theme.Metrics.spacing)
                .padding(.top, Theme.Metrics.spacingTight)
                .padding(.bottom, Theme.Metrics.spacingTight)
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
        .sheet(isPresented: $model.isAbilityMapPresented) {
            TraitTreeView(model: model) {
                model.isAbilityMapPresented = false
            }
            .presentationDragIndicator(.visible)
        }
        .sheet(item: $selectedRegion) { id in
            RegionDetailView(id: id, state: model.regionState(id)) {
                selectedRegion = nil
            }
            .presentationDetents([.height(320)])
        }
        .confirmationDialog(
            L.string("report.home"),
            isPresented: $showQuitConfirmation,
            titleVisibility: .visible
        ) {
            Button(L.string("report.home"), role: .destructive) {
                model.stop()
                onQuit()
            }
            .accessibilityIdentifier(A11y.Game.quitConfirm)
            Button(L.string("settings.cancel"), role: .cancel) {}
        }
        .onChange(of: model.finishedReport) { report in
            guard let report else { return }
            onFinished(report, model.freshAchievements)
        }
        .onDisappear { model.stop() }
    }

    // MARK: Top bar

    private var topBar: some View {
        HStack(spacing: Theme.Metrics.spacing) {
            Button { showQuitConfirmation = true } label: {
                Image(systemName: "chevron.backward")
                    .font(.headline)
                    .foregroundStyle(Theme.Palette.textSecondary)
                    .frame(width: Theme.Metrics.minimumTapTarget, height: Theme.Metrics.minimumTapTarget)
            }
            .accessibilityIdentifier(A11y.Game.quit)
            .accessibilityLabel(Text(L.string("common.back")))

            PathogenGlyph(unlockedTraits: model.state.unlockedTraits, isPulsing: false)
                .frame(width: 46, height: 46)

            VStack(alignment: .leading, spacing: 0) {
                Text(L.strainTitle(model.state.setup.strain))
                    .font(Theme.Typography.subheading)
                    .foregroundStyle(Theme.Palette.textPrimary)
                Text(L.difficultyTitle(model.state.setup.difficulty))
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Palette.textSecondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 0) {
                Text(L.string("hud.day"))
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Palette.textSecondary)
                Text(Figures.integer(model.state.day))
                    .font(Theme.Typography.readout)
                    .foregroundStyle(Theme.Palette.textPrimary)
            }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier(A11y.Game.day)
        }
        .padding(.top, Theme.Metrics.spacingTight)
    }

    // MARK: Readouts

    private var readoutRow: some View {
        Panel(padding: Theme.Metrics.spacing) {
            VStack(spacing: Theme.Metrics.spacing) {
                HStack(spacing: Theme.Metrics.spacing) {
                    Readout(
                        title: L.string("hud.points"),
                        value: Figures.integer(model.state.evolutionPoints),
                        accent: Theme.Palette.spread
                    )
                    Readout(
                        title: L.string("hud.infected"),
                        value: Figures.people(model.state.totalInfected + model.state.totalLost),
                        accent: Theme.Palette.textPrimary,
                        caption: Figures.percent(model.reachFraction)
                    )
                    Readout(
                        title: L.string("hud.regions"),
                        value: "\(model.state.infectedRegionCount)/\(RegionID.allCases.count)",
                        accent: Theme.Palette.textPrimary
                    )
                }

                VStack(spacing: Theme.Metrics.spacingTight) {
                    meterRow(
                        title: L.string("hud.awareness"),
                        value: model.state.globalAwareness / 100,
                        tint: Theme.Palette.response,
                        detail: Figures.percent(model.state.globalAwareness / 100, decimals: 0)
                    )
                    meterRow(
                        title: L.string("hud.research"),
                        value: model.state.researchProgress / 100,
                        tint: Theme.Palette.warning,
                        detail: countdownText
                    )
                    if let objective = model.state.setup.objective, let pressure = model.objectivePressure {
                        meterRow(
                            title: L.string("hud.objective"),
                            value: pressure,
                            tint: model.isObjectiveIntact == false
                                ? Theme.Palette.warning
                                : Theme.Palette.success,
                            detail: L.objective(objective)
                        )
                    }
                }
            }
        }
    }

    private func meterRow(title: String, value: Double, tint: Color, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(title)
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Palette.textSecondary)
                Spacer()
                Text(detail)
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Palette.textTertiary)
                    .multilineTextAlignment(.trailing)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Meter(value: value, tint: tint)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(title))
        .accessibilityValue(Text(detail))
    }

    private var countdownText: String {
        guard let days = model.solutionCountdown else {
            return L.string("hud.noSolutionYet")
        }
        return L.format("hud.solutionIn", days)
    }

    // MARK: Board

    private var mapSection: some View {
        WorldMapView(
            regions: model.state.regions,
            warningRegions: model.warningRegions,
            bubbles: model.state.bubbles,
            selectedRegion: selectedRegion,
            onSelectRegion: { selectedRegion = $0 },
            onCollect: { model.collect($0) }
        )
        .frame(maxWidth: .infinity)
    }

    // MARK: Ticker

    private var tickerSection: some View {
        Group {
            VStack(alignment: .leading, spacing: 4) {
                ForEach(model.ticker.prefix(6)) { event in
                    HStack(alignment: .top, spacing: 6) {
                        Text("\(L.string("hud.day")) \(event.day)")
                            .font(Theme.Typography.figureTiny)
                            .foregroundStyle(Theme.Palette.textTertiary)
                        Text(L.event(event))
                            .font(Theme.Typography.caption)
                            .foregroundStyle(Theme.Palette.textSecondary)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .contain)
    }

    // MARK: Controls

    private var controlRow: some View {
        HStack(spacing: Theme.Metrics.spacing) {
            Button {
                model.speed = model.speed == .paused ? .normal : .paused
            } label: {
                Image(systemName: model.speed == .paused ? "play.fill" : "pause.fill")
                    .font(.headline)
                    .frame(width: 54, height: 54)
                    .foregroundStyle(Theme.Palette.textPrimary)
                    .background(
                        RoundedRectangle(cornerRadius: Theme.Metrics.cornerRadius, style: .continuous)
                            .fill(Theme.Palette.surfaceRaised)
                    )
            }
            .accessibilityIdentifier(A11y.Game.playPause)
            .accessibilityLabel(Text(L.string(model.speed == .paused ? "hud.play" : "hud.pause")))

            Button {
                model.speed = model.speed == .fast ? .normal : .fast
            } label: {
                Image(systemName: model.speed == .fast ? "forward.end.fill" : "forward.fill")
                    .font(.headline)
                    .frame(width: 54, height: 54)
                    .foregroundStyle(model.speed == .fast ? .white : Theme.Palette.textPrimary)
                    .background(
                        RoundedRectangle(cornerRadius: Theme.Metrics.cornerRadius, style: .continuous)
                            .fill(model.speed == .fast ? Theme.Palette.response : Theme.Palette.surfaceRaised)
                    )
            }
            .accessibilityIdentifier(A11y.Game.speed)
            .accessibilityLabel(Text(L.string("hud.speed")))

            PrimaryButton(title: L.string("hud.abilities"), systemImage: "circle.hexagongrid.fill") {
                model.pause()
                model.isAbilityMapPresented = true
            }
            .accessibilityIdentifier(A11y.Game.abilities)
        }
    }
}

/// Tapping a territory opens its figures — the detail the board itself keeps
/// deliberately abstract.
private struct RegionDetailView: View {

    let id: RegionID
    let state: RegionState
    let onClose: () -> Void

    private var blueprint: RegionBlueprint { RegionCatalog.blueprint(id) }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Metrics.spacing) {
            HStack {
                Text(L.region(id))
                    .font(Theme.Typography.heading)
                    .foregroundStyle(Theme.Palette.textPrimary)
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(Theme.Palette.textTertiary)
                }
                .frame(minWidth: Theme.Metrics.minimumTapTarget, minHeight: Theme.Metrics.minimumTapTarget)
                .accessibilityLabel(Text(L.string("common.close")))
            }

            HStack(spacing: Theme.Metrics.spacingTight) {
                Chip(text: L.climate(blueprint.climate), systemImage: "thermometer.medium")
                Chip(text: L.wealth(blueprint.wealth), systemImage: "building.columns")
                Chip(text: L.density(blueprint.density), systemImage: "person.3.fill")
            }

            HStack(spacing: Theme.Metrics.spacing) {
                Readout(
                    title: L.string("hud.infected"),
                    value: Figures.people(state.infected + state.lost),
                    accent: Theme.Palette.spread,
                    caption: Figures.percent(state.touchedFraction)
                )
                Readout(
                    title: L.string("report.lost"),
                    value: Figures.people(state.lost),
                    accent: Theme.Palette.textPrimary
                )
                Readout(
                    title: L.string("hud.awareness"),
                    value: Figures.percent(state.awareness / 100, decimals: 0),
                    accent: Theme.Palette.response
                )
            }

            if state.bordersClosed {
                Chip(
                    text: L.string("map.bordersClosed"),
                    systemImage: "hand.raised.fill",
                    tint: Theme.Palette.response
                )
            } else if state.transportLocked {
                Chip(
                    text: L.string("map.locked"),
                    systemImage: "airplane.circle",
                    tint: Theme.Palette.response
                )
            }

            Spacer(minLength: 0)
        }
        .padding(Theme.Metrics.spacingWide)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.Palette.background.ignoresSafeArea())
    }
}

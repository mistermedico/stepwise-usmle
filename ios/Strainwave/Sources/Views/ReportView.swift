import SwiftUI
import Foundation
import OutbreakEngine

/// The end-of-run summary (section 2.5). The figures land first, then the
/// timeline draws itself in one entry at a time, so the screen builds like a
/// live infographic rather than appearing all at once.
struct ReportView: View {

    let report: EpidemicReport
    let freshAchievements: [Achievement]
    let onPlayAgain: () -> Void
    let onHome: () -> Void

    @State private var revealedEntries = 0
    @State private var headlineShown = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var isAnimated: Bool { !reduceMotion && !Settings.prefersReducedMotion }

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Metrics.spacingSection) {
                headline
                figures
                timeline
                if !freshAchievements.isEmpty { achievements }
                actions
            }
            .padding(.horizontal, Theme.Metrics.spacingWide)
            .padding(.vertical, Theme.Metrics.spacingSection)
        }
        .background(Theme.Palette.background.ignoresSafeArea())
        .accessibilityIdentifier(A11y.Report.root)
        .onAppear(perform: revealSequentially)
    }

    // MARK: Headline

    private var headline: some View {
        VStack(spacing: Theme.Metrics.spacing) {
            PathogenGlyph(
                unlockedTraits: Set(report.traitsUnlocked),
                isPulsing: report.isVictory,
                coreColor: report.isVictory ? Theme.Palette.spread : Theme.Palette.textTertiary,
                glowColor: report.isVictory ? Theme.Palette.spreadGlow : Theme.Palette.outline
            )
            .frame(width: 132, height: 132)

            Text(L.string("report.title.header"))
                .font(Theme.Typography.caption)
                .foregroundStyle(Theme.Palette.textSecondary)
                .textCase(.uppercase)

            Text(L.reportTitle(report.title))
                .font(Theme.Typography.title)
                .foregroundStyle(Theme.Palette.textPrimary)
                .multilineTextAlignment(.center)
                .accessibilityIdentifier(A11y.Report.title)

            if case .defeat(let reason) = report.outcome {
                Text(L.defeatReason(reason))
                    .font(Theme.Typography.callout)
                    .foregroundStyle(Theme.Palette.textSecondary)
            }

            if let objective = report.objective {
                Chip(
                    text: L.objective(objective),
                    systemImage: report.objectiveMet == true ? "checkmark.seal.fill" : "xmark.seal.fill",
                    tint: report.objectiveMet == true ? Theme.Palette.success : Theme.Palette.warning
                )
            }
        }
        .opacity(headlineShown ? 1 : 0)
        .scaleEffect(headlineShown ? 1 : 0.94)
        .frame(maxWidth: .infinity)
    }

    // MARK: Figures

    private var figures: some View {
        Panel {
            VStack(spacing: Theme.Metrics.spacingWide) {
                HStack(spacing: Theme.Metrics.spacing) {
                    Readout(
                        title: L.string("report.duration"),
                        value: L.format("report.durationValue", report.days),
                        accent: Theme.Palette.textPrimary
                    )
                    Readout(
                        title: L.string("report.reached"),
                        value: Figures.percent(report.reachFraction),
                        accent: Theme.Palette.spread,
                        caption: Figures.people(report.totalInfected)
                    )
                    Readout(
                        title: L.string("report.lost"),
                        value: Figures.percent(report.lossFraction),
                        accent: Theme.Palette.warning,
                        caption: Figures.people(report.totalLost)
                    )
                }

                VStack(alignment: .leading, spacing: Theme.Metrics.spacingTight) {
                    Meter(value: report.reachFraction, tint: Theme.Palette.spread, height: 8)
                    HStack {
                        Text(detectionSummary)
                            .font(Theme.Typography.caption)
                            .foregroundStyle(Theme.Palette.textSecondary)
                        Spacer()
                        Text("\(report.regionsReached)/\(RegionID.allCases.count)")
                            .font(Theme.Typography.figure(12, weight: .semibold))
                            .foregroundStyle(Theme.Palette.textTertiary)
                    }
                }

                HStack(spacing: Theme.Metrics.spacingTight) {
                    Chip(text: L.strainTitle(report.strain), systemImage: "circle.hexagonpath")
                    Chip(text: L.difficultyTitle(report.difficulty), systemImage: "gauge.medium")
                    Chip(text: L.region(report.originRegion), systemImage: "mappin.circle")
                }
            }
        }
    }

    private var detectionSummary: String {
        guard let day = report.detectionDay else {
            return L.string("report.neverDetected")
        }
        return L.format("report.detected", day)
    }

    // MARK: Timeline

    private var timeline: some View {
        Panel {
            VStack(alignment: .leading, spacing: Theme.Metrics.spacing) {
                SectionHeader(title: L.string("report.timeline"))

                ForEach(Array(report.timeline.enumerated()), id: \.element.id) { index, event in
                    TimelineRow(
                        event: event,
                        isLast: index == report.timeline.count - 1
                    )
                    .opacity(index < revealedEntries ? 1 : 0)
                    .offset(y: index < revealedEntries ? 0 : 8)
                }
            }
        }
    }

    // MARK: Achievements

    private var achievements: some View {
        Panel(tint: Theme.Palette.surfaceRaised) {
            VStack(alignment: .leading, spacing: Theme.Metrics.spacing) {
                SectionHeader(title: L.string("report.newAchievements"))
                ForEach(freshAchievements, id: \.self) { achievement in
                    HStack(spacing: Theme.Metrics.spacing) {
                        Image(systemName: "rosette")
                            .foregroundStyle(Theme.Palette.success)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(L.achievementTitle(achievement))
                                .font(Theme.Typography.callout.weight(.semibold))
                                .foregroundStyle(Theme.Palette.textPrimary)
                            Text(L.achievementDetail(achievement))
                                .font(Theme.Typography.caption)
                                .foregroundStyle(Theme.Palette.textSecondary)
                        }
                        Spacer(minLength: 0)
                    }
                    .accessibilityElement(children: .combine)
                }
            }
        }
    }

    // MARK: Actions

    private var actions: some View {
        VStack(spacing: Theme.Metrics.spacing) {
            PrimaryButton(title: L.string("report.again"), systemImage: "arrow.clockwise", action: onPlayAgain)
                .accessibilityIdentifier(A11y.Report.again)

            HStack(spacing: Theme.Metrics.spacing) {
                ShareLink(item: shareText) {
                    HStack(spacing: Theme.Metrics.spacingTight) {
                        Image(systemName: "square.and.arrow.up")
                        Text(L.string("report.share"))
                            .font(Theme.Typography.callout.weight(.semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: Theme.Metrics.minimumTapTarget)
                    .foregroundStyle(Theme.Palette.textPrimary)
                    .background(
                        RoundedRectangle(cornerRadius: Theme.Metrics.cornerRadius, style: .continuous)
                            .fill(Theme.Palette.surfaceRaised)
                    )
                }

                SecondaryButton(title: L.string("report.home"), systemImage: "house.fill", action: onHome)
                    .accessibilityIdentifier(A11y.Report.home)
            }
        }
    }

    private var shareText: String {
        L.format(
            "report.shareBody",
            L.string("app.name"),
            L.reportTitle(report.title),
            report.days,
            report.reachFraction * 100
        )
    }

    // MARK: Reveal

    /// Brings the headline in, then unrolls the timeline one entry at a time.
    private func revealSequentially() {
        guard isAnimated else {
            headlineShown = true
            revealedEntries = report.timeline.count
            return
        }

        withAnimation(Theme.Motion.screen) { headlineShown = true }

        for index in report.timeline.indices {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35 + Double(index) * 0.12) {
                withAnimation(Theme.Motion.quick) {
                    self.revealedEntries = index + 1
                }
            }
        }
    }
}

/// One entry on the report timeline, with the connecting rail.
private struct TimelineRow: View {

    let event: GameEvent
    let isLast: Bool

    var body: some View {
        HStack(alignment: .top, spacing: Theme.Metrics.spacing) {
            VStack(spacing: 0) {
                Circle()
                    .fill(tint)
                    .frame(width: 10, height: 10)
                if !isLast {
                    Rectangle()
                        .fill(Theme.Palette.outline)
                        .frame(width: 1.5)
                        .frame(maxHeight: .infinity)
                }
            }
            .frame(width: 10)

            VStack(alignment: .leading, spacing: 1) {
                Text("\(L.string("hud.day")) \(event.day)")
                    .font(Theme.Typography.figure(11, weight: .semibold))
                    .foregroundStyle(Theme.Palette.textTertiary)
                Text(L.event(event))
                    .font(Theme.Typography.callout)
                    .foregroundStyle(Theme.Palette.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.bottom, isLast ? 0 : Theme.Metrics.spacing)

            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }

    private var tint: Color {
        switch event.kind {
        case .victory: return Theme.Palette.success
        case .defeat: return Theme.Palette.warning
        case .strainDetected, .researchBegan, .researchMilestone: return Theme.Palette.response
        default: return Theme.Palette.spread
        }
    }
}

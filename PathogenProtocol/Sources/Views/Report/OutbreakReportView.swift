import SwiftUI
import UIKit

/// The end-of-run "Outbreak Report" (spec section 2.5): an infographic-style summary
/// that builds in as a short sequence, with a share button for the plain-text summary.
struct OutbreakReportView: View {
    @StateObject var viewModel: ReportViewModel
    let onDone: () -> Void

    @State private var revealStage = 0
    @State private var showsShareSheet = false

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                if let summary = viewModel.summary {
                    outcomeBadge(summary)
                        .opacity(revealStage >= 1 ? 1 : 0)
                        .offset(y: revealStage >= 1 ? 0 : 12)

                    Text(LocalizedStringKey(summary.character.titleKey))
                        .font(AppFont.screenTitle)
                        .foregroundStyle(AppColor.textPrimary)
                        .opacity(revealStage >= 2 ? 1 : 0)

                    timeline(summary: summary)
                        .opacity(revealStage >= 3 ? 1 : 0)

                    statGrid(summary: summary)
                        .opacity(revealStage >= 4 ? 1 : 0)

                    if !viewModel.newlyUnlockedAchievementIDs.isEmpty {
                        newAchievements
                            .opacity(revealStage >= 4 ? 1 : 0)
                    }

                    shareButton
                        .opacity(revealStage >= 4 ? 1 : 0)
                }

                Button("common.continue", action: onDone)
                    .buttonStyle(SecondaryButtonStyle())
                    .opacity(revealStage >= 4 ? 1 : 0)
            }
            .padding(20)
        }
        .background(AppColor.labBackground.ignoresSafeArea())
        .onAppear { animateReveal() }
        .sheet(isPresented: $showsShareSheet) {
            ShareSheet(activityItems: [viewModel.shareText])
        }
    }

    private func animateReveal() {
        for stage in 1...4 {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(stage) * 0.35) {
                withAnimation(.easeOut(duration: 0.4)) { revealStage = stage }
            }
        }
    }

    private func outcomeBadge(_ summary: ReportAnalyzer.ReportSummary) -> some View {
        let isVictory = summary.outcome == .victory
        return ZStack {
            Circle()
                .fill(isVictory ? AppColor.contagion.opacity(0.15) : AppColor.response.opacity(0.15))
                .frame(width: 120, height: 120)
            Image(systemName: isVictory ? "atom" : "shield.checkered")
                .font(.system(size: 44, weight: .light))
                .foregroundStyle(isVictory ? AppColor.contagion : AppColor.response)
        }
    }

    private func timeline(summary: ReportAnalyzer.ReportSummary) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("report.timeline_title")
                .font(AppFont.cardTitle)
                .foregroundStyle(AppColor.textPrimary)
            GeometryReader { geo in
                let points = viewModel.finalState.history
                ZStack {
                    Path { path in
                        guard points.count > 1 else { return }
                        for (index, point) in points.enumerated() {
                            let x = geo.size.width * CGFloat(index) / CGFloat(points.count - 1)
                            let y = geo.size.height * (1 - CGFloat(point.globalInfectionFraction))
                            if index == 0 { path.move(to: CGPoint(x: x, y: y)) } else { path.addLine(to: CGPoint(x: x, y: y)) }
                        }
                    }
                    .stroke(AppColor.contagion, style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))

                    Path { path in
                        guard points.count > 1 else { return }
                        for (index, point) in points.enumerated() {
                            let x = geo.size.width * CGFloat(index) / CGFloat(points.count - 1)
                            let y = geo.size.height * (1 - CGFloat(point.globalAwareness))
                            if index == 0 { path.move(to: CGPoint(x: x, y: y)) } else { path.addLine(to: CGPoint(x: x, y: y)) }
                        }
                    }
                    .stroke(AppColor.response, style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                }
            }
            .frame(height: 120)
        }
        .padding(16)
        .background(AppColor.labSurface)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func statGrid(summary: ReportAnalyzer.ReportSummary) -> some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            statTile(titleKey: "report.stat.days", value: "\(summary.totalDays)")
            statTile(titleKey: "report.stat.peak_awareness", value: "\(Int(summary.peakAwareness * 100))%")
            statTile(titleKey: "report.stat.final_spread", value: "\(Int(summary.finalInfectionFraction * 100))%")
            statTile(titleKey: "report.stat.regions_lost", value: "\(summary.regionsFullyLost)")
        }
    }

    private func statTile(titleKey: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(AppFont.largeStat)
                .foregroundStyle(AppColor.textPrimary)
            Text(LocalizedStringKey(titleKey))
                .font(AppFont.body(12))
                .foregroundStyle(AppColor.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(AppColor.labSurface)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var newAchievements: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("report.new_achievements")
                .font(AppFont.cardTitle)
                .foregroundStyle(AppColor.textPrimary)
            ForEach(Array(viewModel.newlyUnlockedAchievementIDs), id: \.self) { id in
                if let achievement = AchievementCatalog.all.first(where: { $0.id == id }) {
                    HStack {
                        Image(systemName: "rosette").foregroundStyle(AppColor.warning)
                        Text(LocalizedStringKey(achievement.titleKey))
                            .font(AppFont.body(14, weight: .semibold))
                    }
                }
            }
        }
        .padding(16)
        .background(AppColor.labSurface)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var shareButton: some View {
        Button {
            showsShareSheet = true
        } label: {
            Label("report.share", systemImage: "square.and.arrow.up")
        }
        .buttonStyle(PrimaryButtonStyle(tint: AppColor.response))
    }
}

private struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

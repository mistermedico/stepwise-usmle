import SwiftUI

/// The top status bar during a run: day counter, evolution points, and the two
/// competing progress readouts (global awareness vs. research), plus the
/// precomputed cure countdown once research has activated (spec sections 2/3/4).
struct GameHUDView: View {
    let state: GameState
    let isPaused: Bool
    let onTogglePause: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Label("\("hud.day".localized) \(state.day)", systemImage: "calendar")
                    .font(AppFont.stat)
                    .foregroundStyle(AppColor.textPrimary)

                Spacer()

                Label("\(Int(state.evolutionPoints))", systemImage: "atom")
                    .font(AppFont.stat)
                    .foregroundStyle(AppColor.contagion)

                Button(action: onTogglePause) {
                    Image(systemName: isPaused ? "play.fill" : "pause.fill")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(AppColor.textPrimary)
                        .padding(8)
                        .background(AppColor.labSurface)
                        .clipShape(Circle())
                }
                .accessibilityLabel(Text(isPaused ? "hud.resume" : "hud.pause"))
            }

            statBar(
                titleKey: "hud.spread",
                value: state.globalInfectionFraction,
                color: AppColor.contagion
            )
            statBar(
                titleKey: "hud.awareness",
                value: state.globalAwareness,
                color: AppColor.response
            )

            if let cureDay = state.projectedCureDay {
                Text("hud.cure_projected \(cureDay)")
                    .font(AppFont.body(12, weight: .semibold))
                    .foregroundStyle(AppColor.warning)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(16)
        .background(AppColor.labSurface.opacity(0.9))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .padding(.horizontal, 16)
    }

    private func statBar(titleKey: String, value: Double, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(LocalizedStringKey(titleKey))
                    .font(AppFont.body(11, weight: .semibold))
                    .foregroundStyle(AppColor.textSecondary)
                Spacer()
                Text("\(Int(value * 100))%")
                    .font(AppFont.body(11, weight: .bold))
                    .foregroundStyle(color)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(AppColor.divider)
                    Capsule()
                        .fill(color)
                        .frame(width: geo.size.width * CGFloat(min(max(value, 0), 1)))
                        .animation(.easeInOut(duration: 0.5), value: value)
                }
            }
            .frame(height: 8)
        }
    }
}

extension String {
    /// Convenience for building a localized string with interpolated arguments in
    /// non-Text contexts (e.g. inside another `Label`'s title).
    var localized: String {
        NSLocalizedString(self, comment: "")
    }
}

import SwiftUI

/// Lives, the fill/mark mode switch, and the three booster buttons — everything the player
/// needs while actively solving, kept in one compact bar above the board.
struct GameToolbarView: View {
    @ObservedObject var viewModel: GameViewModel
    var onPause: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                livesView
                Spacer()
                Picker("", selection: $viewModel.inputMode) {
                    Text(String(localized: "toolbar.mode.fill")).tag(GameViewModel.InputMode.fill)
                    Text(String(localized: "toolbar.mode.mark")).tag(GameViewModel.InputMode.mark)
                }
                .pickerStyle(.segmented)
                .frame(width: 160)
                Spacer()
                Button(action: onPause) {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 18))
                }
                .accessibilityLabel(Text(String(localized: "toolbar.settings")))
            }

            HStack(spacing: 12) {
                BoosterButton(
                    systemImage: "eye.fill",
                    count: viewModel.remainingBoosterCount(.revealLine),
                    label: String(localized: "booster.revealLine"),
                    action: viewModel.useRevealLineBooster
                )
                BoosterButton(
                    systemImage: "checkmark.shield.fill",
                    count: viewModel.remainingBoosterCount(.checkErrors),
                    label: String(localized: "booster.checkErrors"),
                    action: {
                        viewModel.useCheckErrorsBooster()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
                            viewModel.clearErrorFlags()
                        }
                    }
                )
                BoosterButton(
                    systemImage: "lightbulb.fill",
                    count: viewModel.remainingBoosterCount(.hintCell),
                    label: String(localized: "booster.hint"),
                    action: viewModel.useHintBooster
                )
            }
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }

    private var livesView: some View {
        HStack(spacing: 3) {
            ForEach(0..<PlayerProgress.Constants.maxLives, id: \.self) { index in
                Image(systemName: index < viewModel.remainingLives ? "heart.fill" : "heart")
                    .foregroundColor(index < viewModel.remainingLives ? .red : Color("GridLine"))
                    .font(.system(size: 15))
            }
        }
    }
}

private struct BoosterButton: View {
    let systemImage: String
    let count: Int
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Image(systemName: systemImage)
                    .font(.system(size: 18))
                Text("\(count)")
                    .font(.caption2.monospacedDigit())
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(Color("BackgroundSecondary"))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .disabled(count <= 0)
        .opacity(count <= 0 ? 0.4 : 1.0)
        .accessibilityLabel(Text(label))
    }
}

import SwiftUI

/// Presented as a sheet when lives hit zero. Never a hard wall — the player can watch a
/// rewarded ad for an immediate extra life, or just wait for the next free regeneration tick.
struct LivesDepletedView: View {
    @EnvironmentObject private var appViewModel: AppViewModel
    let onLifeGranted: () -> Void

    @State private var isShowingAd = false
    @State private var now = Date()

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "heart.slash.fill")
                .font(.system(size: 44))
                .foregroundColor(.red)
                .padding(.top, 24)

            Text(String(localized: "lives.title"))
                .font(.title2.bold())

            Text(String(localized: "lives.subtitle"))
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            Button(action: watchAd) {
                HStack {
                    if isShowingAd {
                        ProgressView().tint(.white)
                    } else {
                        Image(systemName: "play.rectangle.fill")
                    }
                    Text(String(localized: "lives.watchAd"))
                }
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.accentColor)
                .foregroundColor(.white)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .disabled(isShowingAd)
            .padding(.horizontal, 24)

            Text(String(format: String(localized: "lives.waitFormat"), timeRemainingText))
                .font(.footnote)
                .foregroundColor(.secondary)
                .padding(.bottom, 24)
        }
        .onReceive(timer) { now = $0 }
    }

    private var timeRemainingText: String {
        let interval = PlayerProgress.Constants.lifeRegenerationInterval
        let elapsed = now.timeIntervalSince(appViewModel.progress.lastLifeRegenerationDate)
        let remaining = max(0, interval - elapsed.truncatingRemainder(dividingBy: interval))
        let minutes = Int(remaining) / 60
        let seconds = Int(remaining) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    private func watchAd() {
        isShowingAd = true
        appViewModel.adManager.loadRewarded(for: .extraLife)
        appViewModel.adManager.showRewarded(for: .extraLife) { granted in
            DispatchQueue.main.async {
                isShowingAd = false
                if granted {
                    appViewModel.grantLife()
                    onLifeGranted()
                }
            }
        }
    }
}

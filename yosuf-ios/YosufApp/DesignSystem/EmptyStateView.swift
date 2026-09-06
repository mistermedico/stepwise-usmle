import SwiftUI

/// A single, deliberately-designed "nothing here yet" state — used by
/// Achievements (before any unlock), History (before any match), and the
/// Daily Challenge (before today's attempt) — so an empty screen never
/// reads as a broken/blank one.
struct EmptyStateView: View {
    let systemImage: String
    let titleKey: LocalizedStringKey
    let messageKey: LocalizedStringKey

    var body: some View {
        VStack(spacing: Theme.spacingM) {
            Image(systemName: systemImage)
                .font(.system(size: 48))
                .foregroundStyle(Theme.accentGold.opacity(0.8))
            Text(titleKey)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.textPrimary)
            Text(messageKey)
                .font(.system(size: 15))
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Theme.spacingXL)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(Theme.spacingL)
    }
}

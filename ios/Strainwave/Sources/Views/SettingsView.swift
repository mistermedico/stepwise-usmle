import SwiftUI

/// Preferences, privacy entry points, and the reset control.
struct SettingsView: View {

    @EnvironmentObject private var environment: AppEnvironment
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    @State private var soundEnabled = Settings.isSoundEnabled
    @State private var hapticsEnabled = Settings.isHapticsEnabled
    @State private var reducedMotion = Settings.prefersReducedMotion
    @State private var showsResetConfirmation = false

    /// Hosted alongside the App Store listing. Also linked from the listing's
    /// privacy field — see docs/PRIVACY.md.
    private let privacyURL = URL(string: "https://strainwave.app/privacy")

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle(L.string("settings.sound"), isOn: $soundEnabled)
                        .onChange(of: soundEnabled) { value in
                            environment.feedback.isSoundEnabled = value
                        }
                    Toggle(L.string("settings.haptics"), isOn: $hapticsEnabled)
                        .onChange(of: hapticsEnabled) { value in
                            environment.feedback.isHapticsEnabled = value
                        }
                    Toggle(L.string("settings.reducedMotion"), isOn: $reducedMotion)
                        .onChange(of: reducedMotion) { value in
                            Settings.prefersReducedMotion = value
                        }
                }

                Section {
                    Button(L.string("settings.adChoices")) {
                        Task { await environment.consent.presentPrivacyOptions() }
                    }
                    if let privacyURL {
                        Button(L.string("settings.privacy")) { openURL(privacyURL) }
                    }
                }

                Section {
                    Button(L.string("settings.resetProgress"), role: .destructive) {
                        showsResetConfirmation = true
                    }
                } footer: {
                    Text(L.format("settings.version", appVersion))
                        .font(Theme.Typography.caption)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.Palette.background.ignoresSafeArea())
            .navigationTitle(L.string("home.settings"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L.string("common.close")) { dismiss() }
                }
            }
            .confirmationDialog(
                L.string("settings.resetConfirm"),
                isPresented: $showsResetConfirmation,
                titleVisibility: .visible
            ) {
                Button(L.string("settings.delete"), role: .destructive) {
                    environment.store.deleteAll()
                    soundEnabled = Settings.isSoundEnabled
                    hapticsEnabled = Settings.isHapticsEnabled
                    reducedMotion = Settings.prefersReducedMotion
                }
                Button(L.string("settings.cancel"), role: .cancel) {}
            }
        }
    }

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
}

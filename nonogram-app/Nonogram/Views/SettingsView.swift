import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var appViewModel: AppViewModel

    @State private var soundEnabled = SoundManager.shared.soundEnabled
    @State private var hapticsEnabled = HapticManager.shared.hapticsEnabled
    @State private var languageOverride: AppLanguageOverride = .system

    var body: some View {
        NavigationStack {
            Form {
                Section(appViewModel.localization.string("settings.section.feedback")) {
                    Toggle(appViewModel.localization.string("settings.sound"), isOn: $soundEnabled)
                        .onChange(of: soundEnabled) { appViewModel.soundManager.soundEnabled = $0 }
                    Toggle(appViewModel.localization.string("settings.haptics"), isOn: $hapticsEnabled)
                        .onChange(of: hapticsEnabled) { appViewModel.hapticManager.hapticsEnabled = $0 }
                }

                Section(appViewModel.localization.string("settings.section.language")) {
                    Picker(appViewModel.localization.string("settings.language"), selection: $languageOverride) {
                        ForEach(AppLanguageOverride.allCases) { option in
                            Text(option.displayName.localized(for: appViewModel.localization.languageCode))
                                .tag(option)
                        }
                    }
                    .onChange(of: languageOverride) { appViewModel.localization.override = $0 }
                }

                Section(appViewModel.localization.string("settings.section.about")) {
                    Link(appViewModel.localization.string("settings.privacyPolicy"), destination: URL(string: "https://example.com/privacy")!)
                        .foregroundColor(Color("TextPrimary"))

                    Button(appViewModel.localization.string("settings.restorePurchases")) {
                        // TODO: wire up when IAP (remove ads) ships.
                    }
                    .disabled(true)
                    .foregroundColor(.secondary)

                    HStack {
                        Text(appViewModel.localization.string("settings.version"))
                        Spacer()
                        Text(appVersionString)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle(appViewModel.localization.string("tab.settings"))
            .onAppear {
                languageOverride = appViewModel.localization.override
            }
        }
    }

    private var appVersionString: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
}

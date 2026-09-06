import SwiftUI

struct SettingsView: View {
    @StateObject private var viewModel = SettingsViewModel()

    var body: some View {
        Form {
            Section(String(localized: "settings.section.gameplay")) {
                Toggle(String(localized: "settings.tableHints"), isOn: $viewModel.tableHintsEnabled)
                Picker(String(localized: "settings.cardSkin"), selection: $viewModel.cardSkin) {
                    ForEach(CardSkin.allCases) { skin in
                        Text(LocalizedStringKey(skin.displayNameKey)).tag(skin)
                    }
                }
            }
            Section(String(localized: "settings.section.feedback")) {
                Toggle(String(localized: "settings.sound"), isOn: $viewModel.soundEnabled)
                Toggle(String(localized: "settings.haptics"), isOn: $viewModel.hapticsEnabled)
            }
            Section(String(localized: "settings.section.about")) {
                LabeledContent(String(localized: "settings.version"), value: appVersion)
                NavigationLink(String(localized: "settings.privacyPolicy")) {
                    PrivacyPolicyView()
                }
            }
        }
        .navigationTitle(String(localized: "home.settings"))
    }

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
}

private struct PrivacyPolicyView: View {
    var body: some View {
        ScrollView {
            Text(LocalizedStringKey("legal.privacyPolicyBody"))
                .padding(Theme.spacingL)
        }
        .navigationTitle(String(localized: "settings.privacyPolicy"))
    }
}

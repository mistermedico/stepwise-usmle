import SwiftUI
import YosufEngine

struct RuleProfileSelectionView: View {
    @State private var selected: RuleProfile = .classic
    @State private var opponentCount = 3
    @State private var customProfile = RuleProfile.defaultCustom
    @State private var startGame = false

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.spacingL) {
                ForEach(RuleProfile.allPresets, id: \.id) { profile in
                    RuleProfileCardView(profile: profile, isSelected: selected.id == profile.id) {
                        selected = profile
                    }
                }

                if selected.id == .custom {
                    CustomRuleProfileEditor(profile: $customProfile)
                }

                opponentCountPicker

                Button {
                    startGame = true
                } label: {
                    Text("rules.startMatch")
                }
                .buttonStyle(.primary)
                .padding(.top, Theme.spacingM)
            }
            .padding(Theme.spacingL)
        }
        .background(Theme.tableFelt.ignoresSafeArea())
        .navigationTitle(String(localized: "rules.chooseTitle"))
        .navigationDestination(isPresented: $startGame) {
            GameTableView(profile: selected.id == .custom ? customProfile.clamped() : selected, opponentCount: opponentCount)
        }
    }

    private var opponentCountPicker: some View {
        VStack(alignment: .leading, spacing: Theme.spacingS) {
            Text("rules.opponents")
                .font(.headline)
                .foregroundStyle(.white)
            Picker("", selection: $opponentCount) {
                ForEach(1...3, id: \.self) { count in
                    Text("\(count)").tag(count)
                }
            }
            .pickerStyle(.segmented)
        }
        .padding(Theme.spacingM)
        .themedSurface()
    }
}

struct RuleProfileCardView: View {
    let profile: RuleProfile
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: Theme.spacingM) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(Theme.accentGold)
                    .frame(width: 36)
                VStack(alignment: .leading, spacing: 2) {
                    Text(LocalizedStringKey(profile.displayNameKey))
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.textPrimary)
                    Text(LocalizedStringKey(profile.descriptionKey))
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                }
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.accentGold)
                }
            }
            .padding(Theme.spacingM)
        }
        .themedSurface()
        .overlay(
            RoundedRectangle(cornerRadius: Theme.cornerRadiusMedium, style: .continuous)
                .strokeBorder(isSelected ? Theme.accentGold : .clear, lineWidth: 2)
        )
        .buttonStyle(.plain)
    }

    private var icon: String {
        switch profile.id {
        case .classic: return "suit.spade.fill"
        case .quick: return "bolt.fill"
        case .grandma: return "heart.fill"
        case .street: return "sparkles"
        case .custom: return "slider.horizontal.3"
        }
    }
}

private struct CustomRuleProfileEditor: View {
    @Binding var profile: RuleProfile

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.spacingM) {
            stepperRow(titleKey: "rules.custom.threshold", value: $profile.yosufThreshold, range: 0...15)
            stepperRow(titleKey: "rules.custom.penalty", value: $profile.asafPenalty, range: 0...100, step: 5)
            stepperRow(titleKey: "rules.custom.maxScore", value: $profile.maxScore, range: 30...300, step: 10)
            Toggle(isOn: $profile.aceHigh) {
                Text("rules.custom.aceHigh")
            }
            Toggle(isOn: $profile.eventCardsEnabled) {
                Text("rules.custom.eventCards")
            }
        }
        .padding(Theme.spacingM)
        .themedSurface()
        .foregroundStyle(Theme.textPrimary)
    }

    private func stepperRow(titleKey: LocalizedStringKey, value: Binding<Int>, range: ClosedRange<Int>, step: Int = 1) -> some View {
        Stepper(value: value, in: range, step: step) {
            HStack {
                Text(titleKey)
                Spacer()
                Text("\(value.wrappedValue)").foregroundStyle(Theme.textSecondary)
            }
        }
    }
}

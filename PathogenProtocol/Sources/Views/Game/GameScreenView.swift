import SwiftUI

/// The active-run screen: map behind, HUD on top, a floating pathogen avatar +
/// "evolve" button that sheets in the upgrade tree.
struct GameScreenView: View {
    @ObservedObject var viewModel: GameViewModel
    @State private var showsUpgradeTree = false
    let onFinished: (GameState, Set<String>) -> Void

    var body: some View {
        ZStack {
            AppColor.labBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                GameHUDView(state: viewModel.state, isPaused: viewModel.isPaused, onTogglePause: viewModel.togglePause)
                    .padding(.top, 8)

                WorldMapView(
                    scenario: viewModel.state.scenario,
                    regionStates: viewModel.state.regionStates,
                    lockdownWarnings: viewModel.pendingLockdownWarnings
                )
                .padding(16)

                evolveButton
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
            }
        }
        .onAppear { viewModel.start() }
        .onDisappear { viewModel.stop() }
        .sheet(isPresented: $showsUpgradeTree) {
            UpgradeTreeSheet(viewModel: viewModel, isPresented: $showsUpgradeTree)
        }
        .onChange(of: viewModel.state.outcome) { outcome in
            guard outcome != nil else { return }
            onFinished(viewModel.state, viewModel.newlyUnlockedAchievementIDs)
        }
    }

    private var evolveButton: some View {
        Button {
            showsUpgradeTree = true
        } label: {
            HStack(spacing: 12) {
                PathogenAvatarView(unlockedUpgradeIDs: viewModel.state.unlockedUpgradeIDs)
                    .frame(width: 40, height: 40)
                Text("game.evolve_button")
                Spacer()
                Text("\(Int(viewModel.state.evolutionPoints))")
                    .font(AppFont.dashboard(16, weight: .bold))
            }
        }
        .buttonStyle(PrimaryButtonStyle())
    }
}

private struct UpgradeTreeSheet: View {
    @ObservedObject var viewModel: GameViewModel
    @Binding var isPresented: Bool

    var body: some View {
        NavigationStack {
            UpgradeTreeView(
                unlockedUpgradeIDs: viewModel.state.unlockedUpgradeIDs,
                evolutionPoints: viewModel.state.evolutionPoints,
                onPurchase: viewModel.purchaseUpgrade
            )
            .background(AppColor.labBackground.ignoresSafeArea())
            .navigationTitle(Text("game.evolution_tree_title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("common.done") { isPresented = false }
                }
            }
        }
    }
}

import SwiftUI

/// Grid of level tiles for one category. Completed levels show a small colored-square render
/// of their solved image; unlocked-but-unsolved levels show a neutral "play" placeholder
/// (never the answer); fully locked levels are dimmed with a lock icon.
struct LevelSelectView: View {
    @ObservedObject var viewModel: LevelListViewModel
    @EnvironmentObject private var appViewModel: AppViewModel

    private let columns = [GridItem(.adaptive(minimum: 110), spacing: 14)]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 14) {
                ForEach(viewModel.entries) { entry in
                    let unlocked = viewModel.isUnlocked(entry)
                    if unlocked {
                        NavigationLink {
                            GameHost(entry: entry)
                        } label: {
                            LevelTile(
                                entry: entry,
                                isUnlocked: true,
                                isCompleted: viewModel.isCompleted(entry),
                                isFlawless: viewModel.isFlawless(entry)
                            )
                        }
                        .buttonStyle(.plain)
                    } else {
                        LevelTile(entry: entry, isUnlocked: false, isCompleted: false, isFlawless: false)
                    }
                }
            }
            .padding()
        }
        .background(Color("BackgroundPrimary"))
        .navigationTitle(viewModel.category.displayName.localized(for: appViewModel.localization.languageCode))
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// Loads the full puzzle on demand once navigated to, then hosts `GameView`.
private struct GameHost: View {
    let entry: LevelIndexEntry
    @EnvironmentObject private var appViewModel: AppViewModel
    @State private var puzzle: Puzzle?

    var body: some View {
        Group {
            if let puzzle {
                GameView(viewModel: GameViewModel(puzzle: puzzle, appViewModel: appViewModel))
            } else {
                ProgressView()
                    .onAppear(perform: load)
            }
        }
    }

    private func load() {
        puzzle = try? PuzzleLoader().loadPuzzle(id: entry.id, category: entry.category)
    }
}

private struct LevelTile: View {
    let entry: LevelIndexEntry
    let isUnlocked: Bool
    let isCompleted: Bool
    let isFlawless: Bool

    @State private var completedPuzzle: Puzzle?

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                thumbnail
                if isFlawless {
                    VStack {
                        HStack {
                            Spacer()
                            Image(systemName: "star.fill")
                                .font(.caption)
                                .foregroundColor(.yellow)
                                .padding(4)
                        }
                        Spacer()
                    }
                }
                if !isUnlocked {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 22))
                        .foregroundColor(.white)
                }
            }
            .frame(height: 90)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            Text(sizeLabel)
                .font(.caption2)
                .foregroundColor(.secondary)

            DifficultyBadge(difficulty: entry.difficulty)
        }
        .padding(8)
        .background(Color("BackgroundSecondary"))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .opacity(isUnlocked ? 1.0 : 0.55)
        .onAppear {
            guard isCompleted, completedPuzzle == nil else { return }
            completedPuzzle = try? PuzzleLoader().loadPuzzle(id: entry.id, category: entry.category)
        }
    }

    @ViewBuilder
    private var thumbnail: some View {
        if isCompleted, let completedPuzzle {
            PuzzleThumbnailView(puzzle: completedPuzzle)
        } else if isUnlocked {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color("BackgroundPrimary"))
                .overlay(
                    Image(systemName: "questionmark.square.dashed")
                        .font(.system(size: 26))
                        .foregroundColor(.secondary)
                )
        } else {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.black.opacity(0.35))
        }
    }

    private var sizeLabel: String { "\(entry.width)×\(entry.height)" }
}

private struct DifficultyBadge: View {
    let difficulty: PuzzleDifficulty
    @EnvironmentObject private var appViewModel: AppViewModel

    private var tint: Color {
        switch difficulty {
        case .easy: return .green
        case .medium: return .blue
        case .hard: return .orange
        case .expert: return .red
        }
    }

    var body: some View {
        Text(difficulty.displayName.localized(for: appViewModel.localization.languageCode))
            .font(.caption2.bold())
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(tint.opacity(0.18))
            .foregroundColor(tint)
            .clipShape(Capsule())
    }
}

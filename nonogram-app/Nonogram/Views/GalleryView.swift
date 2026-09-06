import SwiftUI

/// The "collection album": every level across every category, grouped by category. Completed
/// puzzles show their solved image and can be reopened read-only (enlarged); everything else
/// is a silhouette placeholder, keeping unsolved answers hidden.
struct GalleryView: View {
    @EnvironmentObject private var appViewModel: AppViewModel
    @StateObject private var viewModel = GalleryViewModel()
    @State private var selectedItem: GalleryViewModel.Item?

    private let columns = [GridItem(.adaptive(minimum: 100), spacing: 12)]

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 20) {
                    ForEach(PuzzleCategory.allCases) { category in
                        let items = viewModel.itemsByCategory[category] ?? []
                        if !items.isEmpty {
                            Text(category.displayName.localized(for: appViewModel.localization.languageCode))
                                .font(.title3.bold())
                                .padding(.horizontal)

                            LazyVGrid(columns: columns, spacing: 12) {
                                ForEach(items) { item in
                                    GalleryTile(item: item)
                                        .onTapGesture {
                                            if item.isCompleted { selectedItem = item }
                                        }
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                }
                .padding(.vertical)
            }
            .background(Color("BackgroundPrimary"))
            .navigationTitle(appViewModel.localization.string("tab.gallery"))
            .sheet(item: $selectedItem) { item in
                if let puzzle = item.puzzle {
                    GalleryDetailView(puzzle: puzzle)
                }
            }
            .onAppear {
                let entries = PuzzleCategory.allCases.reduce(into: [PuzzleCategory: [LevelIndexEntry]]()) {
                    $0[$1] = appViewModel.levels(in: $1)
                }
                viewModel.load(
                    entriesByCategory: entries,
                    completedLevelIDs: appViewModel.progress.completedLevelIDs,
                    flawlessLevelIDs: appViewModel.progress.flawlessLevelIDs
                )
            }
        }
    }
}

private struct GalleryTile: View {
    let item: GalleryViewModel.Item

    var body: some View {
        Group {
            if item.isCompleted, let puzzle = item.puzzle {
                PuzzleThumbnailView(puzzle: puzzle)
            } else {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color("BackgroundSecondary"))
                    .overlay(Image(systemName: "photo.fill").foregroundColor(.secondary))
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .overlay(alignment: .bottomTrailing) {
            if item.isFlawless {
                Image(systemName: "star.fill")
                    .font(.caption2)
                    .foregroundColor(.yellow)
                    .padding(4)
            }
        }
    }
}

private struct GalleryDetailView: View {
    let puzzle: Puzzle
    @EnvironmentObject private var appViewModel: AppViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack {
                PuzzleThumbnailView(puzzle: puzzle)
                    .padding()
                Text(puzzle.title.localized(for: appViewModel.localization.languageCode))
                    .font(.title2.bold())
                Spacer()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(appViewModel.localization.string("common.done")) { dismiss() }
                }
            }
        }
    }
}

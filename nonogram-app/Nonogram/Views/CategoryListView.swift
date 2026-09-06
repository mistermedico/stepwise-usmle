import SwiftUI

/// Root of the "Play" tab: one tile per `PuzzleCategory`, showing completion progress and
/// leading into that category's level-select grid.
struct CategoryListView: View {
    @EnvironmentObject private var appViewModel: AppViewModel

    private let columns = [GridItem(.adaptive(minimum: 150), spacing: 16)]

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(PuzzleCategory.allCases) { category in
                        NavigationLink(value: category) {
                            CategoryTile(
                                category: category,
                                completed: appViewModel.completedCount(in: category),
                                total: appViewModel.totalCount(in: category)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding()
            }
            .background(Color("BackgroundPrimary"))
            .navigationTitle(appViewModel.localization.string("tab.play"))
            .navigationDestination(for: PuzzleCategory.self) { category in
                LevelSelectView(viewModel: LevelListViewModel(category: category, appViewModel: appViewModel))
            }
        }
    }
}

private struct CategoryTile: View {
    let category: PuzzleCategory
    let completed: Int
    let total: Int
    @EnvironmentObject private var appViewModel: AppViewModel

    private var icon: String {
        switch category {
        case .animals: return "pawprint.fill"
        case .food: return "fork.knife"
        case .nature: return "leaf.fill"
        case .objects: return "cube.fill"
        }
    }

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 32))
                .foregroundColor(.white)
                .frame(width: 64, height: 64)
                .background(Circle().fill(Color.accentColor))

            Text(category.displayName.localized(for: appViewModel.localization.languageCode))
                .font(.headline)
                .foregroundColor(Color("TextPrimary"))

            Text("\(completed)/\(total)")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(Color("BackgroundSecondary"))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

import SwiftUI

/// The main play surface: abstract region tiles connected by thin edge lines, per
/// spec section 4's "flat design, geometric puzzle-shape regions" direction.
struct WorldMapView: View {
    let scenario: WorldScenario
    let regionStates: [RegionID: RegionState]
    let lockdownWarnings: Set<RegionID>

    var body: some View {
        GeometryReader { geo in
            ZStack {
                edges(in: geo.size)
                ForEach(scenario.regions) { region in
                    RegionNodeView(
                        region: region,
                        regionState: regionStates[region.id] ?? .clean,
                        isLockdownImminent: lockdownWarnings.contains(region.id)
                    )
                    .position(RegionLayout.position(for: region.id, in: geo.size))
                }
            }
        }
        .accessibilityElement(children: .contain)
    }

    private func edges(in size: CGSize) -> some View {
        Canvas { context, _ in
            var drawn: Set<String> = []
            for region in scenario.regions {
                let start = RegionLayout.position(for: region.id, in: size)
                for neighborID in region.neighborIDs {
                    let key = [region.id, neighborID].sorted().joined(separator: "-")
                    guard !drawn.contains(key) else { continue }
                    drawn.insert(key)
                    let end = RegionLayout.position(for: neighborID, in: size)
                    var path = Path()
                    path.move(to: start)
                    path.addLine(to: end)
                    context.stroke(path, with: .color(AppColor.divider), lineWidth: 1.5)
                }
            }
        }
    }
}

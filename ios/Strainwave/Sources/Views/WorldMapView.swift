import SwiftUI
import Foundation
import OutbreakEngine

/// The abstract board: twelve geometric pieces, no coastline anywhere.
///
/// Rendering is split in two on purpose. The `Canvas` draws everything visual —
/// pieces, the growing blot, the scatter pattern, restriction stripes. A layer
/// of transparent shapes sits on top purely to carry hit-testing and
/// VoiceOver labels, so the drawing stays fast and the accessibility tree stays
/// meaningful.
struct WorldMapView: View {

    let regions: [RegionID: RegionState]
    let warningRegions: Set<RegionID>
    let bubbles: [PointBubble]
    var selectedRegion: RegionID?
    var onSelectRegion: (RegionID) -> Void = { _ in }
    var onCollect: (PointBubble) -> Void = { _ in }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var isAnimated: Bool {
        !reduceMotion && !Settings.prefersReducedMotion
    }

    var body: some View {
        GeometryReader { proxy in
            let rect = CGRect(origin: .zero, size: proxy.size)

            ZStack {
                TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: !isAnimated)) { timeline in
                    Canvas { context, size in
                        draw(
                            into: &context,
                            size: size,
                            time: timeline.date.timeIntervalSinceReferenceDate
                        )
                    }
                }

                interactionLayer(in: rect)
                bubbleLayer(in: rect)
            }
        }
        .aspectRatio(1.04, contentMode: .fit)
        .accessibilityElement(children: .contain)
    }

    // MARK: Drawing

    private func draw(into context: inout GraphicsContext, size: CGSize, time: TimeInterval) {
        // One shared breath so every infected territory pulses in step.
        let breath = isAnimated ? 1 + 0.035 * sin(time * 1.9) : 1
        let flash = isAnimated ? 0.45 + 0.55 * abs(sin(time * 2.6)) : 1

        for blueprint in RegionCatalog.all {
            let state = regions[blueprint.id]
            let path = shapePath(for: blueprint, in: size)

            // Base fill: an untouched territory.
            context.fill(path, with: .color(Theme.Palette.healthy))

            if let state, state.isInfected {
                drawInfection(state, blueprint: blueprint, path: path, breath: breath, into: &context, size: size)
            }

            if state?.transportLocked == true {
                drawRestrictionStripes(path: path, size: size, into: &context)
            }

            // Outline. Amber and flashing when restrictions are imminent.
            if warningRegions.contains(blueprint.id) {
                context.stroke(
                    path,
                    with: .color(Theme.Palette.warning.opacity(flash)),
                    lineWidth: 2.6
                )
            } else if blueprint.id == selectedRegion {
                context.stroke(path, with: .color(Theme.Palette.textPrimary), lineWidth: 2.2)
            } else {
                context.stroke(path, with: .color(Theme.Palette.outline), lineWidth: 1.2)
            }
        }
    }

    /// The blot: a soft disc growing out of the territory's centre, plus a
    /// scatter of fine points that reads as spread at a microscopic scale.
    private func drawInfection(
        _ state: RegionState,
        blueprint: RegionBlueprint,
        path: Path,
        breath: Double,
        into context: inout GraphicsContext,
        size: CGSize
    ) {
        let bounds = path.boundingRect
        let center = CGPoint(
            x: blueprint.mapCenter.x * size.width,
            y: blueprint.mapCenter.y * size.height
        )
        let maximumRadius = max(bounds.width, bounds.height) * 0.95
        // Square-rooted so early spread is visible immediately and the last
        // stretch slows down — the growth reads as gradual, never binary.
        let radius = maximumRadius * sqrt(min(1, state.touchedFraction)) * breath

        context.drawLayer { layer in
            layer.clip(to: path)

            let blot = Path(ellipseIn: CGRect(
                x: center.x - radius, y: center.y - radius,
                width: radius * 2, height: radius * 2
            ))
            layer.fill(blot, with: .color(Theme.Palette.spread.opacity(0.88)))

            // Softer outer ring, so the edge is a gradient rather than a cut.
            let halo = Path(ellipseIn: CGRect(
                x: center.x - radius * 1.3, y: center.y - radius * 1.3,
                width: radius * 2.6, height: radius * 2.6
            ))
            layer.fill(halo, with: .color(Theme.Palette.spread.opacity(0.22)))

            drawScatter(
                in: bounds, center: center, radius: radius * 1.45,
                seed: blueprint.id.rawValue, into: &layer
            )
        }
    }

    /// Deterministic speckle. Seeded by the territory id so the pattern is
    /// stable between frames instead of shimmering.
    private func drawScatter(
        in bounds: CGRect,
        center: CGPoint,
        radius: Double,
        seed: String,
        into context: inout GraphicsContext
    ) {
        var generator = SeededGenerator(seed: SeededGenerator.seed(from: seed))
        for _ in 0..<26 {
            let x = bounds.minX + generator.unit() * bounds.width
            let y = bounds.minY + generator.unit() * bounds.height
            let distance = hypot(x - center.x, y - center.y)
            guard distance < radius else { continue }
            let dotSize = 1.4 + generator.unit() * 1.8
            let dot = Path(ellipseIn: CGRect(x: x, y: y, width: dotSize, height: dotSize))
            context.fill(dot, with: .color(Theme.Palette.spreadGlow.opacity(0.55)))
        }
    }

    /// Suspended transport reads as a fine cyan hatch laid over the piece.
    private func drawRestrictionStripes(path: Path, size: CGSize, into context: inout GraphicsContext) {
        let bounds = path.boundingRect
        context.drawLayer { layer in
            layer.clip(to: path)
            var stripes = Path()
            let spacing: CGFloat = 7
            var offset = bounds.minX - bounds.height
            while offset < bounds.maxX {
                stripes.move(to: CGPoint(x: offset, y: bounds.maxY))
                stripes.addLine(to: CGPoint(x: offset + bounds.height, y: bounds.minY))
                offset += spacing
            }
            layer.stroke(stripes, with: .color(Theme.Palette.response.opacity(0.45)), lineWidth: 1.4)
        }
    }

    private func shapePath(for blueprint: RegionBlueprint, in size: CGSize) -> Path {
        var path = Path()
        guard let first = blueprint.mapShape.first else { return path }
        path.move(to: CGPoint(x: first.x * size.width, y: first.y * size.height))
        for point in blueprint.mapShape.dropFirst() {
            path.addLine(to: CGPoint(x: point.x * size.width, y: point.y * size.height))
        }
        path.closeSubpath()
        return path
    }

    // MARK: Interaction and accessibility

    private func interactionLayer(in rect: CGRect) -> some View {
        ZStack {
            ForEach(RegionCatalog.all, id: \.id) { blueprint in
                RegionShape(points: blueprint.mapShape)
                    .fill(Color.clear)
                    .contentShape(RegionShape(points: blueprint.mapShape))
                    .onTapGesture { onSelectRegion(blueprint.id) }
                    .accessibilityElement()
                    .accessibilityAddTraits(.isButton)
                    .accessibilityIdentifier(A11y.Game.region(blueprint.id.rawValue))
                    .accessibilityLabel(Text(L.region(blueprint.id)))
                    .accessibilityValue(Text(accessibilityValue(for: blueprint.id)))
            }
        }
        .frame(width: rect.width, height: rect.height)
    }

    private func accessibilityValue(for id: RegionID) -> String {
        guard let state = regions[id] else { return L.string("map.healthy") }
        var parts: [String] = []
        if state.isInfected {
            parts.append(Figures.percent(state.touchedFraction))
        } else {
            parts.append(L.string("map.healthy"))
        }
        if state.bordersClosed {
            parts.append(L.string("map.bordersClosed"))
        } else if state.transportLocked {
            parts.append(L.string("map.locked"))
        }
        if warningRegions.contains(id) {
            parts.append(L.string("map.warning"))
        }
        return parts.joined(separator: ", ")
    }

    /// Collectable clusters, positioned inside their territory.
    private func bubbleLayer(in rect: CGRect) -> some View {
        ZStack {
            ForEach(bubbles) { bubble in
                let blueprint = RegionCatalog.blueprint(bubble.region)
                let bounds = RegionShape(points: blueprint.mapShape).path(in: rect).boundingRect
                BubbleView(value: bubble.value) { onCollect(bubble) }
                    .position(
                        x: bounds.minX + bounds.width * bubble.offset.x,
                        y: bounds.minY + bounds.height * bubble.offset.y
                    )
            }
        }
        .frame(width: rect.width, height: rect.height)
    }
}

/// One territory's outline as a `Shape`, so it can be filled, hit-tested and
/// used as a clip without going through `Canvas`.
struct RegionShape: Shape {
    let points: [MapPoint]

    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard let first = points.first else { return path }
        path.move(to: CGPoint(x: rect.minX + first.x * rect.width, y: rect.minY + first.y * rect.height))
        for point in points.dropFirst() {
            path.addLine(to: CGPoint(
                x: rect.minX + point.x * rect.width,
                y: rect.minY + point.y * rect.height
            ))
        }
        path.closeSubpath()
        return path
    }
}

/// A tappable evolution cluster.
private struct BubbleView: View {
    let value: Int
    let action: () -> Void

    @State private var appeared = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(Theme.Palette.spreadGlow)
                    .shadow(color: Theme.Palette.spread.opacity(0.5), radius: 6)
                Text("+\(value)")
                    .font(Theme.Typography.figure(12, weight: .bold))
                    .foregroundStyle(.white)
            }
            .frame(width: 34, height: 34)
            // Padding lifts the tap target to the accessible minimum without
            // drawing a bigger dot.
            .padding(5)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .scaleEffect(appeared ? 1 : 0.4)
        .opacity(appeared ? 1 : 0)
        .onAppear {
            let animation = reduceMotion ? Theme.Motion.quick : Theme.Motion.unlockPulse
            withAnimation(animation) { appeared = true }
        }
        .accessibilityLabel(Text(L.format("tree.watchForPoints", value)))
    }
}

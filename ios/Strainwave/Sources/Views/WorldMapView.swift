import SwiftUI
import Foundation
import OutbreakEngine

/// The abstract board: twelve geometric pieces, no coastline anywhere.
///
/// Each territory is one full-size layer clipped to its own outline, so the
/// growing blot, the restriction hatch and the speckle can all be ordinary
/// SwiftUI shapes. That buys three things a `Canvas` could not:
///
/// - The blot animates by itself. Its size is bound to the territory's
///   saturation, so a day's spread eases into place instead of jumping.
/// - Nothing redraws unless the board actually changed. An earlier version
///   drove the pulse from `TimelineView(.animation)`, which repaints thirty
///   times a second forever — a flat battery cost, and an app that never goes
///   idle.
/// - The warning flash is bounded. It pulses a few times to catch the eye and
///   then holds, rather than blinking for the rest of the run.
struct WorldMapView: View {

    let regions: [RegionID: RegionState]
    let warningRegions: Set<RegionID>
    let bubbles: [PointBubble]
    var selectedRegion: RegionID?
    var onSelectRegion: (RegionID) -> Void = { _ in }
    var onCollect: (PointBubble) -> Void = { _ in }

    @State private var flash = 1.0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var isAnimated: Bool {
        !reduceMotion && !Settings.prefersReducedMotion
    }

    var body: some View {
        GeometryReader { proxy in
            let rect = CGRect(origin: .zero, size: proxy.size)

            ZStack {
                ForEach(RegionCatalog.all, id: \.id) { blueprint in
                    territory(blueprint, in: rect)
                }
                bubbleLayer(in: rect)
            }
            .frame(width: rect.width, height: rect.height)
        }
        .aspectRatio(1.04, contentMode: .fit)
        .onChange(of: warningRegions) { updated in
            guard isAnimated, !updated.isEmpty else {
                flash = 1
                return
            }
            // Six beats, then it settles into a solid amber outline.
            flash = 1
            withAnimation(.easeInOut(duration: 0.45).repeatCount(6, autoreverses: true)) {
                flash = 0.35
            }
        }
        .accessibilityElement(children: .contain)
    }

    // MARK: One territory

    private func territory(_ blueprint: RegionBlueprint, in rect: CGRect) -> some View {
        let shape = RegionShape(points: blueprint.mapShape)
        let state = regions[blueprint.id]
        let saturation = state?.touchedFraction ?? 0
        let bounds = shape.path(in: rect).boundingRect
        let center = CGPoint(
            x: blueprint.mapCenter.x * rect.width,
            y: blueprint.mapCenter.y * rect.height
        )
        // Square-rooted so early spread shows immediately and the last stretch
        // slows down: growth reads as gradual, never binary.
        let diameter = max(bounds.width, bounds.height) * 1.9 * sqrt(min(1, saturation))

        return ZStack {
            Theme.Palette.healthy

            if saturation > 0 {
                Circle()
                    .fill(Theme.Palette.spread.opacity(0.22))
                    .frame(width: diameter * 1.3, height: diameter * 1.3)
                    .position(center)
                Circle()
                    .fill(Theme.Palette.spread.opacity(0.88))
                    .frame(width: diameter, height: diameter)
                    .position(center)
                SpeckleShape(seed: blueprint.id.rawValue, center: center, radius: diameter * 0.72)
                    .fill(Theme.Palette.spreadGlow.opacity(0.55))
            }

            if state?.transportLocked == true {
                DiagonalStripes()
                    .stroke(Theme.Palette.response.opacity(0.45), lineWidth: 1.4)
            }
        }
        .animation(isAnimated ? .easeInOut(duration: 0.7) : nil, value: saturation)
        .clipShape(shape)
        .overlay(outline(for: blueprint.id, shape: shape))
        .contentShape(shape)
        .onTapGesture { onSelectRegion(blueprint.id) }
        .accessibilityElement()
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier(A11y.Game.region(blueprint.id.rawValue))
        .accessibilityLabel(Text(L.region(blueprint.id)))
        .accessibilityValue(Text(accessibilityValue(for: blueprint.id)))
    }

    @ViewBuilder
    private func outline(for id: RegionID, shape: RegionShape) -> some View {
        if warningRegions.contains(id) {
            shape.stroke(Theme.Palette.warning, lineWidth: 2.6).opacity(flash)
        } else if id == selectedRegion {
            shape.stroke(Theme.Palette.textPrimary, lineWidth: 2.2)
        } else {
            shape.stroke(Theme.Palette.outline, lineWidth: 1.2)
        }
    }

    private func accessibilityValue(for id: RegionID) -> String {
        guard let state = regions[id] else { return L.string("map.healthy") }
        var parts: [String] = []
        parts.append(state.isInfected ? Figures.percent(state.touchedFraction) : L.string("map.healthy"))
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

/// One territory's outline, in normalised map space.
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

/// Suspended transport, drawn as a fine hatch across the piece.
private struct DiagonalStripes: Shape {
    var spacing: CGFloat = 7

    func path(in rect: CGRect) -> Path {
        var path = Path()
        var offset = rect.minX - rect.height
        while offset < rect.maxX {
            path.move(to: CGPoint(x: offset, y: rect.maxY))
            path.addLine(to: CGPoint(x: offset + rect.height, y: rect.minY))
            offset += spacing
        }
        return path
    }
}

/// A deterministic speckle that reads as spread at a microscopic scale.
///
/// Seeded by the territory's own name, so the pattern is identical on every
/// redraw and every device instead of shimmering.
private struct SpeckleShape: Shape {
    let seed: String
    let center: CGPoint
    let radius: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard radius > 0 else { return path }
        var generator = SeededGenerator(seed: SeededGenerator.seed(from: seed))
        for _ in 0..<26 {
            let x = rect.minX + generator.unit() * rect.width
            let y = rect.minY + generator.unit() * rect.height
            guard hypot(x - center.x, y - center.y) < radius else { continue }
            let size = 1.4 + generator.unit() * 1.8
            path.addEllipse(in: CGRect(x: x, y: y, width: size, height: size))
        }
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
                    .font(Theme.Typography.figure(.caption, weight: .bold))
                    .monospacedDigit()
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

import SwiftUI
import Foundation
import OutbreakEngine

/// The strain itself, drawn as a geometric core with arms that accumulate as it
/// evolves (section 4).
///
/// Each branch grows a visually distinct arm inside its own 120° sector, so a
/// glance at the glyph tells you how the run was played: spiky and wide means a
/// transmission build, lobed means resilience, forked means symptoms.
///
/// Every coordinate here is `CGFloat`. Mixing `Double` and `CGFloat` in the same
/// trigonometric expression makes `cos`/`sin` ambiguous and pushes the type
/// checker past its budget, so the types are written out rather than inferred.
struct PathogenGlyph: View {

    let unlockedTraits: Set<TraitID>
    /// Innate arms the chosen sample starts with, so no strain looks bare.
    var innateArms: Int = 3
    var isPulsing: Bool = true
    var coreColor: Color = Theme.Palette.spread
    var glowColor: Color = Theme.Palette.spreadGlow

    @State private var pulse = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var branchCounts: [TraitCategory: Int] {
        var result: [TraitCategory: Int] = [:]
        for id in unlockedTraits {
            result[TraitCatalog.trait(id).category, default: 0] += 1
        }
        return result
    }

    var body: some View {
        Canvas { context, size in
            draw(into: &context, size: size)
        }
        .scaleEffect(pulse ? 1.045 : 0.985)
        .onAppear(perform: startPulsing)
        .accessibilityElement()
        .accessibilityLabel(Text(L.string("app.name")))
        .accessibilityValue(Text(accessibilitySummary))
    }

    private func startPulsing() {
        guard isPulsing, !reduceMotion, !Settings.prefersReducedMotion else { return }
        withAnimation(Theme.Motion.pulse) { pulse = true }
    }

    private var accessibilitySummary: String {
        let counts = branchCounts
        return TraitCategory.allCases
            .map { "\(L.category($0)): \(counts[$0] ?? 0)" }
            .joined(separator: ", ")
    }

    // MARK: Drawing

    private func draw(into context: inout GraphicsContext, size: CGSize) {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let radius: CGFloat = min(size.width, size.height) * 0.24
        let counts = branchCounts
        let branchCount = TraitCategory.allCases.count

        // Arms first, so the core sits on top of where they attach.
        for (index, category) in TraitCategory.allCases.enumerated() {
            let arms = (counts[category] ?? 0) + innateArms / branchCount
            drawArms(
                count: arms, category: category, sectorIndex: index,
                center: center, radius: radius, into: &context
            )
        }

        drawHalo(center: center, radius: radius, into: &context)
        drawCore(center: center, radius: radius, into: &context)
    }

    private func drawHalo(center: CGPoint, radius: CGFloat, into context: inout GraphicsContext) {
        let extent = radius * 1.55
        let halo = Path(ellipseIn: CGRect(
            x: center.x - extent, y: center.y - extent,
            width: extent * 2, height: extent * 2
        ))
        context.fill(halo, with: .color(glowColor.opacity(0.12)))
    }

    private func drawCore(center: CGPoint, radius: CGFloat, into context: inout GraphicsContext) {
        context.fill(hexagon(center: center, radius: radius), with: .color(coreColor))
        // Inner facet, for a little depth without a gradient.
        context.fill(
            hexagon(center: center, radius: radius * 0.52),
            with: .color(glowColor.opacity(0.55))
        )
    }

    private func hexagon(center: CGPoint, radius: CGFloat) -> Path {
        var path = Path()
        for step in 0..<6 {
            let angle: CGFloat = CGFloat(step) / 6 * 2 * .pi - .pi / 2
            let point = offset(from: center, angle: angle, distance: radius)
            if step == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }
        path.closeSubpath()
        return path
    }

    /// Draws one branch's arms inside its own sector.
    private func drawArms(
        count: Int,
        category: TraitCategory,
        sectorIndex: Int,
        center: CGPoint,
        radius: CGFloat,
        into context: inout GraphicsContext
    ) {
        guard count > 0 else { return }
        let capped = min(count, 10)
        let branchCount = CGFloat(TraitCategory.allCases.count)
        let sectorSpan: CGFloat = 2 * .pi / branchCount
        let sectorStart: CGFloat = CGFloat(sectorIndex) * sectorSpan - .pi / 2
        let tint = Theme.Palette.branch(category.style)

        for index in 0..<capped {
            let progress: CGFloat = capped == 1 ? 0.5 : CGFloat(index) / CGFloat(capped - 1)
            // Inset from the sector edges so neighbouring branches stay distinct.
            let angle: CGFloat = sectorStart + sectorSpan * (0.14 + progress * 0.72)
            let length: CGFloat = radius * (1.05 + CGFloat(index % 3) * 0.14)

            let inner = offset(from: center, angle: angle, distance: radius * 0.92)
            let outer = offset(from: center, angle: angle, distance: radius + length)

            var stem = Path()
            stem.move(to: inner)
            stem.addLine(to: outer)
            context.stroke(stem, with: .color(tint), style: StrokeStyle(lineWidth: 2.4, lineCap: .round))

            switch category {
            case .transmission:
                drawSpike(
                    center: center, angle: angle, radius: radius, length: length,
                    tint: tint, into: &context
                )
            case .resilience:
                drawLobe(at: outer, radius: radius, tint: tint, into: &context)
            case .symptoms:
                drawFork(
                    center: center, angle: angle, radius: radius, length: length,
                    from: outer, tint: tint, into: &context
                )
            }
        }
    }

    /// A narrow spike: a small triangle at the tip.
    private func drawSpike(
        center: CGPoint,
        angle: CGFloat,
        radius: CGFloat,
        length: CGFloat,
        tint: Color,
        into context: inout GraphicsContext
    ) {
        let span: CGFloat = 0.16
        var tip = Path()
        tip.move(to: offset(from: center, angle: angle, distance: radius + length * 1.24))
        tip.addLine(to: offset(from: center, angle: angle - span, distance: radius + length * 0.9))
        tip.addLine(to: offset(from: center, angle: angle + span, distance: radius + length * 0.9))
        tip.closeSubpath()
        context.fill(tip, with: .color(tint))
    }

    /// A rounded lobe: a shielded, blunt ending.
    private func drawLobe(
        at point: CGPoint,
        radius: CGFloat,
        tint: Color,
        into context: inout GraphicsContext
    ) {
        let size: CGFloat = radius * 0.30
        let lobe = Path(ellipseIn: CGRect(
            x: point.x - size / 2, y: point.y - size / 2, width: size, height: size
        ))
        context.fill(lobe, with: .color(tint))
        context.stroke(lobe, with: .color(tint.opacity(0.35)), lineWidth: 4)
    }

    /// A fork: two short prongs off the tip.
    private func drawFork(
        center: CGPoint,
        angle: CGFloat,
        radius: CGFloat,
        length: CGFloat,
        from origin: CGPoint,
        tint: Color,
        into context: inout GraphicsContext
    ) {
        let span: CGFloat = 0.28
        let reach: CGFloat = radius + length * 1.28
        for direction in [CGFloat(-1), CGFloat(1)] {
            var prong = Path()
            prong.move(to: origin)
            prong.addLine(to: offset(from: center, angle: angle + span * direction, distance: reach))
            context.stroke(prong, with: .color(tint), style: StrokeStyle(lineWidth: 2, lineCap: .round))
        }
    }

    /// Polar-to-Cartesian, in one place so no call site has to mix numeric types.
    private func offset(from center: CGPoint, angle: CGFloat, distance: CGFloat) -> CGPoint {
        CGPoint(
            x: center.x + cos(angle) * distance,
            y: center.y + sin(angle) * distance
        )
    }
}

extension TraitCategory {
    /// Styling counterpart, so the palette does not need to import the engine.
    var style: TraitBranchStyle {
        switch self {
        case .transmission: return .transmission
        case .resilience: return .resilience
        case .symptoms: return .symptoms
        }
    }
}

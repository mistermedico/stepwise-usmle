import SwiftUI
import Foundation
import OutbreakEngine

/// The strain itself, drawn as a geometric core with arms that accumulate as it
/// evolves (section 4).
///
/// Each branch grows a visually distinct arm inside its own 120° sector, so a
/// glance at the glyph tells you how the run was played: spiky and wide means a
/// transmission build, lobed means resilience, forked means symptoms.
struct PathogenGlyph: View {

    let unlockedTraits: Set<TraitID>
    /// Innate arms the chosen sample starts with, so no strain looks bare.
    var innateArms: Int = 3
    var isPulsing: Bool = true
    var coreColor: Color = Theme.Palette.spread
    var glowColor: Color = Theme.Palette.spreadGlow

    @State private var pulse = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var counts: [TraitCategory: Int] {
        var result: [TraitCategory: Int] = [:]
        for id in unlockedTraits {
            let category = TraitCatalog.trait(id).category
            result[category, default: 0] += 1
        }
        return result
    }

    var body: some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let radius = min(size.width, size.height) * 0.24
            let branchCounts = counts

            // Arms first, so the core sits on top of where they attach.
            for category in TraitCategory.allCases {
                let count = (branchCounts[category] ?? 0) + innateArms / TraitCategory.allCases.count
                draw(
                    arms: count,
                    category: category,
                    center: center,
                    radius: radius,
                    into: &context
                )
            }

            // Soft halo.
            let halo = Path(ellipseIn: CGRect(
                x: center.x - radius * 1.55, y: center.y - radius * 1.55,
                width: radius * 3.1, height: radius * 3.1
            ))
            context.fill(halo, with: .color(glowColor.opacity(0.12)))

            // Hexagonal core.
            var core = Path()
            for step in 0..<6 {
                let angle = Double(step) / 6 * 2 * .pi - .pi / 2
                let point = CGPoint(
                    x: center.x + cos(angle) * radius,
                    y: center.y + sin(angle) * radius
                )
                if step == 0 { core.move(to: point) } else { core.addLine(to: point) }
            }
            core.closeSubpath()
            context.fill(core, with: .color(coreColor))

            // Inner facet, for a little depth without a gradient.
            var facet = Path()
            for step in 0..<6 {
                let angle = Double(step) / 6 * 2 * .pi - .pi / 2
                let point = CGPoint(
                    x: center.x + cos(angle) * radius * 0.52,
                    y: center.y + sin(angle) * radius * 0.52
                )
                if step == 0 { facet.move(to: point) } else { facet.addLine(to: point) }
            }
            facet.closeSubpath()
            context.fill(facet, with: .color(glowColor.opacity(0.55)))
        }
        .scaleEffect(pulse ? 1.045 : 0.985)
        .onAppear {
            guard isPulsing, !reduceMotion, !Settings.prefersReducedMotion else { return }
            withAnimation(Theme.Motion.pulse) { pulse = true }
        }
        .accessibilityElement()
        .accessibilityLabel(Text(L.string("app.name")))
        .accessibilityValue(Text(accessibilitySummary))
    }

    private var accessibilitySummary: String {
        TraitCategory.allCases
            .map { "\(L.category($0)): \(counts[$0] ?? 0)" }
            .joined(separator: ", ")
    }

    /// Draws one branch's arms inside its own sector.
    private func draw(
        arms: Int,
        category: TraitCategory,
        center: CGPoint,
        radius: CGFloat,
        into context: inout GraphicsContext
    ) {
        guard arms > 0 else { return }
        let capped = min(arms, 10)
        let sectorIndex = TraitCategory.allCases.firstIndex(of: category) ?? 0
        let sectorStart = Double(sectorIndex) / Double(TraitCategory.allCases.count) * 2 * .pi - .pi / 2
        let sectorSpan = 2 * .pi / Double(TraitCategory.allCases.count)
        let tint = Theme.Palette.branch(category.style)

        for index in 0..<capped {
            let progress = capped == 1 ? 0.5 : Double(index) / Double(capped - 1)
            // Inset from the sector edges so neighbouring branches stay distinct.
            let angle = sectorStart + sectorSpan * (0.14 + progress * 0.72)
            let inner = CGPoint(
                x: center.x + cos(angle) * radius * 0.92,
                y: center.y + sin(angle) * radius * 0.92
            )
            let length = radius * (1.05 + Double(index % 3) * 0.14)
            let outer = CGPoint(
                x: center.x + cos(angle) * (radius + length),
                y: center.y + sin(angle) * (radius + length)
            )

            var stem = Path()
            stem.move(to: inner)
            stem.addLine(to: outer)
            context.stroke(stem, with: .color(tint), style: StrokeStyle(lineWidth: 2.4, lineCap: .round))

            switch category {
            case .transmission:
                // A narrow spike: a small triangle at the tip.
                let tipSpan = 0.16
                var tip = Path()
                tip.move(to: CGPoint(
                    x: center.x + cos(angle) * (radius + length * 1.24),
                    y: center.y + sin(angle) * (radius + length * 1.24)
                ))
                tip.addLine(to: CGPoint(
                    x: center.x + cos(angle - tipSpan) * (radius + length * 0.9),
                    y: center.y + sin(angle - tipSpan) * (radius + length * 0.9)
                ))
                tip.addLine(to: CGPoint(
                    x: center.x + cos(angle + tipSpan) * (radius + length * 0.9),
                    y: center.y + sin(angle + tipSpan) * (radius + length * 0.9)
                ))
                tip.closeSubpath()
                context.fill(tip, with: .color(tint))

            case .resilience:
                // A rounded lobe: a shielded, blunt ending.
                let size = radius * 0.30
                let lobe = Path(ellipseIn: CGRect(
                    x: outer.x - size / 2, y: outer.y - size / 2, width: size, height: size
                ))
                context.fill(lobe, with: .color(tint))
                context.stroke(lobe, with: .color(tint.opacity(0.35)), lineWidth: 4)

            case .symptoms:
                // A fork: two short prongs off the tip.
                let forkSpan = 0.28
                for direction in [-1.0, 1.0] {
                    var prong = Path()
                    prong.move(to: outer)
                    prong.addLine(to: CGPoint(
                        x: center.x + cos(angle + forkSpan * direction) * (radius + length * 1.28),
                        y: center.y + sin(angle + forkSpan * direction) * (radius + length * 1.28)
                    ))
                    context.stroke(
                        prong, with: .color(tint),
                        style: StrokeStyle(lineWidth: 2.0, lineCap: .round)
                    )
                }
            }
        }
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

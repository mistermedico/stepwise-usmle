import SwiftUI

/// One region "tile": a rounded puzzle-piece shape whose fill grows from the center
/// outward as infection climbs, with a subtle scattered "microscopic spread" dot
/// pattern, a striped overlay while locked down, and an amber pre-lockdown blink
/// (spec section 4, map + animation notes).
struct RegionNodeView: View {
    let region: Region
    let regionState: RegionState
    let isLockdownImminent: Bool

    @State private var pulse = false

    private let tileSize: CGFloat = 64

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(AppColor.labSurface)

            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(
                    RadialGradient(
                        colors: [AppColor.contagionGlow, AppColor.contagion.opacity(0.35), .clear],
                        center: .center, startRadius: 1, endRadius: tileSize * 0.75 * CGFloat(regionState.infectionLevel)
                    )
                )
                .opacity(regionState.infectionLevel > 0 ? 1 : 0)

            if regionState.infectionLevel > 0.15 {
                SpreadDotsView(intensity: regionState.infectionLevel)
                    .opacity(0.6)
            }

            if regionState.isLockedDown {
                StripedOverlay()
                    .foregroundStyle(AppColor.response.opacity(0.35))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }

            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(
                    isLockdownImminent ? AppColor.warning : AppColor.divider,
                    lineWidth: isLockdownImminent ? 2.5 : 1
                )
                .opacity(isLockdownImminent && pulse ? 0.35 : 1)

            VStack(spacing: 2) {
                Text(LocalizedStringKey(region.nameKey))
                    .font(AppFont.body(10, weight: .semibold))
                    .foregroundStyle(AppColor.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                if regionState.infectionLevel > 0 {
                    Text("\(Int(regionState.infectionLevel * 100))%")
                        .font(AppFont.body(9, weight: .bold))
                        .foregroundStyle(AppColor.contagion)
                }
            }
            .padding(4)
        }
        .frame(width: tileSize, height: tileSize)
        .scaleEffect(regionState.infectionLevel > 0 ? 1 + CGFloat(regionState.infectionLevel) * 0.08 : 1)
        .animation(.easeInOut(duration: 0.6), value: regionState.infectionLevel)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(LocalizedStringKey(region.nameKey)))
        .accessibilityValue(accessibilityStatusText)
    }

    private var accessibilityStatusText: Text {
        if regionState.isLockedDown {
            return Text("region.status.lockdown")
        }
        return Text("region.infection.percent \(Int(regionState.infectionLevel * 100))")
    }
}

/// A handful of small scattered dots to suggest microscopic spread rather than a
/// single flat color fill.
private struct SpreadDotsView: View {
    let intensity: Double

    var body: some View {
        Canvas { context, size in
            var generator = SeededGenerator(seed: 42)
            let dotCount = Int(intensity * 14)
            for _ in 0..<dotCount {
                let x = Double.random(in: 0...Double(size.width), using: &generator)
                let y = Double.random(in: 0...Double(size.height), using: &generator)
                let radius = Double.random(in: 0.6...1.6, using: &generator)
                let rect = CGRect(x: CGFloat(x), y: CGFloat(y), width: CGFloat(radius * 2), height: CGFloat(radius * 2))
                context.fill(Path(ellipseIn: rect), with: .color(AppColor.contagion))
            }
        }
    }
}

/// Deterministic RNG so the dot pattern doesn't reshuffle on every SwiftUI re-render.
private struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed &+ 0x9E3779B97F4A7C15 }
    mutating func next() -> UInt64 {
        state ^= state << 13
        state ^= state >> 7
        state ^= state << 17
        return state
    }
}

private struct StripedOverlay: View {
    var body: some View {
        GeometryReader { geo in
            Path { path in
                let spacing: CGFloat = 6
                var x: CGFloat = -geo.size.height
                while x < geo.size.width {
                    path.move(to: CGPoint(x: x, y: geo.size.height))
                    path.addLine(to: CGPoint(x: x + geo.size.height, y: 0))
                    x += spacing
                }
            }
            .stroke(style: StrokeStyle(lineWidth: 2))
        }
    }
}

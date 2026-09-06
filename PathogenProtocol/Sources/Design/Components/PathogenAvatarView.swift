import SwiftUI

/// The pathogen's own portrait: a central hexagon that grows a distinct kind of "arm"
/// per upgrade category, so the shape visually narrates how this run was played
/// (spec section 4 — transmission = radiating lines, resistance = orbiting rings,
/// symptoms = outward spikes).
public struct PathogenAvatarView: View {
    let unlockedUpgradeIDs: Set<String>

    public init(unlockedUpgradeIDs: Set<String>) {
        self.unlockedUpgradeIDs = unlockedUpgradeIDs
    }

    private func tierCount(_ category: UpgradeCategory) -> Int {
        UpgradeCatalog.allNodes
            .filter { $0.category == category && unlockedUpgradeIDs.contains($0.id) }
            .count
    }

    public var body: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)
            ZStack {
                resistanceRings(size: size)
                transmissionArms(size: size)
                core(size: size)
                symptomSpikes(size: size)
            }
            .frame(width: size, height: size)
            .position(x: geo.size.width / 2, y: geo.size.height / 2)
        }
    }

    private func core(size: CGFloat) -> some View {
        Hexagon()
            .fill(
                RadialGradient(
                    colors: [AppColor.contagionGlow, AppColor.contagion],
                    center: .center, startRadius: 1, endRadius: size * 0.28
                )
            )
            .frame(width: size * 0.42, height: size * 0.42)
            .shadow(color: AppColor.contagion.opacity(0.5), radius: 12)
    }

    private func transmissionArms(size: CGFloat) -> some View {
        let count = tierCount(.transmission)
        return ForEach(0..<max(count, 0), id: \.self) { index in
            let angle = Angle.degrees(Double(index) / 4.0 * 360 - 90)
            Capsule()
                .fill(AppColor.contagion.opacity(0.85))
                .frame(width: size * 0.34, height: 4)
                .offset(x: size * 0.28)
                .rotationEffect(angle)
        }
    }

    private func resistanceRings(size: CGFloat) -> some View {
        let count = tierCount(.resistance)
        return ForEach(0..<max(count, 0), id: \.self) { index in
            Circle()
                .stroke(AppColor.response.opacity(0.7), style: StrokeStyle(lineWidth: 2, dash: [3, 5]))
                .frame(width: size * (0.5 + CGFloat(index) * 0.14), height: size * (0.5 + CGFloat(index) * 0.14))
        }
    }

    private func symptomSpikes(size: CGFloat) -> some View {
        let count = tierCount(.symptoms)
        return ForEach(0..<max(count, 0), id: \.self) { index in
            let angle = Angle.degrees(Double(index) / 4.0 * 360 - 45)
            Triangle()
                .fill(AppColor.warning.opacity(0.85))
                .frame(width: 10, height: size * 0.16)
                .offset(y: -size * 0.28)
                .rotationEffect(angle)
        }
    }
}

struct Hexagon: Shape {
    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        var path = Path()
        for i in 0..<6 {
            let angle = Angle.degrees(Double(i) / 6.0 * 360 - 90)
            let point = CGPoint(x: center.x + radius * cos(angle.radians), y: center.y + radius * sin(angle.radians))
            if i == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }
        path.closeSubpath()
        return path
    }
}

struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

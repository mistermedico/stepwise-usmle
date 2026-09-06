import SwiftUI
import Foundation
import OutbreakEngine

/// The ability map (section 4): a branching path of nodes joined by thin glowing
/// lines. Unlocking a node sends a pulse of light down the line that feeds it,
/// and only then does the node light up.
struct TraitTreeView: View {

    @ObservedObject var model: GameViewModel
    let onClose: () -> Void

    @State private var category: TraitCategory = .transmission
    @State private var selected: TraitID?
    @State private var pulse: PulseState?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// A travelling light on one edge of the map.
    private struct PulseState: Equatable {
        let from: MapPoint
        let to: MapPoint
        var progress: Double
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            branchPicker
            mapArea
            detailPanel
        }
        .background(Theme.Palette.background.ignoresSafeArea())
        .onChange(of: model.lastUnlockedTrait) { unlocked in
            guard let unlocked else { return }
            startPulse(to: unlocked)
        }
    }

    // MARK: Header

    private var header: some View {
        HStack {
            Text(L.string("tree.title"))
                .font(Theme.Typography.heading)
                .foregroundStyle(Theme.Palette.textPrimary)

            Spacer()

            HStack(spacing: 6) {
                Image(systemName: "hexagon.fill")
                    .foregroundStyle(Theme.Palette.spread)
                Text(Figures.integer(model.state.evolutionPoints))
                    .font(Theme.Typography.readoutSmall)
                    .monospacedDigit()
                    .foregroundStyle(Theme.Palette.textPrimary)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(Text(L.string("hud.points")))
            .accessibilityValue(Text(Figures.integer(model.state.evolutionPoints)))

            Button(action: onClose) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(Theme.Palette.textTertiary)
            }
            .frame(minWidth: Theme.Metrics.minimumTapTarget, minHeight: Theme.Metrics.minimumTapTarget)
            .accessibilityIdentifier(A11y.Tree.close)
            .accessibilityLabel(Text(L.string("common.close")))
        }
        .padding(.horizontal, Theme.Metrics.spacingWide)
        .padding(.top, Theme.Metrics.spacingWide)
    }

    private var branchPicker: some View {
        Picker("", selection: $category) {
            ForEach(TraitCategory.allCases, id: \.self) { category in
                Text(L.category(category)).tag(category)
            }
        }
        .pickerStyle(.segmented)
        .padding(Theme.Metrics.spacingWide)
        .accessibilityLabel(Text(L.string("tree.title")))
    }

    // MARK: Map

    private var mapArea: some View {
        GeometryReader { proxy in
            let inset: CGFloat = 34
            let canvas = CGSize(
                width: max(1, proxy.size.width - inset * 2),
                height: max(1, proxy.size.height - inset * 2)
            )

            ZStack {
                edges(in: canvas, inset: inset)
                pulseDot(in: canvas, inset: inset)
                nodes(in: canvas, inset: inset)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .frame(maxHeight: .infinity)
    }

    /// The connecting lines. Drawn lit when both ends are unlocked, dim otherwise.
    private func edges(in canvas: CGSize, inset: CGFloat) -> some View {
        Canvas { context, _ in
            for trait in TraitCatalog.traits(in: category) {
                for requirement in trait.prerequisites {
                    let parent = TraitCatalog.trait(requirement)
                    var line = Path()
                    line.move(to: point(parent.mapPosition, in: canvas, inset: inset))
                    line.addLine(to: point(trait.mapPosition, in: canvas, inset: inset))

                    let isLit = model.state.isUnlocked(trait.id)
                    let isReady = model.state.isAvailable(trait.id)
                    let colour = isLit
                        ? Theme.Palette.branch(category.style)
                        : Theme.Palette.outline
                    context.stroke(
                        line,
                        with: .color(colour.opacity(isLit ? 0.9 : isReady ? 0.55 : 0.3)),
                        style: StrokeStyle(lineWidth: isLit ? 2.4 : 1.4, lineCap: .round)
                    )
                }
            }
        }
        .accessibilityHidden(true)
    }

    private func nodes(in canvas: CGSize, inset: CGFloat) -> some View {
        ForEach(model.nodes(in: category)) { entry in
            TraitNodeView(
                trait: entry.trait,
                status: entry.status,
                isSelected: selected == entry.trait.id,
                tint: Theme.Palette.branch(category.style)
            ) {
                selected = entry.trait.id
            }
            .position(point(entry.trait.mapPosition, in: canvas, inset: inset))
        }
    }

    @ViewBuilder
    private func pulseDot(in canvas: CGSize, inset: CGFloat) -> some View {
        if let pulse {
            let from = point(pulse.from, in: canvas, inset: inset)
            let to = point(pulse.to, in: canvas, inset: inset)
            Circle()
                .fill(Theme.Palette.spreadGlow)
                .frame(width: 10, height: 10)
                .shadow(color: Theme.Palette.spreadGlow, radius: 6)
                .position(
                    x: from.x + (to.x - from.x) * pulse.progress,
                    y: from.y + (to.y - from.y) * pulse.progress
                )
                .allowsHitTesting(false)
        }
    }

    private func point(_ position: MapPoint, in canvas: CGSize, inset: CGFloat) -> CGPoint {
        CGPoint(
            x: inset + position.x * canvas.width,
            y: inset + position.y * canvas.height
        )
    }

    /// Sends the light down the edge that feeds a freshly unlocked node.
    private func startPulse(to id: TraitID) {
        let trait = TraitCatalog.trait(id)
        guard trait.category == category,
              let parent = trait.prerequisites.first,
              !reduceMotion,
              !Settings.prefersReducedMotion else { return }

        pulse = PulseState(
            from: TraitCatalog.trait(parent).mapPosition,
            to: trait.mapPosition,
            progress: 0
        )
        withAnimation(Theme.Motion.unlockPulse) {
            pulse?.progress = 1
        }
        // Clear once the light has arrived.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            self.pulse = nil
        }
    }

    // MARK: Detail

    @ViewBuilder
    private var detailPanel: some View {
        if let id = selected {
            let trait = TraitCatalog.trait(id)
            let isUnlocked = model.state.isUnlocked(id)
            let canUnlock = model.state.canUnlock(id)
            let isAvailable = model.state.isAvailable(id)

            Panel {
                VStack(alignment: .leading, spacing: Theme.Metrics.spacing) {
                    HStack {
                        Text(L.traitTitle(id))
                            .font(Theme.Typography.subheading)
                            .foregroundStyle(Theme.Palette.textPrimary)
                        Spacer()
                        if isUnlocked {
                            Chip(
                                text: L.string("tree.unlocked"),
                                systemImage: "checkmark",
                                tint: Theme.Palette.success
                            )
                        } else {
                            Chip(
                                text: L.format("tree.cost", trait.cost),
                                systemImage: "hexagon.fill",
                                tint: canUnlock ? Theme.Palette.spread : Theme.Palette.textTertiary
                            )
                        }
                    }

                    Text(L.traitDetail(id))
                        .font(Theme.Typography.callout)
                        .foregroundStyle(Theme.Palette.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)

                    if !isAvailable, !isUnlocked {
                        Text(L.prerequisites(trait.prerequisites))
                            .font(Theme.Typography.caption)
                            .foregroundStyle(Theme.Palette.warning)
                    } else if !canUnlock, !isUnlocked {
                        Text(L.string("tree.notEnough"))
                            .font(Theme.Typography.caption)
                            .foregroundStyle(Theme.Palette.warning)
                    }

                    actionRow(for: id, isUnlocked: isUnlocked, canUnlock: canUnlock)
                }
            }
            .padding(Theme.Metrics.spacingWide)
            .transition(.opacity.combined(with: .offset(y: 12)))
        } else {
            hintPanel
        }
    }

    @ViewBuilder
    private func actionRow(for id: TraitID, isUnlocked: Bool, canUnlock: Bool) -> some View {
        HStack(spacing: Theme.Metrics.spacing) {
            if isUnlocked {
                SecondaryButton(
                    title: L.format("tree.refund", TraitCatalog.trait(id).refund),
                    systemImage: "arrow.uturn.backward"
                ) {
                    model.fold(id)
                }
                .accessibilityIdentifier(A11y.Tree.fold)
                .disabled(!model.state.canFold(id))
                .opacity(model.state.canFold(id) ? 1 : 0.45)
            } else {
                PrimaryButton(
                    title: L.string("tree.unlock"),
                    systemImage: "bolt.fill",
                    isEnabled: canUnlock
                ) {
                    model.unlock(id)
                }
                .accessibilityIdentifier(A11y.Tree.unlock)
            }
        }
        if isUnlocked, !model.state.canFold(id) {
            Text(L.string("tree.foldBlocked"))
                .font(Theme.Typography.caption)
                .foregroundStyle(Theme.Palette.textTertiary)
        }
    }

    private var hintPanel: some View {
        Panel {
            VStack(spacing: Theme.Metrics.spacingTight) {
                Text(L.string("tree.bonusPoints"))
                    .font(Theme.Typography.callout)
                    .foregroundStyle(Theme.Palette.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                SecondaryButton(
                    title: L.format("tree.watchForPoints", AdPolicy.rewardedPoints),
                    systemImage: "play.rectangle.fill"
                ) {
                    model.watchForPoints()
                }
            }
        }
        .padding(Theme.Metrics.spacingWide)
    }
}

/// A single node on the ability map.
private struct TraitNodeView: View {

    let trait: Trait
    let status: NodeStatus
    let isSelected: Bool
    let tint: Color
    let action: () -> Void

    @State private var lit = false

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(fill)
                    .frame(width: 44, height: 44)
                Circle()
                    .strokeBorder(border, lineWidth: isSelected ? 3 : 1.6)
                    .frame(width: 44, height: 44)
                Image(systemName: symbol)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(symbolColor)
            }
            .shadow(
                color: status == .unlocked ? tint.opacity(0.5) : .clear,
                radius: status == .unlocked ? 8 : 0
            )
        }
        .buttonStyle(.plain)
        .scaleEffect(lit ? 1 : 0.9)
        .onAppear {
            withAnimation(Theme.Motion.quick) { lit = true }
        }
        .accessibilityIdentifier(A11y.Tree.node(trait.id.rawValue))
        .accessibilityLabel(Text(L.traitTitle(trait.id)))
        .accessibilityValue(Text(accessibilityValue))
        .accessibilityHint(Text(L.traitDetail(trait.id)))
    }

    private var fill: Color {
        switch status {
        case .unlocked: return tint
        case .affordable: return tint.opacity(0.18)
        case .available: return Theme.Palette.surfaceRaised
        case .locked: return Theme.Palette.surfaceRaised.opacity(0.6)
        }
    }

    private var border: Color {
        switch status {
        case .unlocked: return tint
        case .affordable: return tint
        case .available: return Theme.Palette.outline
        case .locked: return Theme.Palette.outline.opacity(0.5)
        }
    }

    private var symbolColor: Color {
        switch status {
        case .unlocked: return .white
        case .affordable: return tint
        case .available: return Theme.Palette.textSecondary
        case .locked: return Theme.Palette.textTertiary
        }
    }

    private var symbol: String {
        switch status {
        case .unlocked: return "checkmark"
        case .affordable: return "plus"
        case .available: return "hexagon"
        case .locked: return "lock.fill"
        }
    }

    private var accessibilityValue: String {
        switch status {
        case .unlocked: return L.string("tree.unlocked")
        case .affordable, .available: return L.format("tree.cost", trait.cost)
        case .locked: return L.string("picker.locked")
        }
    }
}

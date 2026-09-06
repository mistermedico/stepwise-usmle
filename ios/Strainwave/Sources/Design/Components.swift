import SwiftUI
import Foundation

// MARK: - Surfaces

/// The standard raised panel: rounded, hairlined, quietly shadowed.
struct Panel<Content: View>: View {
    var padding: CGFloat = Theme.Metrics.spacingWide
    var tint: Color = Theme.Palette.surface
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: Theme.Metrics.cornerRadius, style: .continuous)
                    .fill(tint)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Metrics.cornerRadius, style: .continuous)
                    .strokeBorder(Theme.Palette.outline, lineWidth: Theme.Metrics.hairline)
            )
    }
}

/// A labelled figure on the control panel.
struct Readout: View {
    let title: String
    let value: String
    var accent: Color = Theme.Palette.textPrimary
    var caption: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(Theme.Typography.caption)
                .foregroundStyle(Theme.Palette.textSecondary)
            Text(value)
                .font(Theme.Typography.readoutSmall)
                .foregroundStyle(accent)
            if let caption {
                Text(caption)
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Palette.textTertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("\(title), \(value)"))
    }
}

/// A thin progress bar. Used for awareness, the solution countdown and the
/// world-reach meter, so all three read as the same instrument.
struct Meter: View {
    let value: Double
    var tint: Color = Theme.Palette.spread
    var track: Color = Theme.Palette.outline
    var height: CGFloat = 6

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(track)
                Capsule()
                    .fill(tint)
                    .frame(width: proxy.size.width * min(1, max(0, value)))
            }
        }
        .frame(height: height)
        .animation(Theme.Motion.standard, value: value)
        .accessibilityHidden(true)
    }
}

// MARK: - Controls

/// The primary action: full-width, high contrast, unmistakable.
struct PrimaryButton: View {
    let title: String
    var systemImage: String?
    var tint: Color = Theme.Palette.spread
    var isEnabled: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Theme.Metrics.spacingTight) {
                if let systemImage {
                    Image(systemName: systemImage)
                }
                Text(title)
                    .font(Theme.Typography.subheading)
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: 54)
            .foregroundStyle(.white)
            .background(
                RoundedRectangle(cornerRadius: Theme.Metrics.cornerRadius, style: .continuous)
                    .fill(isEnabled ? tint : Theme.Palette.textTertiary)
            )
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
    }
}

/// A quieter action that still reads as a control.
struct SecondaryButton: View {
    let title: String
    var systemImage: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Theme.Metrics.spacingTight) {
                if let systemImage {
                    Image(systemName: systemImage)
                }
                Text(title)
                    .font(Theme.Typography.callout.weight(.semibold))
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: Theme.Metrics.minimumTapTarget)
            .foregroundStyle(Theme.Palette.textPrimary)
            .background(
                RoundedRectangle(cornerRadius: Theme.Metrics.cornerRadius, style: .continuous)
                    .fill(Theme.Palette.surfaceRaised)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Metrics.cornerRadius, style: .continuous)
                    .strokeBorder(Theme.Palette.outline, lineWidth: Theme.Metrics.hairline)
            )
        }
        .buttonStyle(.plain)
    }
}

/// A section header with an optional trailing action.
struct SectionHeader<Trailing: View>: View {
    let title: String
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(Theme.Typography.heading)
                .foregroundStyle(Theme.Palette.textPrimary)
            Spacer(minLength: Theme.Metrics.spacing)
            trailing()
        }
        .accessibilityAddTraits(.isHeader)
    }
}

extension SectionHeader where Trailing == EmptyView {
    init(title: String) {
        self.init(title: title, trailing: { EmptyView() })
    }
}

/// A small status pill: territory state, objective badges, tier labels.
struct Chip: View {
    let text: String
    var systemImage: String?
    var tint: Color = Theme.Palette.textSecondary

    var body: some View {
        HStack(spacing: 4) {
            if let systemImage {
                Image(systemName: systemImage).font(.caption2)
            }
            Text(text).font(Theme.Typography.caption.weight(.semibold))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .foregroundStyle(tint)
        .background(
            Capsule().fill(tint.opacity(0.14))
        )
    }
}

// MARK: - Empty states

/// A designed empty state (section 4): never a blank screen.
struct EmptyStateView: View {
    let title: String
    let detail: String
    var illustration: EmptyIllustration = .shelf

    var body: some View {
        VStack(spacing: Theme.Metrics.spacing) {
            illustration.view
                .frame(width: 140, height: 92)
            Text(title)
                .font(Theme.Typography.subheading)
                .foregroundStyle(Theme.Palette.textPrimary)
            Text(detail)
                .font(Theme.Typography.callout)
                .foregroundStyle(Theme.Palette.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.Metrics.spacingSection)
        .accessibilityElement(children: .combine)
    }
}

enum EmptyIllustration {
    /// An empty laboratory shelf, drawn rather than shipped as an asset.
    case shelf
    /// An empty pin board.
    case board

    @ViewBuilder var view: some View {
        switch self {
        case .shelf: ShelfIllustration()
        case .board: BoardIllustration()
        }
    }
}

private struct ShelfIllustration: View {
    var body: some View {
        Canvas { context, size in
            let line = Theme.Palette.outline
            let glass = Theme.Palette.spreadSoft

            // Two shelves.
            for row in 0..<2 {
                let y = size.height * (row == 0 ? 0.44 : 0.86)
                var shelf = Path()
                shelf.move(to: CGPoint(x: size.width * 0.06, y: y))
                shelf.addLine(to: CGPoint(x: size.width * 0.94, y: y))
                context.stroke(shelf, with: .color(line), lineWidth: 2)
            }

            // Three empty vessels, outlines only.
            let positions: [CGFloat] = [0.22, 0.5, 0.78]
            for (index, position) in positions.enumerated() {
                let width = size.width * 0.13
                let height = size.height * (index == 1 ? 0.30 : 0.24)
                let rect = CGRect(
                    x: size.width * position - width / 2,
                    y: size.height * 0.44 - height,
                    width: width,
                    height: height
                )
                let shape = Path(roundedRect: rect, cornerRadius: 4)
                context.fill(shape, with: .color(glass.opacity(0.5)))
                context.stroke(shape, with: .color(line), lineWidth: 1.5)
            }
        }
        .accessibilityHidden(true)
    }
}

private struct BoardIllustration: View {
    var body: some View {
        Canvas { context, size in
            let outline = Theme.Palette.outline
            let board = Path(
                roundedRect: CGRect(origin: .zero, size: size).insetBy(dx: 6, dy: 6),
                cornerRadius: 10
            )
            context.stroke(board, with: .color(outline), lineWidth: 2)

            // Four empty pin holes.
            for column in 0..<4 {
                let x = size.width * (0.22 + Double(column) * 0.19)
                let dot = Path(ellipseIn: CGRect(x: x - 4, y: size.height * 0.46, width: 8, height: 8))
                context.stroke(dot, with: .color(outline), lineWidth: 1.5)
            }
        }
        .accessibilityHidden(true)
    }
}

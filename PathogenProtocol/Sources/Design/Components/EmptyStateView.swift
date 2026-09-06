import SwiftUI

/// A designed, non-blank empty state (spec section 4, "מדף ריק במעבדה") — used for the
/// past-reports gallery and anywhere else a list can legitimately be empty.
public struct EmptyStateView: View {
    let symbolName: String
    let title: String
    let message: String

    public init(symbolName: String, title: String, message: String) {
        self.symbolName = symbolName
        self.title = title
        self.message = message
    }

    public var body: some View {
        VStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(AppColor.labSurface)
                    .frame(width: 88, height: 88)
                Image(systemName: symbolName)
                    .font(.system(size: 34, weight: .light))
                    .foregroundStyle(AppColor.response)
            }
            Text(title)
                .font(AppFont.cardTitle)
                .foregroundStyle(AppColor.textPrimary)
            Text(message)
                .font(AppFont.body(13))
                .foregroundStyle(AppColor.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .padding(.vertical, 40)
        .frame(maxWidth: .infinity)
    }
}

import SwiftUI

struct SharedLoadingStateView: View {
    let title: String

    var body: some View {
        HStack(spacing: AppSpacing.md) {
            ProgressView()
            Text(title)
                .font(AppTypography.body)
                .foregroundStyle(AppColorToken.textSecondary.color)
            Spacer()
        }
        .padding(AppSpacing.lg)
        .background(AppColorToken.surface.color)
        .clipShape(RoundedRectangle(cornerRadius: AppCornerRadius.md, style: .continuous))
    }
}

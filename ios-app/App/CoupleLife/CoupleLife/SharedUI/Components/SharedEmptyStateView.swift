import SwiftUI

struct SharedEmptyStateView: View {
    let title: String
    let message: String
    let symbolName: String

    var body: some View {
        VStack(spacing: AppSpacing.sm) {
            Image(systemName: symbolName)
                .font(.title2)
                .foregroundStyle(AppColorToken.textSecondary.color)
            Text(title)
                .font(AppTypography.sectionTitle)
                .foregroundStyle(AppColorToken.textPrimary.color)
            Text(message)
                .font(AppTypography.body)
                .foregroundStyle(AppColorToken.textSecondary.color)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(AppSpacing.xl)
        .background(AppColorToken.surface.color)
        .clipShape(RoundedRectangle(cornerRadius: AppCornerRadius.md, style: .continuous))
    }
}

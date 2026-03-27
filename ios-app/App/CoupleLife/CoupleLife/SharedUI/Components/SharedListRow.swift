import SwiftUI

struct SharedListRow: View {
    let title: String
    let subtitle: String?
    let symbolName: String
    let colorToken: AppColorToken
    let badgeText: String?

    var body: some View {
        HStack(spacing: AppSpacing.md) {
            Image(systemName: symbolName)
                .font(.body.weight(.semibold))
                .foregroundStyle(colorToken.color)
                .frame(width: 28, height: 28)
                .background(colorToken.color.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: AppCornerRadius.sm, style: .continuous))

            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text(title)
                    .font(AppTypography.body)
                    .foregroundStyle(AppColorToken.textPrimary.color)
                if let subtitle {
                    Text(subtitle)
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColorToken.textSecondary.color)
                }
            }

            Spacer(minLength: AppSpacing.sm)

            if let badgeText {
                SharedStatusBadge(text: badgeText, colorToken: colorToken)
            }
        }
        .padding(.vertical, AppSpacing.xs)
        .accessibilityElement(children: .combine)
    }
}

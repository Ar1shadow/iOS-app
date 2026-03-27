import SwiftUI

struct SharedTag: View {
    let text: String
    let colorToken: AppColorToken
    var symbolName: String? = nil

    var body: some View {
        HStack(spacing: AppSpacing.xs) {
            if let symbolName {
                Image(systemName: symbolName)
                    .font(.caption2.weight(.semibold))
            }
            Text(text)
                .font(AppTypography.badge)
        }
        .foregroundStyle(colorToken.color)
        .padding(.horizontal, AppSpacing.sm)
        .padding(.vertical, AppSpacing.xs)
        .background(colorToken.color.opacity(0.12))
        .clipShape(Capsule())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(text)
    }
}

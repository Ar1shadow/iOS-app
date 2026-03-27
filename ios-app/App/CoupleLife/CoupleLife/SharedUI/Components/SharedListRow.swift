import SwiftUI

struct SharedListRow: View {
    enum LayoutMode: Equatable {
        case horizontal
        case stacked
    }

    let title: String
    let subtitle: String?
    let symbolName: String
    let colorToken: AppColorToken
    let badgeText: String?
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    static func layoutMode(for dynamicTypeSize: DynamicTypeSize) -> LayoutMode {
        dynamicTypeSize.isAccessibilitySize ? .stacked : .horizontal
    }

    var body: some View {
        Group {
            if Self.layoutMode(for: dynamicTypeSize) == .stacked {
                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    mainContent
                    if let badgeText {
                        SharedStatusBadge(text: badgeText, colorToken: colorToken)
                    }
                }
            } else {
                HStack(spacing: AppSpacing.md) {
                    mainContent
                    Spacer(minLength: AppSpacing.sm)
                    if let badgeText {
                        SharedStatusBadge(text: badgeText, colorToken: colorToken)
                    }
                }
            }
        }
        .padding(.vertical, AppSpacing.xs)
        .accessibilityElement(children: .combine)
    }

    private var mainContent: some View {
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
                    .fixedSize(horizontal: false, vertical: true)
                if let subtitle {
                    Text(subtitle)
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColorToken.textSecondary.color)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .layoutPriority(1)
        }
    }
}

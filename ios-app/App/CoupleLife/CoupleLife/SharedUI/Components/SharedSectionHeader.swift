import SwiftUI

struct SharedSectionHeader<Trailing: View>: View {
    private let title: String
    private let subtitle: String?
    private let trailing: Trailing

    init(
        _ title: String,
        subtitle: String? = nil,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.title = title
        self.subtitle = subtitle
        self.trailing = trailing()
    }

    init(_ title: String, subtitle: String? = nil) where Trailing == EmptyView {
        self.init(title, subtitle: subtitle) { EmptyView() }
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text(title)
                    .font(AppTypography.sectionTitle)
                    .foregroundStyle(AppColorToken.textPrimary.color)
                if let subtitle {
                    Text(subtitle)
                        .font(AppTypography.sectionSubtitle)
                        .foregroundStyle(AppColorToken.textSecondary.color)
                }
            }

            Spacer(minLength: AppSpacing.md)
            trailing
        }
    }
}

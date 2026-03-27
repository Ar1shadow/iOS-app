import SwiftUI

struct SharedCard<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(AppSpacing.lg)
            .background(AppColorToken.surface.color)
            .clipShape(RoundedRectangle(cornerRadius: AppCornerRadius.lg, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: AppCornerRadius.lg, style: .continuous)
                    .stroke(AppColorToken.surfaceBorder.color.opacity(0.25), lineWidth: 1)
            )
            .shadow(
                color: AppShadowToken.card.color,
                radius: AppShadowToken.card.radius,
                x: AppShadowToken.card.x,
                y: AppShadowToken.card.y
            )
    }
}

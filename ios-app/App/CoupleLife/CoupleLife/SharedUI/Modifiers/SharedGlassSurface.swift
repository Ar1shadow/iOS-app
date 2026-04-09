import SwiftUI

enum SharedGlassSurfaceStyle {
    case cardOverlay
    case panel
}

private struct SharedGlassSurfaceModifier: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    let style: SharedGlassSurfaceStyle

    func body(content: Content) -> some View {
        switch style {
        case .cardOverlay:
            content
                .background {
                    if !reduceTransparency {
                        RoundedRectangle(cornerRadius: AppCornerRadius.lg, style: .continuous)
                            .fill(.ultraThinMaterial)
                            .opacity(0.28)
                            .allowsHitTesting(false)
                    }
                }
                .overlay(glassStroke)
        case .panel:
            content
                .background(panelBackground)
                .overlay(glassStroke)
                .clipShape(RoundedRectangle(cornerRadius: AppCornerRadius.lg, style: .continuous))
                .shadow(
                    color: AppShadowToken.card.color.opacity(0.9),
                    radius: 14,
                    x: 0,
                    y: 8
                )
        }
    }

    private var glassStroke: some View {
        RoundedRectangle(cornerRadius: AppCornerRadius.lg, style: .continuous)
            .stroke(Color.white.opacity(reduceTransparency ? 0.12 : 0.3), lineWidth: 1)
    }

    @ViewBuilder
    private var panelBackground: some View {
        if reduceTransparency {
            RoundedRectangle(cornerRadius: AppCornerRadius.lg, style: .continuous)
                .fill(AppColorToken.surface.color)
        } else {
            RoundedRectangle(cornerRadius: AppCornerRadius.lg, style: .continuous)
                .fill(.ultraThinMaterial)
        }
    }
}

extension View {
    func sharedGlassSurface(_ style: SharedGlassSurfaceStyle = .panel) -> some View {
        modifier(SharedGlassSurfaceModifier(style: style))
    }
}

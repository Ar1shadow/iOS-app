import SwiftUI

enum AppColorToken: Equatable {
    case background
    case surface
    case surfaceBorder
    case textPrimary
    case textSecondary
    case blue
    case brown
    case red
    case indigo
    case green
    case slate

    var color: Color {
        switch self {
        case .background:
            return Color(.systemGroupedBackground)
        case .surface:
            return Color(.secondarySystemGroupedBackground)
        case .surfaceBorder:
            return Color(.separator)
        case .textPrimary:
            return Color.primary
        case .textSecondary:
            return Color.secondary
        case .blue:
            return .blue
        case .brown:
            return .brown
        case .red:
            return .red
        case .indigo:
            return .indigo
        case .green:
            return .green
        case .slate:
            return Color(.systemGray)
        }
    }
}

enum AppSpacing {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 24
    static let screenHorizontal: CGFloat = 20
}

enum AppCornerRadius {
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
}

enum AppShadowToken {
    case card

    var color: Color {
        switch self {
        case .card:
            return Color.black.opacity(0.08)
        }
    }

    var radius: CGFloat {
        switch self {
        case .card:
            return 8
        }
    }

    var x: CGFloat {
        0
    }

    var y: CGFloat {
        3
    }
}

enum AppTypography {
    static let sectionTitle: Font = .headline.weight(.semibold)
    static let sectionSubtitle: Font = .subheadline
    static let body: Font = .body
    static let caption: Font = .caption
    static let badge: Font = .caption.weight(.semibold)
}

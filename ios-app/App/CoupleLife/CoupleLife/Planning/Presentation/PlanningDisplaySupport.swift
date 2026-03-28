import Foundation

extension PlanLevel {
    var title: String {
        switch self {
        case .day:
            return "日"
        case .week:
            return "周"
        case .month:
            return "月"
        case .year:
            return "年"
        }
    }
}

extension TaskStatus {
    var title: String {
        switch self {
        case .todo:
            return "待办"
        case .done:
            return "已完成"
        case .postponed:
            return "已延期"
        case .cancelled:
            return "已取消"
        }
    }

    var symbolName: String {
        switch self {
        case .todo:
            return "circle"
        case .done:
            return "checkmark.circle.fill"
        case .postponed:
            return "arrow.uturn.forward.circle"
        case .cancelled:
            return "xmark.circle.fill"
        }
    }

    var colorToken: AppColorToken {
        switch self {
        case .todo:
            return .blue
        case .done:
            return .green
        case .postponed:
            return .brown
        case .cancelled:
            return .red
        }
    }
}

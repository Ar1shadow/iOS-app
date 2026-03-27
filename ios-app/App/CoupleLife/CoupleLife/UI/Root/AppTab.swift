import Foundation

enum AppTab: String, CaseIterable, Hashable {
    case home
    case calendar
    case planning
    case fitness
    case profile

    var title: String {
        switch self {
        case .home:
            "首页"
        case .calendar:
            "日历"
        case .planning:
            "计划"
        case .fitness:
            "运动"
        case .profile:
            "我的"
        }
    }

    var systemImage: String {
        switch self {
        case .home:
            "house"
        case .calendar:
            "calendar"
        case .planning:
            "checklist"
        case .fitness:
            "figure.walk"
        case .profile:
            "person"
        }
    }
}

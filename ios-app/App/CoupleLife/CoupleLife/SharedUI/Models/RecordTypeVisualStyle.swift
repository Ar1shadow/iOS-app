import SwiftUI

struct RecordTypeVisualStyle: Equatable {
    let title: String
    let symbolName: String
    let colorToken: AppColorToken

    var tintColor: Color {
        colorToken.color
    }
}

enum RecordTypeVisualCatalog {
    static let mapping: [RecordType: RecordTypeVisualStyle] = [
        .water: RecordTypeVisualStyle(title: "喝水", symbolName: "drop.fill", colorToken: .blue),
        .bowelMovement: RecordTypeVisualStyle(title: "排便", symbolName: "toilet.fill", colorToken: .brown),
        .menstruation: RecordTypeVisualStyle(title: "经期", symbolName: "drop.circle.fill", colorToken: .red),
        .sleep: RecordTypeVisualStyle(title: "睡眠", symbolName: "moon.stars.fill", colorToken: .indigo),
        .activity: RecordTypeVisualStyle(title: "活动", symbolName: "figure.walk", colorToken: .green),
        .custom: RecordTypeVisualStyle(title: "自定义", symbolName: "square.and.pencil", colorToken: .slate)
    ]

    static func style(for type: RecordType) -> RecordTypeVisualStyle {
        mapping[type] ?? mapping[.custom]!
    }
}

extension RecordType {
    var visualStyle: RecordTypeVisualStyle {
        RecordTypeVisualCatalog.style(for: self)
    }
}

import Foundation

struct VisibilityPolicy: Equatable {
    struct Option: Identifiable, Equatable {
        let visibility: Visibility
        let title: String
        let description: String

        var id: Visibility { visibility }
    }

    struct SharedRecordContent: Equatable {
        let visibility: Visibility
        let summaryText: String?
        let note: String?
        let tags: [String]
        let valueText: String?
    }

    let allowedVisibilities: [Visibility]
    let helperText: String
    let summaryPreviewText: String?

    var options: [Option] {
        allowedVisibilities.map { visibility in
            Option(
                visibility: visibility,
                title: visibility.title,
                description: description(for: visibility)
            )
        }
    }

    func sanitized(_ visibility: Visibility) -> Visibility {
        guard allowedVisibilities.contains(visibility) else {
            return .private
        }
        return visibility
    }

    func chipLabel(for visibility: Visibility) -> String {
        sanitized(visibility).chipLabel
    }

    func sharedRecordContent(
        visibility: Visibility,
        note: String?,
        tagsRaw: String?,
        valueText: String?
    ) -> SharedRecordContent {
        let resolvedVisibility = sanitized(visibility)

        switch resolvedVisibility {
        case .private:
            return SharedRecordContent(
                visibility: resolvedVisibility,
                summaryText: nil,
                note: nil,
                tags: [],
                valueText: nil
            )
        case .summaryShared:
            return SharedRecordContent(
                visibility: resolvedVisibility,
                summaryText: summaryPreviewText,
                note: nil,
                tags: [],
                valueText: nil
            )
        case .coupleShared:
            return SharedRecordContent(
                visibility: resolvedVisibility,
                summaryText: summaryPreviewText,
                note: note,
                tags: normalizedTags(from: tagsRaw),
                valueText: valueText
            )
        }
    }

    static let task = VisibilityPolicy(
        allowedVisibilities: [.private, .coupleShared],
        helperText: "任务默认仅自己可见。共享后，伴侣可看到任务标题、时间与当前状态。",
        summaryPreviewText: nil
    )

    static let healthSnapshot = VisibilityPolicy(
        allowedVisibilities: [.private],
        helperText: "健康快照当前版本默认仅自己可见。",
        summaryPreviewText: nil
    )

    static func record(type: RecordType) -> VisibilityPolicy {
        if sensitiveRecordTypes.contains(type) {
            return VisibilityPolicy(
                allowedVisibilities: [.private, .summaryShared, .coupleShared],
                helperText: "敏感记录默认仅自己可见。你可以只共享汇总结论，或明确授权后完整共享细节。",
                summaryPreviewText: type.summaryPreviewText
            )
        }

        return VisibilityPolicy(
            allowedVisibilities: [.private, .coupleShared],
            helperText: "记录默认仅自己可见。开启共享后，伴侣可看到这条记录的完整内容。",
            summaryPreviewText: type.summaryPreviewText
        )
    }

    private static let sensitiveRecordTypes: Set<RecordType> = [.menstruation, .bowelMovement, .sleep]

    private func description(for visibility: Visibility) -> String {
        switch sanitized(visibility) {
        case .private:
            return "仅自己可见，不会同步给伴侣。"
        case .summaryShared:
            return "只共享结论或状态摘要，不共享详细备注、标签与原始内容。"
        case .coupleShared:
            return "伴侣可查看这条内容的完整信息。"
        }
    }

    private func normalizedTags(from rawValue: String?) -> [String] {
        (rawValue ?? "")
            .split(separator: ",")
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
}

extension Visibility {
    var chipLabel: String {
        switch self {
        case .private:
            return "私密"
        case .summaryShared:
            return "仅汇总"
        case .coupleShared:
            return "完全共享"
        }
    }

    var title: String {
        switch self {
        case .private:
            return "仅自己可见"
        case .summaryShared:
            return "仅汇总共享"
        case .coupleShared:
            return "完全共享"
        }
    }
}

private extension RecordType {
    var summaryPreviewText: String {
        switch self {
        case .menstruation:
            return "已记录经期状态"
        case .bowelMovement:
            return "已记录排便状态"
        case .sleep:
            return "已记录睡眠状态"
        case .water:
            return "已记录饮水"
        case .activity:
            return "已记录活动"
        case .custom:
            return "已记录一条自定义内容"
        }
    }
}

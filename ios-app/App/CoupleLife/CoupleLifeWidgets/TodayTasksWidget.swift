import SwiftUI
import WidgetKit

struct TodayTasksEntry: TimelineEntry {
    enum State {
        case summary
        case empty
    }

    let date: Date
    let state: State
    let totalTasks: Int
    let completedTasks: Int
    let nextTaskTitle: String?
    let nextTaskTimeText: String?

    static func previewSummary(date: Date = .now) -> TodayTasksEntry {
        TodayTasksEntry(
            date: date,
            state: .summary,
            totalTasks: 4,
            completedTasks: 2,
            nextTaskTitle: "Book dinner for Friday",
            nextTaskTimeText: "Next up · 6:30 PM"
        )
    }

    static func empty(date: Date = .now) -> TodayTasksEntry {
        TodayTasksEntry(
            date: date,
            state: .empty,
            totalTasks: 0,
            completedTasks: 0,
            nextTaskTitle: nil,
            nextTaskTimeText: nil
        )
    }
}

struct TodayTasksProvider: TimelineProvider {
    func placeholder(in context: Context) -> TodayTasksEntry {
        .previewSummary()
    }

    func getSnapshot(in context: Context, completion: @escaping (TodayTasksEntry) -> Void) {
        completion(context.isPreview ? .previewSummary() : .empty())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TodayTasksEntry>) -> Void) {
        let refreshDate = Calendar.current.date(byAdding: .minute, value: 30, to: .now) ?? .now
        completion(Timeline(entries: [.empty()], policy: .after(refreshDate)))
    }
}

struct TodayTasksWidget: Widget {
    private let kind = "TodayTasksWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TodayTasksProvider()) { entry in
            TodayTasksWidgetView(entry: entry)
        }
        .configurationDisplayName("Today's Tasks")
        .description("Shows how many tasks are planned today and the next focus item.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

private struct TodayTasksWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: TodayTasksEntry

    var body: some View {
        WidgetSurface(background: WidgetTheme.background([Color(red: 0.22, green: 0.30, blue: 0.76), Color(red: 0.45, green: 0.22, blue: 0.80)])) {
            switch entry.state {
            case .summary:
                VStack(alignment: .leading, spacing: family == .systemSmall ? WidgetTheme.compactSpacing : WidgetTheme.roomySpacing) {
                    WidgetMetricChip(icon: "checklist", title: "Today", tint: .white)
                    Text("\(entry.completedTasks)/\(entry.totalTasks)")
                        .font(.system(size: family == .systemSmall ? 30 : 34, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text("tasks finished")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.82))

                    Spacer(minLength: 0)

                    if let nextTaskTitle = entry.nextTaskTitle {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(nextTaskTitle)
                                .font(.headline)
                                .foregroundStyle(.white)
                                .lineLimit(family == .systemSmall ? 2 : 1)
                            if let nextTaskTimeText = entry.nextTaskTimeText {
                                Text(nextTaskTimeText)
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.78))
                                    .lineLimit(1)
                            }
                        }
                    }
                }
            case .empty:
                WidgetEmptyStateView(
                    title: "No tasks yet",
                    message: "Open CoupleLife to add today's plans. The widget will show your next focus item here.",
                    icon: "calendar.badge.plus"
                )
            }
        }
    }
}

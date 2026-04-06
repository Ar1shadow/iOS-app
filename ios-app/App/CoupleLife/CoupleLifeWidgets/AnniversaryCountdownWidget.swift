import SwiftUI
import WidgetKit

struct AnniversaryCountdownEntry: TimelineEntry {
    enum State {
        case countdown
        case placeholder
    }

    let date: Date
    let state: State
    let title: String?
    let targetDateText: String?
    let daysRemaining: Int?

    static func previewCountdown(date: Date = .now) -> AnniversaryCountdownEntry {
        AnniversaryCountdownEntry(
            date: date,
            state: .countdown,
            title: "Next Anniversary",
            targetDateText: "December 18",
            daysRemaining: 256
        )
    }

    static func placeholder(date: Date = .now) -> AnniversaryCountdownEntry {
        AnniversaryCountdownEntry(
            date: date,
            state: .placeholder,
            title: nil,
            targetDateText: nil,
            daysRemaining: nil
        )
    }
}

struct AnniversaryCountdownProvider: TimelineProvider {
    func placeholder(in context: Context) -> AnniversaryCountdownEntry {
        .previewCountdown()
    }

    func getSnapshot(in context: Context, completion: @escaping (AnniversaryCountdownEntry) -> Void) {
        completion(context.isPreview ? .previewCountdown() : .placeholder())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<AnniversaryCountdownEntry>) -> Void) {
        let midnight = Calendar.current.startOfDay(for: .now)
        let refreshDate = Calendar.current.date(byAdding: .day, value: 1, to: midnight) ?? .now
        completion(Timeline(entries: [.placeholder()], policy: .after(refreshDate)))
    }
}

struct AnniversaryCountdownWidget: Widget {
    private let kind = "AnniversaryCountdownWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: AnniversaryCountdownProvider()) { entry in
            AnniversaryCountdownWidgetView(entry: entry)
        }
        .configurationDisplayName("Anniversary Countdown")
        .description("Keeps the next relationship milestone visible, even before CoupleSpace sync is ready.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

private struct AnniversaryCountdownWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: AnniversaryCountdownEntry

    var body: some View {
        WidgetSurface(background: WidgetTheme.background([Color(red: 0.92, green: 0.38, blue: 0.53), Color(red: 0.98, green: 0.67, blue: 0.42)])) {
            switch entry.state {
            case .countdown:
                VStack(alignment: .leading, spacing: family == .systemSmall ? WidgetTheme.compactSpacing : WidgetTheme.roomySpacing) {
                    WidgetMetricChip(icon: "heart.fill", title: "Milestone", tint: .white)

                    if let daysRemaining = entry.daysRemaining {
                        Text("\(daysRemaining)")
                            .font(.system(size: family == .systemSmall ? 30 : 36, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                        Text(daysRemaining == 1 ? "day to go" : "days to go")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.82))
                    }

                    Spacer(minLength: 0)

                    VStack(alignment: .leading, spacing: 4) {
                        if let title = entry.title {
                            Text(title)
                                .font(.headline)
                                .foregroundStyle(.white)
                                .lineLimit(1)
                        }
                        if let targetDateText = entry.targetDateText {
                            Text(targetDateText)
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.78))
                                .lineLimit(1)
                        }
                    }
                }
            case .placeholder:
                WidgetEmptyStateView(
                    title: "Anniversary coming soon",
                    message: "Once CoupleSpace milestones are available, this widget will count down the next date here.",
                    icon: "calendar.badge.clock"
                )
            }
        }
    }
}

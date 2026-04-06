import SwiftUI
import WidgetKit

struct TodayStepsEntry: TimelineEntry {
    enum State {
        case summary
        case unavailable
    }

    let date: Date
    let state: State
    let stepCount: Int?
    let activeEnergyText: String?
    let progressText: String?

    static func previewSummary(date: Date = .now) -> TodayStepsEntry {
        TodayStepsEntry(
            date: date,
            state: .summary,
            stepCount: 8260,
            activeEnergyText: "420 kcal active",
            progressText: "84% of 10k goal"
        )
    }

    static func unavailable(date: Date = .now) -> TodayStepsEntry {
        TodayStepsEntry(
            date: date,
            state: .unavailable,
            stepCount: nil,
            activeEnergyText: nil,
            progressText: nil
        )
    }
}

struct TodayStepsProvider: TimelineProvider {
    func placeholder(in context: Context) -> TodayStepsEntry {
        .previewSummary()
    }

    func getSnapshot(in context: Context, completion: @escaping (TodayStepsEntry) -> Void) {
        completion(context.isPreview ? .previewSummary() : .unavailable())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TodayStepsEntry>) -> Void) {
        let refreshDate = Calendar.current.date(byAdding: .hour, value: 1, to: .now) ?? .now
        completion(Timeline(entries: [.unavailable()], policy: .after(refreshDate)))
    }
}

struct TodayStepsWidget: Widget {
    private let kind = "TodayStepsWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TodayStepsProvider()) { entry in
            TodayStepsWidgetView(entry: entry)
        }
        .configurationDisplayName("Today's Steps")
        .description("Highlights step progress and active energy with a clear no-access fallback.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

private struct TodayStepsWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: TodayStepsEntry

    var body: some View {
        WidgetSurface(background: WidgetTheme.background([Color(red: 0.09, green: 0.53, blue: 0.39), Color(red: 0.18, green: 0.72, blue: 0.55)])) {
            switch entry.state {
            case .summary:
                VStack(alignment: .leading, spacing: family == .systemSmall ? WidgetTheme.compactSpacing : WidgetTheme.roomySpacing) {
                    WidgetMetricChip(icon: "figure.walk", title: "Activity", tint: .white)

                    if let stepCount = entry.stepCount {
                        Text(stepCount.formatted())
                            .font(.system(size: family == .systemSmall ? 28 : 32, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                        Text("steps today")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.82))
                    }

                    Spacer(minLength: 0)

                    VStack(alignment: .leading, spacing: 4) {
                        if let progressText = entry.progressText {
                            Text(progressText)
                                .font(.headline)
                                .foregroundStyle(.white)
                                .lineLimit(2)
                        }
                        if let activeEnergyText = entry.activeEnergyText {
                            Text(activeEnergyText)
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.78))
                                .lineLimit(1)
                        }
                    }
                }
            case .unavailable:
                WidgetEmptyStateView(
                    title: "Health access needed",
                    message: "Open CoupleLife and enable Health permissions to show steps or active energy here.",
                    icon: "heart.text.square"
                )
            }
        }
    }
}

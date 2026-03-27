import SwiftUI

struct HomeTab: View {
    @StateObject private var viewModel: HomeDashboardViewModel

    init(
        taskRepository: any TaskRepository,
        recordRepository: any RecordRepository,
        healthSnapshotRepository: any HealthSnapshotRepository,
        healthDataService: any HealthDataService,
        ownerUserId: String = "demo-user"
    ) {
        let service = DefaultHomeDashboardService(
            taskRepository: taskRepository,
            recordRepository: recordRepository,
            healthSnapshotRepository: healthSnapshotRepository
        )
        _viewModel = StateObject(
            wrappedValue: HomeDashboardViewModel(
                service: service,
                healthDataService: healthDataService,
                ownerUserId: ownerUserId
            )
        )
    }

    var body: some View {
        NavigationStack {
            Group {
                switch viewModel.state {
                case .loading:
                    dashboardContainer {
                        SharedLoadingStateView(title: "正在加载首页摘要…")
                    }
                case .failed(let message):
                    dashboardContainer {
                        SharedEmptyStateView(
                            title: "首页暂不可用",
                            message: message,
                            symbolName: "exclamationmark.triangle"
                        )
                    }
                case .loaded(let summary, let availability):
                    dashboardContent(summary: summary, availability: availability)
                }
            }
            .background(AppColorToken.background.color.ignoresSafeArea())
            .navigationTitle("首页")
        }
        .task {
            await viewModel.load()
        }
    }

    @ViewBuilder
    private func dashboardContent(summary: HomeDashboardSummary, availability: ServiceAvailability) -> some View {
        dashboardContainer {
            SharedSectionHeader("今日总览", subtitle: daySubtitle(from: summary.dayRange.start))

            SharedCard {
                VStack(alignment: .leading, spacing: AppSpacing.md) {
                    HStack {
                        Text("今日任务")
                            .font(AppTypography.sectionTitle)
                        Spacer()
                        SharedTag(text: "\(summary.todayTaskCompleted)/\(summary.todayTaskTotal)", colorToken: .green)
                    }

                    if summary.todayTaskTotal == 0 {
                        Text("今天还没有任务。")
                            .font(AppTypography.body)
                            .foregroundStyle(AppColorToken.textSecondary.color)
                    } else {
                        Text("待完成：\(summary.todayTaskTotal - summary.todayTaskCompleted)")
                            .font(AppTypography.body)
                            .foregroundStyle(AppColorToken.textPrimary.color)

                        if !summary.importantTasks.isEmpty {
                            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                                ForEach(summary.importantTasks, id: \.self) { item in
                                    SharedListRow(
                                        title: item.title,
                                        subtitle: item.dueAt.map { "截止 \(timeLabel($0))" },
                                        symbolName: "checklist",
                                        colorToken: .green,
                                        badgeText: "重要"
                                    )
                                }
                            }
                        }
                    }
                }
            }
            .homeGlassSurface()

            SharedCard {
                VStack(alignment: .leading, spacing: AppSpacing.md) {
                    SharedSectionHeader("今日记录", subtitle: "按类型摘要")

                    if summary.todayRecordTotal == 0 {
                        Text("今天还没有记录。")
                            .font(AppTypography.body)
                            .foregroundStyle(AppColorToken.textSecondary.color)
                    } else {
                        HStack(spacing: AppSpacing.sm) {
                            ForEach(summary.recordTypeCounts.keys.sorted(by: { $0.rawValue < $1.rawValue }), id: \.self) { type in
                                let style = type.visualStyle
                                SharedTag(
                                    text: "\(style.title) \(summary.recordTypeCounts[type, default: 0])",
                                    colorToken: style.colorToken,
                                    symbolName: style.symbolName
                                )
                            }
                        }
                    }
                }
            }
            .homeGlassSurface()

            SharedCard {
                VStack(alignment: .leading, spacing: AppSpacing.md) {
                    SharedSectionHeader("运动摘要", subtitle: healthSubtitle(for: availability))

                    if availability == .notSupported {
                        SharedEmptyStateView(
                            title: "设备不支持健康数据",
                            message: "可在后续设备或权限开放后显示今日步数与睡眠摘要。",
                            symbolName: "heart.slash"
                        )
                    } else if let steps = summary.steps, let sleepHours = summary.sleepHours {
                        HStack(spacing: AppSpacing.lg) {
                            metricView(title: "步数", value: "\(steps)")
                            metricView(title: "睡眠", value: "\(String(format: "%.1f", sleepHours))h")
                        }
                    } else {
                        Text("暂无今日运动或睡眠缓存数据。")
                            .font(AppTypography.body)
                            .foregroundStyle(AppColorToken.textSecondary.color)
                    }
                }
            }
            .homeGlassSurface()

            SharedCard {
                VStack(alignment: .leading, spacing: AppSpacing.md) {
                    SharedSectionHeader("快捷入口")
                    HStack(spacing: AppSpacing.sm) {
                        quickAction(title: "新增记录", symbol: "plus.circle")
                        quickAction(title: "新增任务", symbol: "checklist")
                    }
                }
            }
            .homeGlassSurface()

            if !summary.hasAnyData {
                SharedEmptyStateView(
                    title: "今天还没有聚合数据",
                    message: "可通过快捷入口创建任务或记录，首页将自动更新摘要。",
                    symbolName: "tray"
                )
            }
        }
    }

    private func dashboardContainer<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.xl) {
                content()
            }
            .padding(.horizontal, AppSpacing.screenHorizontal)
            .padding(.vertical, AppSpacing.lg)
        }
    }

    private func metricView(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text(title)
                .font(AppTypography.caption)
                .foregroundStyle(AppColorToken.textSecondary.color)
            Text(value)
                .font(AppTypography.sectionTitle)
                .foregroundStyle(AppColorToken.textPrimary.color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func quickAction(title: String, symbol: String) -> some View {
        Button(action: {}) {
            Label(title, systemImage: symbol)
                .font(AppTypography.body)
                .frame(maxWidth: .infinity)
                .padding(.vertical, AppSpacing.sm)
        }
        .buttonStyle(.borderedProminent)
        .accessibilityHint("MVP 阶段仅展示入口")
    }

    private func daySubtitle(from date: Date) -> String {
        DateFormatter.homeDayFormatter.string(from: date)
    }

    private func timeLabel(_ date: Date) -> String {
        DateFormatter.homeTimeFormatter.string(from: date)
    }

    private func healthSubtitle(for availability: ServiceAvailability) -> String {
        switch availability {
        case .available:
            return "今日缓存摘要"
        case .notAuthorized:
            return "未授权，展示本地缓存"
        case .notSupported:
            return "当前设备不可用"
        case .failed:
            return "服务状态异常"
        }
    }
}

private extension DateFormatter {
    static let homeDayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "M月d日 EEEE"
        return formatter
    }()

    static let homeTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter
    }()
}

private struct HomeGlassSurfaceModifier: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    func body(content: Content) -> some View {
        content
            .overlay {
                if !reduceTransparency {
                    RoundedRectangle(cornerRadius: AppCornerRadius.lg, style: .continuous)
                        .fill(.ultraThinMaterial)
                        .opacity(0.28)
                        .allowsHitTesting(false)
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: AppCornerRadius.lg, style: .continuous)
                    .stroke(Color.white.opacity(reduceTransparency ? 0.0 : 0.3), lineWidth: 1)
            )
    }
}

private extension View {
    func homeGlassSurface() -> some View {
        modifier(HomeGlassSurfaceModifier())
    }
}

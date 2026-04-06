import Charts
import SwiftUI

struct FitnessDashboardView: View {
    @StateObject private var viewModel: FitnessDashboardViewModel
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    init(
        healthSnapshotRepository: any HealthSnapshotRepository,
        healthDataService: any HealthDataService,
        ownerUserId: String = CurrentUser.id
    ) {
        let service = DefaultFitnessDashboardService(repository: healthSnapshotRepository)
        _viewModel = StateObject(
            wrappedValue: FitnessDashboardViewModel(
                service: service,
                healthDataService: healthDataService,
                ownerUserId: ownerUserId
            )
        )
    }

    var body: some View {
        Group {
            switch viewModel.state {
            case .loading:
                dashboardContainer {
                    SharedLoadingStateView(title: "正在加载运动健康摘要…")
                }
            case .failed(let message):
                dashboardContainer {
                    SharedEmptyStateView(
                        title: "运动页暂不可用",
                        message: message,
                        symbolName: "figure.walk.motion"
                    )
                }
            case .loaded(let healthState):
                dashboardContent(healthState: healthState)
            }
        }
        .background(AppColorToken.background.color.ignoresSafeArea())
        .navigationTitle("运动")
        .task {
            await viewModel.load()
            await viewModel.refreshIfNeeded()
        }
    }

    private func dashboardContent(healthState: FitnessDashboardViewModel.HealthState) -> some View {
        dashboardContainer {
            SharedSectionHeader("运动健康", subtitle: bucketSubtitle)

            permissionCard(healthState: healthState)
            bucketPicker
            trendCard
            metricsGrid
        }
    }

    private var bucketSubtitle: String {
        switch viewModel.selectedBucket {
        case .day:
            return "按天查看今日汇总与最近 7 天趋势"
        case .week:
            return "按周查看本周汇总与最近 8 周趋势"
        case .month:
            return "按月查看本月汇总与最近 6 个月趋势"
        }
    }

    private func permissionCard(healthState: FitnessDashboardViewModel.HealthState) -> some View {
        SharedCard {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: AppSpacing.xs) {
                        Text(permissionTitle(for: healthState.availability))
                            .font(AppTypography.sectionTitle)
                            .foregroundStyle(AppColorToken.textPrimary.color)
                        Text(permissionSubtitle(for: healthState.availability))
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColorToken.textSecondary.color)
                    }
                    Spacer()
                    sourceBadge(text: sourceMarker(for: viewModel.visibleSummary))
                }

                if let message = healthState.message {
                    Text(message)
                        .font(AppTypography.body)
                        .foregroundStyle(AppColorToken.textSecondary.color)
                }

                healthActionButton(for: healthState)
            }
        }
    }

    private var bucketPicker: some View {
        HStack(spacing: AppSpacing.sm) {
            ForEach(HealthMetricBucket.allCases, id: \.rawValue) { bucket in
                Button {
                    viewModel.selectBucket(bucket)
                } label: {
                    Text(bucket.title)
                        .font(AppTypography.badge)
                        .foregroundStyle(bucket == viewModel.selectedBucket ? AppColorToken.textPrimary.color : AppColorToken.textSecondary.color)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, AppSpacing.sm)
                }
                .buttonStyle(.plain)
                .background(
                    RoundedRectangle(cornerRadius: AppCornerRadius.md, style: .continuous)
                        .fill(bucket == viewModel.selectedBucket ? AppColorToken.surface.color.opacity(0.92) : Color.clear)
                )
            }
        }
        .padding(AppSpacing.sm)
        .fitnessGlassSurface(reduceTransparency: reduceTransparency)
    }

    private var trendCard: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            HStack {
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text("步数趋势")
                        .font(AppTypography.sectionTitle)
                        .foregroundStyle(AppColorToken.textPrimary.color)
                    Text(trendSubtitle(for: viewModel.selectedBucket))
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColorToken.textSecondary.color)
                }
                Spacer()
                sourceBadge(text: sourceMarker(for: viewModel.visibleSummary))
            }

            if viewModel.hasAnyTrendData {
                Chart(FitnessTrendChartMark.make(for: viewModel.visibleTrend), id: \.id) { mark in
                    switch mark {
                    case .value(_, let label, let value):
                        BarMark(
                            x: .value("日期", label),
                            y: .value("步数", value)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: AppCornerRadius.sm, style: .continuous))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [AppColorToken.green.color.opacity(0.45), AppColorToken.indigo.color.opacity(0.85)],
                                startPoint: .bottom,
                                endPoint: .top
                            )
                        )
                    case .missing(_, let label):
                        RuleMark(x: .value("日期", label))
                            .foregroundStyle(AppColorToken.slate.color.opacity(0.45))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading)
                }
                .frame(height: 220)
            } else {
                SharedEmptyStateView(
                    title: "暂无趋势数据",
                    message: "连接健康数据后，系统同步的步数缓存会显示在这里。",
                    symbolName: "chart.bar"
                )
            }
        }
        .padding(AppSpacing.lg)
        .fitnessGlassSurface(reduceTransparency: reduceTransparency)
    }

    private var metricsGrid: some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: AppSpacing.md),
                GridItem(.flexible(), spacing: AppSpacing.md)
            ],
            spacing: AppSpacing.md
        ) {
            ForEach(FitnessMetricCard.allCases, id: \.self) { metric in
                SharedCard {
                    VStack(alignment: .leading, spacing: AppSpacing.md) {
                        HStack(alignment: .top) {
                            Label(metric.title, systemImage: metric.symbolName)
                                .font(AppTypography.body)
                                .foregroundStyle(metric.color.color)
                            Spacer()
                            sourceBadge(text: sourceMarker(for: viewModel.visibleSummary))
                        }

                        VStack(alignment: .leading, spacing: AppSpacing.xs) {
                            Text(metric.formattedValue(from: viewModel.visibleSummary))
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(AppColorToken.textPrimary.color)
                            Text(metric.detailText(from: viewModel.visibleSummary))
                                .font(AppTypography.caption)
                                .foregroundStyle(AppColorToken.textSecondary.color)
                        }

                        Text(bucketValueCaption(for: viewModel.visibleSummary))
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColorToken.textSecondary.color)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    private func permissionTitle(for availability: ServiceAvailability) -> String {
        switch availability {
        case .available:
            return "已连接健康数据"
        case .notAuthorized:
            return "连接 Apple 健康"
        case .notSupported:
            return "当前环境不可用"
        case .failed:
            return "健康服务异常"
        }
    }

    private func permissionSubtitle(for availability: ServiceAvailability) -> String {
        switch availability {
        case .available:
            return "优先展示本地缓存，刷新时后台更新 day/week/month 汇总"
        case .notAuthorized:
            return "开启后可同步步数、距离、能量、运动、站立、睡眠和静息心率"
        case .notSupported:
            return "保留空态与语义占位，不触发无效读取"
        case .failed:
            return "可以重试状态检查或手动刷新缓存"
        }
    }

    @ViewBuilder
    private func healthActionButton(for healthState: FitnessDashboardViewModel.HealthState) -> some View {
        switch healthState.availability {
        case .available, .failed:
            Button {
                Task { await viewModel.refreshHealthData() }
            } label: {
                Label(healthState.isRefreshing ? "刷新中…" : "刷新缓存", systemImage: "arrow.clockwise")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .disabled(healthState.isRefreshing)
        case .notAuthorized:
            Button {
                Task { await viewModel.connectHealthData() }
            } label: {
                Label(healthState.isRefreshing ? "连接中…" : "连接健康数据", systemImage: "heart.text.square")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(healthState.isRefreshing)
        case .notSupported:
            EmptyView()
        }
    }

    private func bucketValueCaption(for snapshot: HealthMetricSnapshot?) -> String {
        guard let snapshot else {
            return "当前 \(viewModel.selectedBucket.title) 暂无缓存"
        }

        return switch viewModel.selectedBucket {
        case .day:
            "统计日期 \(DateFormatter.fitnessDay.string(from: snapshot.dayStart))"
        case .week:
            "周起始 \(DateFormatter.fitnessShortDay.string(from: snapshot.dayStart))"
        case .month:
            "月份 \(DateFormatter.fitnessMonth.string(from: snapshot.dayStart))"
        }
    }

    private func trendSubtitle(for bucket: HealthMetricBucket) -> String {
        switch bucket {
        case .day:
            return "最近 7 天缓存步数"
        case .week:
            return "最近 8 周缓存步数"
        case .month:
            return "最近 6 个月缓存步数"
        }
    }

    private func sourceMarker(for snapshot: HealthMetricSnapshot?) -> String {
        guard let snapshot else {
            return "系统同步"
        }

        switch snapshot.source {
        case .healthKit, .systemCalendar:
            return "系统同步"
        case .manual:
            return "手动录入"
        }
    }

    private func sourceBadge(text: String) -> some View {
        Text(text)
            .font(AppTypography.badge)
            .foregroundStyle(AppColorToken.textSecondary.color)
            .padding(.horizontal, AppSpacing.sm)
            .padding(.vertical, AppSpacing.xs)
            .background(AppColorToken.surface.color.opacity(0.82), in: Capsule())
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
}

enum FitnessMetricCard: CaseIterable {
    case steps
    case sleep
    case restingHeartRate
    case distance
    case activeEnergy
    case exercise
    case stand

    var title: String {
        switch self {
        case .steps: return "步数"
        case .sleep: return "睡眠"
        case .restingHeartRate: return "静息心率"
        case .distance: return "距离"
        case .activeEnergy: return "消耗能量"
        case .exercise: return "运动时长"
        case .stand: return "站立时长"
        }
    }

    var symbolName: String {
        switch self {
        case .steps: return "shoeprints.fill"
        case .sleep: return "bed.double.fill"
        case .restingHeartRate: return "heart.fill"
        case .distance: return "point.topleft.down.curvedto.point.bottomright.up"
        case .activeEnergy: return "flame.fill"
        case .exercise: return "figure.run"
        case .stand: return "figure.stand"
        }
    }

    var color: AppColorToken {
        switch self {
        case .steps: return .green
        case .sleep: return .indigo
        case .restingHeartRate: return .red
        case .distance: return .blue
        case .activeEnergy: return .brown
        case .exercise: return .green
        case .stand: return .slate
        }
    }

    func formattedValue(from snapshot: HealthMetricSnapshot?) -> String {
        switch self {
        case .steps:
            guard let steps = snapshot?.steps else { return "暂无数据" }
            return NumberFormatter.fitnessInteger.string(from: NSNumber(value: steps)) ?? "\(Int(steps))"
        case .sleep:
            guard let sleepSeconds = snapshot?.sleepSeconds else { return "暂无数据" }
            return String(format: "%.1f 小时", sleepSeconds / 3600)
        case .restingHeartRate:
            guard let rate = snapshot?.restingHeartRate else { return "暂无数据" }
            return "\(Int(rate)) 次/分"
        case .distance:
            guard let distanceMeters = snapshot?.distanceMeters else { return "暂无数据" }
            return String(format: "%.1f 公里", distanceMeters / 1000)
        case .activeEnergy:
            guard let activeEnergy = snapshot?.activeEnergyKcal else { return "暂无数据" }
            return "\(Int(activeEnergy)) 千卡"
        case .exercise:
            guard let exerciseMinutes = snapshot?.exerciseMinutes else { return "暂无数据" }
            return "\(Int(exerciseMinutes)) 分钟"
        case .stand:
            guard let standMinutes = snapshot?.standMinutes else { return "暂无数据" }
            return "\(Int(standMinutes)) 分钟"
        }
    }

    func detailText(from snapshot: HealthMetricSnapshot?) -> String {
        switch self {
        case .steps:
            return snapshot?.steps == nil ? "暂无缓存，请授权并刷新。" : "来自 Apple 健康的聚合数据"
        case .sleep:
            return snapshot?.sleepSeconds == nil ? "暂无缓存，请授权并刷新。" : "来自 Apple 健康的聚合数据"
        case .restingHeartRate:
            return snapshot?.restingHeartRate == nil ? "暂无缓存，请授权并刷新。" : "来自 Apple 健康的聚合数据"
        case .distance:
            return snapshot?.distanceMeters == nil ? "暂无缓存，请授权并刷新。" : "来自 Apple 健康的聚合数据"
        case .activeEnergy:
            return snapshot?.activeEnergyKcal == nil ? "暂无缓存，请授权并刷新。" : "来自 Apple 健康的聚合数据"
        case .exercise:
            return snapshot?.exerciseMinutes == nil ? "暂无缓存，请授权并刷新。" : "来自 Apple 健康的聚合数据"
        case .stand:
            return snapshot?.standMinutes == nil ? "暂无缓存，请授权并刷新。" : "来自 Apple 健康的聚合数据"
        }
    }
}

enum FitnessTrendChartMark: Equatable {
    case value(date: Date, label: String, value: Double)
    case missing(date: Date, label: String)

    var id: String {
        switch self {
        case .value(let date, let label, _):
            return "value-\(date.timeIntervalSince1970)-\(label)"
        case .missing(let date, let label):
            return "missing-\(date.timeIntervalSince1970)-\(label)"
        }
    }

    static func make(for points: [FitnessTrendPoint]) -> [FitnessTrendChartMark] {
        points.map { point in
            if let value = point.value {
                return .value(date: point.date, label: point.label, value: value)
            }
            return .missing(date: point.date, label: point.label)
        }
    }
}

private struct FitnessGlassSurface: ViewModifier {
    let reduceTransparency: Bool

    func body(content: Content) -> some View {
        content
            .background(background)
            .overlay(
                RoundedRectangle(cornerRadius: AppCornerRadius.lg, style: .continuous)
                    .stroke(Color.white.opacity(reduceTransparency ? 0.12 : 0.3), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: AppCornerRadius.lg, style: .continuous))
            .shadow(color: Color.black.opacity(0.08), radius: 14, x: 0, y: 8)
    }

    @ViewBuilder
    private var background: some View {
        if reduceTransparency {
            RoundedRectangle(cornerRadius: AppCornerRadius.lg, style: .continuous)
                .fill(AppColorToken.surface.color)
        } else {
            RoundedRectangle(cornerRadius: AppCornerRadius.lg, style: .continuous)
                .fill(.ultraThinMaterial)
        }
    }
}

private extension View {
    func fitnessGlassSurface(reduceTransparency: Bool) -> some View {
        modifier(FitnessGlassSurface(reduceTransparency: reduceTransparency))
    }
}

private extension HealthMetricBucket {
    var title: String {
        switch self {
        case .day: return "日"
        case .week: return "周"
        case .month: return "月"
        }
    }
}

private extension NumberFormatter {
    static let fitnessInteger: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return formatter
    }()
}

private extension DateFormatter {
    static let fitnessDay: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M月d日"
        return formatter
    }()

    static let fitnessShortDay: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M/d"
        return formatter
    }()

    static let fitnessMonth: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy年M月"
        return formatter
    }()
}

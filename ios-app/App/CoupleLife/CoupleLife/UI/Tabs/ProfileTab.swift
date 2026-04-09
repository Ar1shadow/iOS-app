import SwiftUI
import UIKit

struct ProfileTab: View {
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var viewModel: ProfileSettingsViewModel
    @StateObject private var coupleViewModel: CoupleSpaceViewModel

    init(
        healthDataService: any HealthDataService,
        calendarSyncService: any CalendarSyncService,
        calendarSyncSettings: any CalendarSyncSettingsStore,
        notificationScheduler: any NotificationScheduler,
        coupleSpaceService: any CoupleSpaceService,
        cloudSyncService: any CloudSyncService
    ) {
        _viewModel = StateObject(
            wrappedValue: ProfileSettingsViewModel(
                healthDataService: healthDataService,
                calendarSyncController: DefaultCalendarSyncSettingsController(
                    calendarSyncService: calendarSyncService,
                    settingsStore: calendarSyncSettings
                ),
                notificationController: DefaultNotificationSettingsController(
                    notificationScheduler: notificationScheduler,
                    settingsStore: UserDefaultsNotificationSettingsStore()
                ),
                notificationScheduler: notificationScheduler,
                cloudSyncService: cloudSyncService
            )
        )
        _coupleViewModel = StateObject(
            wrappedValue: CoupleSpaceViewModel(service: coupleSpaceService)
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.xl) {
                    if viewModel.hasLoadedOnce && coupleViewModel.hasLoadedOnce {
                        coupleSection
                        permissionSection
                        privacySection
                        diagnosticsSection
                    } else {
                        SharedLoadingStateView(title: "正在检查权限与同步状态…")
                    }
                }
                .padding(.horizontal, AppSpacing.screenHorizontal)
                .padding(.vertical, AppSpacing.lg)
            }
            .background(AppColorToken.background.color.ignoresSafeArea())
            .navigationTitle("我的")
        }
        .task {
            await refresh()
        }
        .onChange(of: scenePhase) { _, newValue in
            guard newValue == .active else { return }
            Task { await refresh() }
        }
    }

    private var coupleSection: some View {
        CoupleSpaceSection(viewModel: coupleViewModel)
    }

    private var permissionSection: some View {
        SharedCard {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                SharedSectionHeader("权限状态", subtitle: "优先解释用途，再由你主动触发授权")

                SettingsStatusRow(
                    title: "HealthKit",
                    subtitle: healthSummary,
                    tagText: healthStatusText,
                    tagColorToken: healthStatusColorToken,
                    tagSymbolName: healthStatusSymbolName
                ) {
                    Button(healthActionTitle) {
                        Task { await viewModel.requestHealthAuthorization() }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(viewModel.isRequestingHealthAuthorization || viewModel.healthAvailability == .notSupported)
                }

                Divider()

                SettingsStatusRow(
                    title: "EventKit（日历）",
                    subtitle: calendarSummary,
                    tagText: calendarStatusText,
                    tagColorToken: calendarStatusColorToken,
                    tagSymbolName: calendarStatusSymbolName
                ) {
                    Toggle(
                        "系统日历同步",
                        isOn: Binding(
                            get: { viewModel.calendarSyncStatus.isEnabled },
                            set: { enabled in
                                Task { await viewModel.setCalendarSyncEnabled(enabled) }
                            }
                        )
                    )
                    .labelsHidden()
                    .disabled(viewModel.isUpdatingCalendarSync || viewModel.calendarSyncStatus.availability == .notSupported)
                }

                Divider()

                SettingsStatusRow(
                    title: "通知",
                    subtitle: notificationSummary,
                    tagText: notificationStatusText,
                    tagColorToken: notificationStatusColorToken,
                    tagSymbolName: notificationStatusSymbolName
                ) {
                    Button(notificationActionTitle) {
                        Task { await viewModel.requestNotificationAuthorization() }
                    }
                    .buttonStyle(.bordered)
                    .disabled(
                        viewModel.isRequestingNotificationAuthorization ||
                        viewModel.notificationAvailability == .notSupported
                    )
                }

                Divider()

                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    Text("若你想撤销授权或修改系统权限，请前往系统设置中的 CoupleLife。")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColorToken.textSecondary.color)

                    Button("打开系统设置") {
                        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                        openURL(url)
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
    }

    private var privacySection: some View {
        SharedCard {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                SharedSectionHeader("共享与隐私", subtitle: "默认只同步个人 iCloud 数据；共享必须由你显式选择")

                Text("只有任务或记录明确选择共享，且存在活跃情侣空间时，系统才会为伴侣准备可见投影。HealthKit 原始数据、系统日历事件内容和通知偏好仍只保留在你自己的设备或 iCloud。")
                    .font(AppTypography.body)
                    .foregroundStyle(AppColorToken.textSecondary.color)

                SharedTag(text: "默认私有，按条目共享", colorToken: .slate, symbolName: "lock.shield")
            }
        }
    }

    private var diagnosticsSection: some View {
        SharedCard {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                SharedSectionHeader("同步与诊断", subtitle: "同步状态、最近结果与恢复建议都集中放在这里")

                SettingsStatusRow(
                    title: "CloudKit 同步",
                    subtitle: cloudSyncSummary,
                    tagText: cloudSyncStatusText,
                    tagColorToken: cloudSyncStatusColorToken,
                    tagSymbolName: cloudSyncStatusSymbolName
                ) {
                    Button {
                        Task { await viewModel.refreshCloudSync() }
                    } label: {
                        Label(viewModel.isRefreshingCloudSync ? "刷新中…" : "刷新同步状态", systemImage: "arrow.clockwise")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .disabled(viewModel.isRefreshingCloudSync || viewModel.cloudSyncAvailability == .notSupported)
                }

                Divider()

                CloudSyncDiagnosticsPanel(
                    status: viewModel.cloudSyncStatus,
                    hasActiveCoupleSpace: coupleViewModel.status.hasActiveSpace
                )
            }
        }
    }

    private var healthActionTitle: String {
        switch viewModel.healthAvailability {
        case .available:
            return "重新检查授权"
        case .notAuthorized:
            return "连接 HealthKit"
        case .notSupported:
            return "当前不可用"
        case .failed:
            return "重试授权"
        }
    }

    private var healthSummary: String {
        switch viewModel.healthAvailability {
        case .available:
            return "已连接。CoupleLife 仅读取步数与睡眠摘要，不会写回你的健康数据。"
        case .notAuthorized:
            return "尚未授权。点按按钮后再进入系统权限页授权；未授权时不会读取任何健康数据。"
        case .notSupported:
            return "当前设备或环境不支持 HealthKit；模拟器也可能无法返回有效状态。"
        case .failed(let message):
            return message
        }
    }

    private var healthStatusText: String {
        switch viewModel.healthAvailability {
        case .available:
            return "已授权"
        case .notAuthorized:
            return "未授权"
        case .notSupported:
            return "当前环境不可用"
        case .failed:
            return "状态异常"
        }
    }

    private var healthStatusColorToken: AppColorToken {
        switch viewModel.healthAvailability {
        case .available:
            return .green
        case .notAuthorized, .notSupported, .failed:
            return .slate
        }
    }

    private var healthStatusSymbolName: String {
        switch viewModel.healthAvailability {
        case .available:
            return "heart.fill"
        case .notAuthorized:
            return "heart.slash"
        case .notSupported, .failed:
            return "exclamationmark.triangle"
        }
    }

    private var calendarSummary: String {
        switch (viewModel.calendarSyncStatus.isEnabled, viewModel.calendarSyncStatus.availability) {
        case (true, .available):
            return "已同步到系统日历。关闭前不会再新增或更新系统日历事件。"
        case (false, .available):
            return "已获得系统日历权限。只有你手动开启后，任务才会写入默认日历。"
        case (_, .notAuthorized):
            return "未授权时不会写入系统日历；你在开启同步时才会看到系统授权流程。"
        case (_, .notSupported):
            return "当前环境不支持系统日历同步；此开关会保持关闭。"
        case (_, .failed(let message)):
            return message
        }
    }

    private var calendarStatusText: String {
        switch (viewModel.calendarSyncStatus.isEnabled, viewModel.calendarSyncStatus.availability) {
        case (true, .available):
            return "已开启"
        case (false, .available):
            return "已授权，未开启"
        case (_, .notAuthorized):
            return "未授权"
        case (_, .notSupported):
            return "当前环境不可用"
        case (_, .failed):
            return "同步状态异常"
        }
    }

    private var calendarStatusColorToken: AppColorToken {
        switch (viewModel.calendarSyncStatus.isEnabled, viewModel.calendarSyncStatus.availability) {
        case (true, .available):
            return .green
        case (false, .available):
            return .indigo
        case (_, .notAuthorized), (_, .notSupported), (_, .failed):
            return .slate
        }
    }

    private var calendarStatusSymbolName: String {
        switch (viewModel.calendarSyncStatus.isEnabled, viewModel.calendarSyncStatus.availability) {
        case (true, .available):
            return "calendar.badge.checkmark"
        case (false, .available):
            return "calendar.badge.plus"
        case (_, .notAuthorized):
            return "calendar.badge.exclamationmark"
        case (_, .notSupported), (_, .failed):
            return "exclamationmark.triangle"
        }
    }

    private var notificationSummary: String {
        switch viewModel.notificationSettingsStatus.availability {
        case .available:
            switch (viewModel.notificationSettingsStatus.isTaskRemindersEnabled, viewModel.notificationSettingsStatus.isWaterReminderEnabled) {
            case (true, true):
                return "已允许通知，任务提醒和喝水提醒都保持开启。若你刚恢复授权，可前往计划页确认提醒配置。"
            case (true, false):
                return "已允许通知，任务提醒保持开启；喝水提醒关闭。"
            case (false, true):
                return "已允许通知，喝水提醒保持开启；任务提醒关闭。"
            case (false, false):
                return "已允许本地通知，但任务提醒和喝水提醒目前都未开启。"
            }
        case .notAuthorized:
            return "尚未授权通知。若系统权限被撤销，已保存的提醒开关会自动关闭并停止触发。"
        case .notSupported:
            return "当前环境不支持本地通知提醒；计划页中的相关开关会保持禁用。"
        case .failed(let message):
            return message
        }
    }

    private var notificationStatusText: String {
        switch viewModel.notificationSettingsStatus.availability {
        case .available:
            switch (viewModel.notificationSettingsStatus.isTaskRemindersEnabled, viewModel.notificationSettingsStatus.isWaterReminderEnabled) {
            case (true, true):
                return "已授权，2 项提醒开启"
            case (true, false), (false, true):
                return "已授权，1 项提醒开启"
            case (false, false):
                return "已授权，未开启"
            }
        case .notAuthorized:
            return "未授权"
        case .notSupported:
            return "当前环境不可用"
        case .failed:
            return "状态异常"
        }
    }

    private var notificationStatusColorToken: AppColorToken {
        switch viewModel.notificationSettingsStatus.availability {
        case .available:
            return (viewModel.notificationSettingsStatus.isTaskRemindersEnabled || viewModel.notificationSettingsStatus.isWaterReminderEnabled) ? .green : .indigo
        case .notAuthorized, .notSupported, .failed:
            return .slate
        }
    }

    private var notificationStatusSymbolName: String {
        switch viewModel.notificationSettingsStatus.availability {
        case .available:
            return (viewModel.notificationSettingsStatus.isTaskRemindersEnabled || viewModel.notificationSettingsStatus.isWaterReminderEnabled) ? "bell.badge" : "bell"
        case .notAuthorized:
            return "bell.slash"
        case .notSupported, .failed:
            return "exclamationmark.triangle"
        }
    }

    private var notificationActionTitle: String {
        switch viewModel.notificationAvailability {
        case .available:
            return "重新检查授权"
        case .notAuthorized:
            return "允许通知"
        case .notSupported:
            return "当前不可用"
        case .failed:
            return "重试授权"
        }
    }

    private var cloudSyncSummary: String {
        let status = viewModel.cloudSyncStatus

        switch status.availability {
        case .notSupported:
            return "当前环境不支持 CloudKit。请在已登录 iCloud 的真机上重试。"
        case .available:
            let lastSyncText = status.lastSyncAt.map { "最近同步 \(DateFormatter.cloudSyncStatus.string(from: $0))" } ?? "尚未执行同步"
            let summary = status.summary
            return "\(lastSyncText)。本次推送 \(summary.lastPushCount) 条，拉取 \(summary.lastPullCount) 条；个人库 \(summary.privateChangeCount) 条，共享投影 \(summary.sharedChangeCount) 条。"
        case .notAuthorized:
            return "未检测到可用 iCloud 账号或 CloudKit 权限；共享同步不会启动。"
        case .failed(let message):
            return message
        }
    }

    private var cloudSyncStatusText: String {
        switch viewModel.cloudSyncStatus.availability {
        case .notSupported:
            return "当前环境不可用"
        case .available:
            return viewModel.cloudSyncStatus.lastSyncAt == nil ? "可用，待刷新" : "最近已同步"
        case .notAuthorized:
            return "未授权"
        case .failed:
            return "状态异常"
        }
    }

    private var cloudSyncStatusColorToken: AppColorToken {
        switch viewModel.cloudSyncStatus.availability {
        case .available:
            return viewModel.cloudSyncStatus.lastSyncAt == nil ? .indigo : .green
        case .notAuthorized, .notSupported, .failed:
            return .slate
        }
    }

    private var cloudSyncStatusSymbolName: String {
        switch viewModel.cloudSyncStatus.availability {
        case .available:
            return viewModel.cloudSyncStatus.lastSyncAt == nil ? "icloud" : "icloud.and.arrow.up"
        case .notAuthorized:
            return "icloud.slash"
        case .notSupported:
            return "wrench.and.screwdriver"
        case .failed:
            return "exclamationmark.icloud"
        }
    }

    private func refresh() async {
        async let settingsLoad: Void = viewModel.load()
        async let coupleLoad: Void = coupleViewModel.load()
        _ = await (settingsLoad, coupleLoad)
    }
}

private struct CloudSyncDiagnosticsPanel: View {
    let status: CloudSyncStatus
    let hasActiveCoupleSpace: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Text(status.diagnostics.isEmpty ? "同步边界" : "恢复建议")
                .font(AppTypography.body.weight(.semibold))
                .foregroundStyle(AppColorToken.textPrimary.color)

            if status.diagnostics.isEmpty {
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text(syncBoundaryText)
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColorToken.textSecondary.color)
                        .fixedSize(horizontal: false, vertical: true)

                    Text("若多设备不同步，请确认设备已登录 iCloud、网络可用，并返回本页刷新同步状态。")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColorToken.textSecondary.color)
                        .fixedSize(horizontal: false, vertical: true)
                }
            } else {
                ForEach(Array(status.diagnostics.enumerated()), id: \.offset) { _, diagnostic in
                    VStack(alignment: .leading, spacing: AppSpacing.xs) {
                        SharedTag(
                            text: diagnostic.kind.title,
                            colorToken: diagnostic.kind.colorToken,
                            symbolName: diagnostic.kind.symbolName
                        )

                        Text(diagnostic.message)
                            .font(AppTypography.body)
                            .foregroundStyle(AppColorToken.textPrimary.color)
                            .fixedSize(horizontal: false, vertical: true)

                        Text(diagnostic.recoverySuggestion)
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColorToken.textSecondary.color)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }

    private var syncBoundaryText: String {
        if hasActiveCoupleSpace {
            return "已检测到活跃情侣空间。个人库保存完整 canonical 数据；只有显式共享的任务/记录会生成伴侣端可见投影，summaryShared 会隐藏 note、tags、valueText。"
        }

        return "尚未加入情侣空间。CloudKit 刷新只同步你的个人库，不会生成共享投影；加入或创建情侣空间后，共享条目才会进入伴侣可见路径。"
    }
}

private extension CloudSyncDiagnosticKind {
    var title: String {
        switch self {
        case .notAuthorized:
            return "iCloud 未授权"
        case .notSupported:
            return "环境不支持"
        case .noActiveSpace:
            return "无情侣空间"
        case .networkFailure:
            return "网络异常"
        case .serviceFailure:
            return "服务异常"
        }
    }

    var colorToken: AppColorToken {
        switch self {
        case .networkFailure, .serviceFailure:
            return .red
        case .notAuthorized, .notSupported, .noActiveSpace:
            return .slate
        }
    }

    var symbolName: String {
        switch self {
        case .notAuthorized:
            return "icloud.slash"
        case .notSupported:
            return "wrench.and.screwdriver"
        case .noActiveSpace:
            return "person.2.slash"
        case .networkFailure:
            return "wifi.exclamationmark"
        case .serviceFailure:
            return "exclamationmark.icloud"
        }
    }
}

private extension DateFormatter {
    static let cloudSyncStatus: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M月d日 HH:mm"
        return formatter
    }()
}

struct SettingsStatusRow<Trailing: View>: View {
    private let title: String
    private let subtitle: String
    private let tagText: String
    private let tagColorToken: AppColorToken
    private let tagSymbolName: String
    private let trailing: Trailing

    init(
        title: String,
        subtitle: String,
        tagText: String,
        tagColorToken: AppColorToken,
        tagSymbolName: String,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.title = title
        self.subtitle = subtitle
        self.tagText = tagText
        self.tagColorToken = tagColorToken
        self.tagSymbolName = tagSymbolName
        self.trailing = trailing()
    }

    init(
        title: String,
        subtitle: String,
        tagText: String,
        tagColorToken: AppColorToken,
        tagSymbolName: String
    ) where Trailing == EmptyView {
        self.init(
            title: title,
            subtitle: subtitle,
            tagText: tagText,
            tagColorToken: tagColorToken,
            tagSymbolName: tagSymbolName
        ) {
            EmptyView()
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack(alignment: .top, spacing: AppSpacing.md) {
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text(title)
                        .font(AppTypography.body.weight(.semibold))
                        .foregroundStyle(AppColorToken.textPrimary.color)

                    Text(subtitle)
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColorToken.textSecondary.color)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: AppSpacing.md)

                SharedTag(
                    text: tagText,
                    colorToken: tagColorToken,
                    symbolName: tagSymbolName
                )
            }

            trailing
        }
    }
}

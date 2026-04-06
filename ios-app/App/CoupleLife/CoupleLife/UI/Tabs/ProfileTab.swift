import SwiftUI
import UIKit

struct ProfileTab: View {
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var viewModel: ProfileSettingsViewModel

    init(
        healthDataService: any HealthDataService,
        calendarSyncService: any CalendarSyncService,
        calendarSyncSettings: any CalendarSyncSettingsStore,
        notificationScheduler: any NotificationScheduler,
        cloudSyncService: any CloudSyncService
    ) {
        _viewModel = StateObject(
            wrappedValue: ProfileSettingsViewModel(
                healthDataService: healthDataService,
                calendarSyncController: DefaultCalendarSyncSettingsController(
                    calendarSyncService: calendarSyncService,
                    settingsStore: calendarSyncSettings
                ),
                notificationScheduler: notificationScheduler,
                cloudSyncService: cloudSyncService
            )
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.xl) {
                    permissionSection
                    privacySection
                    diagnosticsSection
                }
                .padding(.horizontal, AppSpacing.screenHorizontal)
                .padding(.vertical, AppSpacing.lg)
            }
            .background(AppColorToken.background.color.ignoresSafeArea())
            .navigationTitle("我的")
        }
        .task {
            await viewModel.load()
        }
        .onChange(of: scenePhase) { _, newValue in
            guard newValue == .active else { return }
            Task { await viewModel.load() }
        }
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
                )

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
                SharedSectionHeader("共享与隐私", subtitle: "Phase 2 将补齐伴侣共享控制")

                Text("当前版本不会自动把健康数据、日历内容或通知偏好共享给伴侣。后续会在这里提供共享开关，并明确展示哪些数据会被共享、哪些数据只保留在你的设备或 iCloud。")
                    .font(AppTypography.body)
                    .foregroundStyle(AppColorToken.textSecondary.color)

                SharedTag(text: "Phase 2 占位", colorToken: .slate, symbolName: "lock.shield")
            }
        }
    }

    private var diagnosticsSection: some View {
        SharedCard {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                SharedSectionHeader("同步与诊断", subtitle: "CloudKit 与用户友好诊断将在后续版本补齐")

                SettingsStatusRow(
                    title: "CloudKit 同步",
                    subtitle: cloudSyncSummary,
                    tagText: cloudSyncStatusText,
                    tagColorToken: cloudSyncStatusColorToken,
                    tagSymbolName: cloudSyncStatusSymbolName
                )

                Divider()

                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    Text("诊断入口（占位）")
                        .font(AppTypography.body.weight(.semibold))
                        .foregroundStyle(AppColorToken.textPrimary.color)
                    Text("若后续看到同步失败，这里会把错误转成可执行步骤，例如：检查 iCloud 登录、确认系统日历权限、返回本页刷新状态。当前版本先提供说明，不会误导你已启用云同步。")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColorToken.textSecondary.color)
                }
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
        switch viewModel.notificationAvailability {
        case .notSupported:
            return "当前分支尚未接入提醒能力，这里先展示预留状态，避免误导你已启用通知。"
        case .available, .notAuthorized, .failed:
            return "提醒能力将在后续任务接入；届时这里会显示真实授权状态与提醒范围说明。"
        }
    }

    private var notificationStatusText: String {
        switch viewModel.notificationAvailability {
        case .notSupported:
            return "未接入"
        case .available, .notAuthorized, .failed:
            return "功能预留中"
        }
    }

    private var notificationStatusColorToken: AppColorToken {
        .slate
    }

    private var notificationStatusSymbolName: String {
        "bell.slash"
    }

    private var cloudSyncSummary: String {
        switch viewModel.cloudSyncAvailability {
        case .notSupported:
            return "CloudKit 同步尚未在当前版本接入；本页先保留同步状态与诊断入口位置。"
        case .available:
            return "检测到同步能力可用，但本任务范围内不会启用云同步或诊断流程。"
        case .notAuthorized:
            return "后续如果需要 iCloud 授权，会在这里说明如何开启与关闭。"
        case .failed(let message):
            return message
        }
    }

    private var cloudSyncStatusText: String {
        switch viewModel.cloudSyncAvailability {
        case .notSupported:
            return "未接入"
        case .available:
            return "后续接入"
        case .notAuthorized:
            return "待授权"
        case .failed:
            return "状态异常"
        }
    }

    private var cloudSyncStatusColorToken: AppColorToken {
        switch viewModel.cloudSyncAvailability {
        case .failed:
            return .slate
        case .available:
            return .indigo
        case .notAuthorized, .notSupported:
            return .slate
        }
    }

    private var cloudSyncStatusSymbolName: String {
        switch viewModel.cloudSyncAvailability {
        case .available:
            return "icloud"
        case .notAuthorized:
            return "icloud.slash"
        case .notSupported, .failed:
            return "wrench.and.screwdriver"
        }
    }
}

private struct SettingsStatusRow<Trailing: View>: View {
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

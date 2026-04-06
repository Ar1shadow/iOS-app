# 710 本地通知调度 v1

- 状态: Done
- 最后更新: 2026-04-06

- Phase: Phase 1 (MVP)
- 模块: Integrations
- 依赖: 110、500
- 目标: 实现本地通知能力，覆盖任务提醒与基础健康/习惯提醒（如喝水提醒），支持创建/更新/取消并提供权限引导。
- 非目标: 不做推送通知；不做复杂的智能提醒规则（后续 Phase 3）。

## 交付物

- `NotificationScheduler` 默认实现：按任务截止时间/自定义时间调度通知
- 权限引导与设置入口：显示当前授权状态与引导文案
- 基础策略：通知重复/覆盖规则清晰（避免重复堆叠）

## 验收标准

- 用户允许通知后，提醒能按预期触发；关闭后不再触发
- 更新任务时间会更新对应提醒（不残留旧通知）
- 未授权时 UI 有清晰降级说明

## 实施要点

- 将通知与业务模型解耦：只依赖必要字段（id、时间、标题、类型）
- 为后续“共享任务提醒”预留扩展点（Phase 2）
- 数据路径：Planning/Profile View -> ViewModel/SettingsController -> NotificationScheduler -> UNUserNotificationCenter
- 权限与降级：Profile 负责展示授权状态与授权入口；Planning 中提醒开关在未授权/不可用时保持清晰降级文案，关闭时清理待触发提醒
- MVP 策略：任务提醒与喝水提醒默认关闭；同一业务提醒使用稳定 identifier 覆盖旧请求，避免重复堆叠

## Skills 使用

- `$xcode-simulator-debug`: 用于排查通知权限、Simulator 行为差异与调度逻辑；适用于“构建/运行 + 日志定位”。

## 实施记录

- 已实现 `UserNotificationScheduler`，通过稳定 identifier 覆盖任务提醒与喝水提醒，支持授权请求、创建、更新、取消与批量清理。
- `DefaultPlanningTaskService` 在任务创建/更新/完成/取消/删除后做最佳努力通知联动；通知失败不会阻断任务 CRUD。
- `ProfileTab` 展示真实通知授权状态并提供授权入口，`PlanningTab` 增加任务提醒/喝水提醒开关与未授权降级文案。
- 后续修正：Profile 加载时会通过 `NotificationSettingsController.currentStatus()` 自动对齐已存提醒开关，系统权限被撤销后无需进入 Planning 也会关闭失效开关并取消待触发提醒。
- 后续修正：任务提醒相关异步调度在 `Task` 内再次检查设置开关，避免用户快速关闭提醒后仍继续调度旧通知。

## 验证记录

- `cd ios-app/App/CoupleLife && xcodegen generate`
- `cd ios-app/App/CoupleLife && xcodebuild test -project CoupleLife.xcodeproj -scheme CoupleLife -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.6'`
- 结果：115 个测试全部通过；新增通知设置控制器、调度器适配层、任务服务通知规则、Profile 授权入口与权限撤销回归测试均通过。

## 已知风险/遗留

- 已完成命令行与单元测试验证，但本次未做真机通知到达手测；仍需在真机上确认授权弹窗、后台投递时机与系统设置跳转体验。

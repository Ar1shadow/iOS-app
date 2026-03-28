# 700 EventKit 单向同步（任务 -> 系统日历）v1

- Phase: Phase 1 (MVP)
- 模块: Integrations
- 状态: In Progress
- 最后更新: 2026-03-28
- 依赖: 110、500
- 目标: 基于 EventKit 实现“应用任务 -> 系统日历事件”的单向同步，建立任务与系统事件的映射关系，并提供最小的开关与失败策略。
- 非目标: 不做双向同步（系统事件 -> 任务）作为默认；不让任务模型与日历事件强耦合。

## 交付物

- `CalendarSyncService` 的 EventKit 实现：创建/更新/删除 EKEvent
- 映射策略：`Task.linkedCalendarEventId`（或单独映射表）用于追踪对应关系
- 权限与开关：用户明确开启后才写入系统日历

## 验收标准

- 开启同步后，新建/更新/删除任务会正确反映到系统日历（至少在可验证环境下）
- 未授权时不会崩溃，并能给出清晰提示与降级（不写入）
- 同步方向清晰：首期以“应用 -> 系统”优先，减少冲突复杂度

## 实施要点

- 权限申请与功能触发解耦：不要在首屏自动弹权限
- 删除策略：删除任务时明确“保留/删除”系统事件的行为（按产品选择最小复杂度）

## Skills 使用

- `$xcode-simulator-debug`: 用于排查 EventKit 权限、运行时异常与构建日志；适用于“系统 API 接入的可复现排障”。

## 实施记录

- 开工: 2026-03-28
- 进展:
  - 已扩展 `CalendarSyncService` 协议，并新增 `EventKitCalendarSyncService`，将 EventKit 访问限制在 `CoupleLife/Integrations/Calendar/`。
  - 已新增 `UserDefaultsCalendarSyncSettingsStore` 与 `DefaultCalendarSyncSettingsController`，显式控制“是否开启系统日历同步”与按需权限申请。
  - 已在 `DefaultPlanningTaskService` 中接入单向同步：创建、更新、状态变更、删除任务时，按当前开关和权限状态尝试写入或删除系统日历事件；同步失败不阻塞 CRUD。
  - 删除策略已定为“删除任务时同时删除已关联的系统日历事件”；若系统事件已丢失或无权限，任务删除仍继续。
  - 已在 Planning Tab 增加最小同步入口，展示开启状态、授权状态与降级提示；SwiftUI 视图本身不直接调用 EventKit。
- 权限策略:
  - 首屏不自动触发权限弹窗。
  - 用户在 Planning Tab 显式开启同步时，才调用 EventKit 写权限请求。
  - 未授权、受限、失败、无可写默认日历时，只降级为“不写入系统日历”，不影响任务 CRUD。
  - 当同步开关关闭时，所有系统日历写操作都停止，包括删除任务时的系统事件删除。
- 数据契约:
  - 继续使用 `TaskItem.systemCalendarEventId` 作为任务与系统事件的稳定映射。
  - EventKit 映射仅在 Integration 层内部完成，UI 和仓储层不依赖 `EKEvent`。
  - 本地仓储持久化优先于系统日历写入；创建/更新后的事件标识通过后续 best-effort `taskRepository.update` 回写，删除任务则先删本地任务再 best-effort 删除系统事件。
  - 任务取消排期时，只有系统事件删除成功或事件已不存在时才清空 `systemCalendarEventId`；删除失败时保留映射以便后续重试。
- 下一步:
  - 在可访问 CoreSimulator 的环境中运行 `xcodebuild test`，验证 EventKit 权限路径与测试结果。
  - 在真机上手动验证系统日历写入与删除行为。

## 验证记录

- 命令:
  - `cd ios-app/App/CoupleLife && xcodegen generate`
  - `cd ios-app/App/CoupleLife && xcodebuild build -project CoupleLife.xcodeproj -scheme CoupleLife -sdk iphonesimulator -derivedDataPath /tmp/CoupleLife-task700-build`
  - `cd ios-app/App/CoupleLife && xcodebuild test -project CoupleLife.xcodeproj -scheme CoupleLife -destination 'platform=iOS Simulator,OS=18.6,name=iPhone 16' -derivedDataPath /tmp/CoupleLife-task700-test`
- 结果:
  - `xcodegen generate` 已通过。
  - 非提权的 `xcodebuild build/test` 会被当前 sandbox 限制阻断，无法作为最终验证结论。
  - 提权后，`xcodebuild test -project CoupleLife.xcodeproj -scheme CoupleLife -destination 'platform=iOS Simulator,OS=18.6,name=iPhone 16' -derivedDataPath /tmp/CoupleLife-task700-test` 已通过。
  - 提权后，`xcodebuild test -project CoupleLife.xcodeproj -scheme CoupleLife -destination 'platform=iOS Simulator,OS=18.6,name=iPhone 16' -derivedDataPath /tmp/CoupleLife-task700-review-full` 已通过，`57` 个测试全部成功。

## 可复现验证步骤

1. 运行 `cd ios-app/App/CoupleLife && xcodegen generate` 生成最新工程。
2. 运行 `cd ios-app/App/CoupleLife && xcodebuild test -project CoupleLife.xcodeproj -scheme CoupleLife -destination 'platform=iOS Simulator,OS=18.6,name=iPhone 16' -derivedDataPath /tmp/CoupleLife-task700-test`。
3. 启动 App，进入 Planning Tab，确认默认看到“未授权/未开启”的同步提示，且没有自动弹权限。
4. 手动开启“系统日历同步”，确认此时才触发系统权限申请。
5. 授权后新建一个带日期的任务，确认系统默认日历出现对应事件。
6. 编辑该任务的标题或时间，确认系统日历事件同步更新。
7. 删除该任务，确认系统日历中的对应事件被删除。
8. 关闭同步或拒绝权限后重复创建任务，确认任务仍可保存，但不会写入系统日历。

## 已知风险/遗留

- EventKit 在模拟器和真机上的权限弹窗、默认日历可用性、事件标识稳定性可能不同，最终行为需以真机验证为准。
- 当前使用 `NSCalendarsWriteOnlyAccessUsageDescription` 与 iOS 17+ 写权限 API；若未来下探系统版本，需要重新评估授权 API 和 Info.plist 键。
- 未排期任务不会写入系统日历；若已同步任务后续移除日期，仅在同步开关仍开启时才会主动删除系统事件映射。

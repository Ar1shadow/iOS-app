# 500 任务系统 v1

- Phase: Phase 1 (MVP)
- 模块: Planning
- 依赖: 200、210、300
- 状态: Done
- 最后更新: 2026-03-28
- 目标: 实现最小可用的任务系统：创建、完成、延期、取消，并支持日/周/月/年层级的基础组织。
- 非目标: 不实现完整子任务树与复杂重复规则（先占位字段即可）；不实现双向日历同步（见 700）。

## 交付物

- 任务列表与新增/编辑入口（MVP 字段集）
- 任务状态流转：todo -> done / postponed / canceled
- 层级字段：`planLevel`（日/周/月/年）用于筛选与视图组织

## 验收标准

- 任务的创建与状态更新会即时反映到 UI
- 不同层级的任务能被正确筛选与展示
- 数据结构为后续 EventKit 映射与情侣共享预留字段（但不强制实现）

## 实施要点

- 状态与优先级优先做枚举而不是散落字符串
- 先做“日计划”体验再补齐周/月/年筛选，避免一次堆太多 UI
- 数据路径：`PlanningTab/ViewModel -> PlanningTaskService -> TaskRepository -> SwiftData`
- 降级路径：加载失败显示错误空态；无任务显示引导空态；延期无日期时仅更新状态并保留可编辑入口

## Skills 使用

- `$swiftui-feature-builder`: 用于快速落地任务列表与编辑表单；适用于“列表 + 表单 + 状态流转”。

## 实施记录

- 已将 `PlanningTab` 从占位页替换为真实任务流：列表按 `planLevel` + 状态筛选展示，支持新增/编辑表单与行内完成、延期、取消操作。
- 新增 `DefaultPlanningTaskService` 与 `PlanningViewModel`，把创建、更新、延期和状态变更逻辑从 SwiftUI 视图中移出，并通过 `RootTabView` 注入 `TaskRepository`。
- 已补齐 `TaskStatus.postponed`、`TaskRepository.update(_:)` 以及对应单元测试，确保状态流转会持久化并更新 `updatedAt/version`。
- 根据代码评审补充状态流转约束：新任务固定从 `todo` 创建，编辑表单不再允许任意改写状态，领域服务只允许 `todo/postponed -> done/postponed/canceled`，非法流转会返回用户可见错误。
- 修复 Home 聚合回归：`postponed` 任务重新纳入首页 important events/upcoming 聚合，避免延期任务从首页消失。

## 验证记录

- `cd ios-app/App/CoupleLife && xcodegen generate`
- `cd ios-app/App/CoupleLife && xcodebuild -project CoupleLife.xcodeproj -scheme CoupleLife -destination 'platform=iOS Simulator,id=5EF18BBB-1C49-45C8-BBD4-A831BDDA53B6' -derivedDataPath /tmp/CoupleLifeDerivedData500-green CODE_SIGNING_ALLOWED=NO test -only-testing:CoupleLifeTests/TaskRepositoryTests -only-testing:CoupleLifeTests/PlanningTaskServiceTests`
- `xcodebuild -project ios-app/App/CoupleLife/CoupleLife.xcodeproj -scheme CoupleLife -destination 'platform=iOS Simulator,id=5EF18BBB-1C49-45C8-BBD4-A831BDDA53B6' -derivedDataPath /tmp/CoupleLifeDerivedData500-review-green CODE_SIGNING_ALLOWED=NO test -only-testing:CoupleLifeTests/PlanningTaskServiceTests -only-testing:CoupleLifeTests/HomeDashboardServiceTests`
- `xcodebuild -project ios-app/App/CoupleLife/CoupleLife.xcodeproj -scheme CoupleLife -destination 'platform=iOS Simulator,id=5EF18BBB-1C49-45C8-BBD4-A831BDDA53B6' -derivedDataPath /tmp/CoupleLifeDerivedData500 CODE_SIGNING_ALLOWED=NO test`
- 结果：36 个测试全部通过；新增验证覆盖仓储更新、任务加载排序、空标题失败路径、延期状态与日期推进逻辑，以及状态流转约束和首页延期任务聚合回归。

## 已知风险/遗留

- 本任务按 MVP 实现筛选与单层任务编辑，不扩展子任务树、重复规则与日历双向同步。
- 仍需在真机或 Simulator 手测 `PlanningTab` 的按钮密度、动态字体与长文本场景；本次验证以单元测试和编译级集成为主。

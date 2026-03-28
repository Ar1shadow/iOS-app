# 400 日历视图与日期导航 v1

- Phase: Phase 1 (MVP)
- 模块: Calendar
- 状态: Done
- 最后更新: 2026-03-28
- 依赖: 300、200（至少需要日期与记录类型的展示语义）
- 目标: 落地月/周/日的基础日历导航体验，支持选择日期进入“某天详情”。
- 非目标: 不在本任务实现记录的新增/编辑（见 410）；不做复杂的统计标记与预测。

## 交付物

- 月视图：可切换月份、选中某天
- 周/日视图：可查看更密集的日程与记录摘要（先 MVP）
- 从日历进入某天详情页的导航链路（详情页可先占位，410 补齐内容）

## 验收标准

- 日期选择与切换稳定，跨月/跨周逻辑清晰
- UI 状态明确（选中态、今日标记、记录标记占位）
- 日历视图的结构可扩展（后续加入记录标记、双人视角、合并视图）

## 实施要点

- 先保证“选日期 -> 进详情”闭环，再迭代展示细节
- 为未来双人视角预留：同一天可能展示“我/TA/我们”的摘要信息入口

## 实施记录

- `RootTabView` 现已向 `CalendarTab` 注入 `RecordRepository`；`CalendarTab` 替换为真实月/周/日导航 UI，并接入某天详情占位页。
- 新增纯 `CalendarMonthGridBuilder` 与 `CalendarRecordSummaryService`，分别负责月网格生成与可见范围记录标记/日摘要聚合。
- 日历状态保持在本地 `CalendarViewModel`，覆盖选中日期、周期切换、加载失败降级与快速切换下的请求竞态保护。
- 已修复月末跨月漂移：`CalendarViewModel` 现保留 `anchoredDayOfMonth`，月切换按目标月份可用天数稳定回落，不再出现 `1/31 -> 2/29 -> 1/29` 的回退漂移。
- 已补充可取消的 `reloadTask` 调度，避免快速切换时排队启动多次摘要加载；月/周日期按钮也补齐了 VoiceOver 的日期、选中态、今日与记录标记语义。

## 验证记录

- 已执行：`cd ios-app/App/CoupleLife && xcodegen generate`
- 已执行：`xcodebuild -project ios-app/App/CoupleLife/CoupleLife.xcodeproj -scheme CoupleLife -destination 'platform=iOS Simulator,id=5EF18BBB-1C49-45C8-BBD4-A831BDDA53B6' -derivedDataPath /tmp/CoupleLifeDerivedData400 CODE_SIGNING_ALLOWED=NO test`
- 已验证：18 个 XCTest 全部通过；新增月导航漂移回归测试与加载失败降级测试通过。

## 已知风险/遗留

- 本次仅完成命令行测试，尚未在 Simulator 内逐路径手点验证月/周/日切换动画、VoiceOver 朗读与不同地区首周设置的视觉表现。

## Skills 使用

- `$swiftui-feature-builder`: 用于搭建日历 UI 的状态流与导航；适用于“复杂布局 + 多状态页面”。
- `$swiftui-ui-refactor`: 用于拆分日历组件（网格、顶部控件、周/日切换）；适用于“降低 `body` 复杂度”。

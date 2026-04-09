# 1000 本周生活洞察 v1

- Phase: Phase 3 (数据洞察)
- 模块: Home
- 状态: Done
- 最后更新: 2026-04-09
- 依赖: 350、400、410、500、510、600、610
- 目标: 在首页聚合任务、记录、健康缓存，展示本周生活洞察卡。
- 非目标: 不做 AI 文案生成；不做跨周/月复杂趋势图；不做 CloudKit 共享规则变更。

## 交付物

- 首页新增“本周洞察”卡片，展示任务完成、记录活跃天数、高频记录、累计步数、平均睡眠。
- `HomeDashboardSummary` 新增 `HomeDashboardWeeklyInsight`，聚合逻辑仍位于 Domain Service。
- 测试覆盖周区间、owner 过滤、记录类型统计、健康快照汇总。

## 验收标准

- 本周无数据时首页展示清晰空态，不崩溃。
- 本周有任务/记录/健康缓存时，洞察卡展示正确聚合值。
- 统计只使用当前 `ownerUserId` 的数据，不混入伴侣或他人记录。
- 不改动 CloudKit 写入、共享投影和隐私策略。

## 实施要点

- 周区间使用 `Calendar.dateInterval(of: .weekOfYear, for:)`，与用户当前日历设置保持一致。
- 记录活跃天数按记录开始时间归一到自然日后去重。
- 健康数据只读 `.day` bucket 缓存：步数求和，睡眠按有值天数求平均。

## Skills 使用

- `$subagent-driven-development`: 用 explorer 并行确认 Phase 3 切入点与依赖。
- `$build-ios-apps:swiftui-ui-patterns`: 用于在现有 `HomeTab` 中按项目约定新增 SwiftUI 卡片。
- `$caveman`: 压缩过程汇报。

## 实施记录

- 开工: 2026-04-09
- 完成: 扩展 `DefaultHomeDashboardService`，生成本周任务/记录/健康洞察。
- 完成: 首页新增“本周洞察”卡片，复用既有 `SharedCard`、`SharedSectionHeader`、`metricView` 与 record type visual style。
- 下一步: Phase 3 可继续拆月报、趋势对比、跨模块关联分析。

## Definition of Done

- 首页洞察卡片完成并可在无数据/有数据路径渲染。
- 领域服务测试覆盖 owner 过滤、周区间和健康快照汇总。
- 验证命令通过，任务索引已更新。

## 验证记录

- 命令: `xcodebuild test -quiet -project ios-app/App/CoupleLife/CoupleLife.xcodeproj -scheme CoupleLife -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.6' -derivedDataPath /tmp/CoupleLifeDerivedData-task1000 -only-testing:CoupleLifeTests/HomeDashboardServiceTests -only-testing:CoupleLifeTests/HomeDashboardViewModelTests`
- 结果: 通过，exit code 0；仅有既有重复 simulator destination warning。
- 命令: `xcodebuild test -quiet -project ios-app/App/CoupleLife/CoupleLife.xcodeproj -scheme CoupleLife -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.6' -derivedDataPath /tmp/CoupleLifeDerivedData-task1000-full`
- 结果: 通过，exit code 0；仅有既有重复 simulator destination warning。
- 手测: 未做真机手测。
- 遗留风险: 当前仅做本周摘要，不做长期趋势和个性化建议；健康洞察依赖缓存快照，缓存缺失时不会主动拉取 HealthKit 历史数据。

## 执行规范

- 见 `workflow.md`。

# 1010 本月趋势洞察 v1

- Phase: Phase 3 (数据洞察)
- 模块: Home
- 状态: Done
- 最后更新: 2026-04-13
- 依赖: 350、1000
- 目标: 在首页聚合本月任务、记录、健康缓存，并与上月对比（步数/睡眠）展示趋势卡片。
- 非目标: 不做 AI 文案生成；不做跨月复杂趋势图；不做 HealthKit 历史回填与长期分析。

## 交付物

- `HomeDashboardSummary` 扩展 `monthlyInsight: HomeDashboardMonthlyInsight`，并纳入 `hasAnyData`。
- `DefaultHomeDashboardService` 计算月区间与上月区间，聚合本月任务/记录/健康快照，并输出步数与睡眠的环比 delta。
- 首页新增“本月趋势”卡片：任务完成、活跃天数、累计步数与 delta、平均睡眠与 delta。
- 单元测试覆盖月聚合、owner 过滤、步数/睡眠 delta 计算。

## 验收标准

- 本月无数据时，卡片展示清晰空态，不崩溃。
- 本月有数据时，聚合值与 delta 显示正确。
- 统计只使用当前 `ownerUserId` 的数据（records 需手动过滤）。

## 实施要点

- 月区间使用 `Calendar.dateInterval(of: .month, for:)`。
- 上月区间使用 `monthRange.start` 回退一个月后再取 `dateInterval(of: .month, for:)`，避免月末天数差异导致不稳。
- 健康数据仅使用 `.day` bucket 缓存：步数求和；睡眠按有值天数求平均（小时，保留 1 位小数）。

## 实施记录

- 开工: 2026-04-13
- 完成: 新增 `HomeDashboardMonthlyInsight`，并在 `DefaultHomeDashboardService` 聚合本月/上月数据与 delta。
- 完成: `HomeTab` 新增“本月趋势”卡片，保持与“本周洞察”一致的 `SharedCard`/`SharedSectionHeader`/`metricView`/`SharedTag` 风格。

## Definition of Done

- 单元测试通过：`HomeDashboardServiceTests`、`HomeDashboardViewModelTests`。
- 核心逻辑最小可用，未引入额外依赖或跨模块改动。

## 验证记录

- 命令: `xcodebuild test -quiet -project ios-app/App/CoupleLife/CoupleLife.xcodeproj -scheme CoupleLife -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.6' -derivedDataPath /tmp/CoupleLifeDerivedData-task1010 -only-testing:CoupleLifeTests/HomeDashboardServiceTests -only-testing:CoupleLifeTests/HomeDashboardViewModelTests`
- 结果: 通过，exit code 0；仅有既有重复 simulator destination warning。

## 执行规范

- 见 `workflow.md`。


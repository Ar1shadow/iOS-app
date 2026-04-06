# 610 运动健康仪表盘 v1

- Phase: Phase 1 (MVP)
- 模块: Fitness
- 依赖: 600、300
- 状态: Done
- 最后更新: 2026-04-06
- 目标: 实现健康数据展示页，支持日/周/月切换，展示步数、距离、能量、站立、运动时长、心率、睡眠摘要等首期指标。
- 非目标: 不做情侣对比视图（后续 Phase 2/3）；不做深度健康洞察（Phase 3）。

## 交付物

- 仪表盘页面：指标卡片 + 趋势图（折线/柱状图按 MVP）
- 权限引导：未授权/不可用时的说明与入口
- 数据来源标记：区分系统同步与手动录入（若首期不支持手动录入，也要预留语义）

## 验收标准

- 切换日/周/月不会触发明显卡顿或重复大量读取
- 数据为空或不可用时展示清晰空态而不是空白
- 样式与 SharedUI 一致，卡片信息层级清楚

## 实施要点

- 仪表盘优先读缓存 `HealthMetricSnapshot`，必要时后台刷新
- 图表实现先统一容器与数据适配层，再迭代视觉细节
- `day/week/month` 控制当前汇总 bucket，趋势图分别展示最近 7 天、8 周、6 个月的历史序列
- 先补 `HealthSnapshotRepository` 范围查询，切换粒度只读 SwiftData 缓存，不在切换时重复触发 HealthKit 读取

## 实施记录

- 已实现 `FitnessTab` 仪表盘：日/周/月切换、权限引导、步数趋势图、健康指标卡片与来源标记
- 扩展 `HealthSnapshotRepository` 范围查询；Dashboard 先读 SwiftData 缓存，首次进入仅在日缓存缺失或过期时后台刷新
- 新增 Fitness domain/presentation 层与测试，切换粒度只切本地状态，不重复触发 HealthKit 读取

## 验证记录

- 已执行：`cd ios-app/App/CoupleLife && xcodegen generate`
- 已执行：`xcodebuild test -project CoupleLife.xcodeproj -scheme CoupleLife -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.6'`
- 已覆盖：缓存范围查询、趋势序列补齐、ViewModel 的缓存优先/按需刷新/切换粒度不触发刷新；模拟器环境下全量测试 80 项通过
- 待真机手测：HealthKit 授权弹窗、真实缓存刷新、未授权到已授权的 UI 切换

## 已知风险/遗留

- 当前 HealthKit 集成仍只稳定填充步数、睡眠、静息心率；距离、能量、运动、站立在页面中明确展示“暂无数据”
- 趋势图当前只绘制步数缓存，后续若补齐更多指标缓存，需要扩展适配层而不是直接把图表逻辑塞回 View

## Skills 使用

- `$swiftui-feature-builder`: 用于快速实现“卡片 + 图表 + 多时间粒度切换”的页面；适用于“仪表盘型 UI”。
- `$ios-liquid-glass`: 用于运动卡片层次与材质处理（若作为试点页面）；适用于“玻璃风格但保持对比度”。
- `$ios-performance-audit`: 用于定位图表与滚动掉帧、重绘、图片/路径绘制等热点；适用于“渲染性能问题”。

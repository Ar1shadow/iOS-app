# 1020 跨模块关联分析 v1

- Phase: Phase 3 (数据洞察)
- 模块: Home
- 状态: Done
- 最后更新: 2026-04-13
- 依赖: 350、400、410、500、510、600、610、1000、1010
- 目标: 在首页提供轻量的跨模块关联提示，帮助用户理解任务、记录与健康指标之间的可能关联（不做因果结论）。
- 非目标: 不做复杂统计建模；不做个性化推荐引擎；不做长时间窗多变量回归；不引入外部分析服务。

## 交付物

- 首页新增“关联提示”区域（或卡片），从以下信号中输出 1-3 条短提示（可为空）：
  - 任务完成天数/完成率 vs 记录活跃天数
  - 步数水平 vs 睡眠水平（基于缓存快照）
  - 记录类型偏好变化（例如高频从 water 转为 sleep）
- 规则为可解释的启发式（threshold-based），并明确“不代表因果”。
- 测试覆盖：阈值边界、空数据降级、owner 过滤。

## 验收标准

- 数据不足时不强行输出提示，不误导；页面稳定不崩溃。
- 提示内容可解释、可复现，同一输入稳定输出。
- 只使用当前 `ownerUserId` 的数据。

## 实施要点

- 首版优先使用周/月聚合结果（复用 1000/1010 的聚合），避免重复扫库。
- 每条提示必须能追溯到一个明确的阈值或规则。
- 文案避免因果表述：用“可能/倾向/在本周（本月）观察到”。
- 首版规则（v1，最多输出 3 条，按顺序挑选，满足才输出）：
  - 任务完成率高但记录少：`weekly.totalTaskCount >= 5` 且 `weekly.completed/total >= 0.8` 且 `weekly.activeDayCount <= 1`
  - 记录很勤但任务完成率低：`weekly.totalTaskCount >= 5` 且 `weekly.completed/total <= 0.4` 且 `weekly.activeDayCount >= 4`
  - 活动量与睡眠组合提示：当 `weekly.totalSteps != nil` 且 `weekly.averageSleepHours != nil` 时，满足任一：
    - `weekly.totalSteps >= 45000` 且 `weekly.averageSleepHours < 7.0`
    - `weekly.totalSteps <= 20000` 且 `weekly.averageSleepHours >= 8.0`
  - 高频记录偏好变化：`weekly.dominantRecordType` 与 `monthly.dominantRecordType` 均非空且不同。

## Skills 使用

- `$subagent-driven-development`: 分规则实现与测试，逐条验收。

## 实施记录

- 开工: 2026-04-13
- 进展: 已在 `HomeDashboardSummary` 增加 `correlationHints`，并按 v1 阈值生成最多 3 条提示；Home 新增“关联提示”卡片；补齐 XCTest 覆盖 Rule 1/Rule 4/多规则顺序。
- 下一步: 无。

## Definition of Done

- 规则集可配置、可测试；空数据/边界数据覆盖。
- 验证命令通过；任务文档补齐验证与遗留风险。

## 验证记录

- 命令: `cd ios-app/App/CoupleLife && xcodebuild test -quiet -project CoupleLife.xcodeproj -scheme CoupleLife -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.6' -derivedDataPath /tmp/CoupleLifeDerivedData-task1020 -only-testing:CoupleLifeTests/HomeDashboardServiceTests -only-testing:CoupleLifeTests/HomeDashboardViewModelTests`
- 结果: 2026-04-13 通过（退出码 0）
- 手测: 未做（本任务为规则与展示卡片，优先用 XCTest 覆盖）
- 遗留风险: 规则为启发式阈值，提示文本已注明“不代表因果”；后续如规则增多需回补更全面的边界测试。

## 执行规范

- 见 `workflow.md`。

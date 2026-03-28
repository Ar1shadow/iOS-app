# 510 计划视图与筛选 v1

- Phase: Phase 1 (MVP)
- 模块: Planning
- 依赖: 500、300
- 状态: Done
- 最后更新: 2026-03-28
- 目标: 提供“计划视图”和“列表视图”的切换，并实现按日/周/月/年层级的筛选与分组展示。
- 非目标: 不做统计分析、完成率报表（见 Phase 3）；不做模板计划（未来扩展）。

## 交付物

- 两种展示模式：计划视图（按层级对应周期分组：日按日期、周按周、月按月、年按年；All 时附加“未排期”）与列表视图（保留状态分组 + 快捷操作）
- 筛选与分组：按 `planLevel`、状态、日期范围（All / Today / Next 7 / Next 30 / Custom）
- 交互一致性：与 Calendar/SharedUI 的组件风格一致，切换视图不重置现有筛选状态

## 验收标准

- 视图切换不会丢失筛选条件或导致状态错乱
- 日期范围过滤按 `dueAt ?? startAt` 生效，Custom 使用起止日期边界
- 数据量增大时仍可用（最少保证不明显卡顿）

## 实施要点

- 优先实现“过滤与分组”的清晰语义，再考虑更复杂的拖拽/排序
- 计划视图按 `selectedPlanLevel` 对应的周期分桶，递增排序；`All` 时允许显示“未排期”
- 需要性能优化时，以测量驱动（见 960）

## Skills 使用

- `$swiftui-feature-builder`: 用于实现视图切换与筛选 UI；适用于“多状态切换型页面”。
- `$swiftui-ui-refactor`: 当筛选与视图逻辑开始膨胀时用于拆分与收敛；适用于“保持页面可维护”。
- `$ios-performance-audit`: 当过滤/分组导致列表渲染开销明显时用于定位热点；适用于“滚动掉帧与重渲染”。

## 实施记录

- `PlanningViewModel` 新增 `displayMode`、`dateRangeFilter` 与自定义日期起止状态，筛选顺序固定为 `planLevel -> status -> date range`，切换视图不会重置现有筛选。
- `PlanningTab` 新增“计划视图 / 列表视图”切换、日期范围筛选与自定义日期选择；列表视图保留原有状态分组 + 行内快捷操作，计划视图按 `planLevel` 对应周期分组展示。
- `PlanningDisplaySupport` 统一补充任务计划日期语义（`dueAt ?? startAt`），并保留 Planning 相关标题映射，减少视图里散落的格式化逻辑。
- 新增 `PlanningViewModelTests` 覆盖计划视图分组、Custom 日期范围边界、Today 预设范围，以及视图切换时筛选状态保持不变。

## 验证记录

- 已执行：`cd ios-app/App/CoupleLife && xcodegen generate`
- 已执行：`cd ios-app/App/CoupleLife && xcodebuild -project CoupleLife.xcodeproj -scheme CoupleLife -destination 'platform=iOS Simulator,id=5EF18BBB-1C49-45C8-BBD4-A831BDDA53B6' -derivedDataPath /tmp/CoupleLifeDerivedData510-focused CODE_SIGNING_ALLOWED=NO test -only-testing:CoupleLifeTests/PlanningViewModelTests -only-testing:CoupleLifeTests/PlanningTaskServiceTests`
- 已执行：`cd ios-app/App/CoupleLife && xcodebuild -project CoupleLife.xcodeproj -scheme CoupleLife -destination 'platform=iOS Simulator,id=5EF18BBB-1C49-45C8-BBD4-A831BDDA53B6' -derivedDataPath /tmp/CoupleLifeDerivedData510 CODE_SIGNING_ALLOWED=NO test`
- 已执行：`cd ios-app/App/CoupleLife && xcodebuild -project CoupleLife.xcodeproj -scheme CoupleLife -destination 'platform=iOS Simulator,id=5EF18BBB-1C49-45C8-BBD4-A831BDDA53B6' -derivedDataPath /tmp/CoupleLifeDerivedData510-full CODE_SIGNING_ALLOWED=NO test`
- 结果：45 个测试全部通过；新增验证覆盖计划视图按层级周期分组、All/Today/Custom/Next 7 日期范围语义、未排期任务显示规则，以及筛选状态在视图切换中的保持行为。

## 已知风险/遗留

- 本任务按 MVP 实现筛选与单层任务分组，不扩展拖拽排序、统计分析与模板计划。
- 本次验证以单元测试和编译级集成为主；仍建议在 Simulator 中手测长文案、动态字体和大量任务下的视觉表现。

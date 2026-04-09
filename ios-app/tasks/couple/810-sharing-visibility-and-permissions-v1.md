# 810 共享可见性与敏感数据边界 v1

- Phase: Phase 2 (情侣共享)
- 模块: Couple
- 状态: Done
- 最后更新: 2026-04-09
- 依赖: 800、200
- 目标: 落地数据可见性规则与 UI（private/shared/仅汇总共享/完全共享），尤其对月经/排便/睡眠等敏感数据提供明确边界。
- 非目标: 不做复杂权限策略引擎；不做默认全量共享。

## 交付物

- `visibility` 的规则定义：默认 private，用户显式选择后才共享
- 敏感类型策略：允许“仅汇总共享”与“完全共享”的差异（按产品取最小可行实现）
- UI 入口：在记录/任务创建与详情中可设置可见性，并提供解释文案

## 验收标准

- 敏感数据不会在未明确授权的情况下对伴侣可见
- 用户能理解当前共享范围（UI 上有可解释的提示）
- 共享策略的落点集中，不散落在多个页面的临时 if/else 中

## 实施要点

- 把共享策略收敛到 Domain 层（规则集中），Presentation 层只展示与调用
- 后续 CloudKit 同步只同步“允许共享的数据”（与 720 对齐）

## Skills 使用

- `$swiftui-feature-builder`: 用于实现可见性设置的 UI 与解释文案；适用于“设置型控件落地”。
- `$swiftui-ui-refactor`: 用于把散落的共享判断收敛成明确的状态与规则入口；适用于“保持行为一致的结构整理”。

## 实施记录

- 开工: 2026-04-09
- 进展: 新增集中式 `VisibilityPolicy`，把任务与记录的共享规则、选项标题、说明文案、非法值净化逻辑与“共享给伴侣时的字段投影”统一收敛到 Domain 层。
- 进展: 记录流改为按类型动态提供可见性选项；`menstruation`、`bowelMovement`、`sleep` 支持“仅汇总共享”，其余记录与任务仅支持“仅自己可见 / 完全共享”。
- 进展: `PlanningTaskDraft`、`DefaultPlanningTaskService`、`DefaultCalendarDayRecordService` 与对应表单已接入规则；补齐共享策略测试与任务文档回填。
- 下一步: 进入 720 前复用当前 policy 决定“哪些数据允许进入 CloudKit 私有库/共享库”，避免在同步层重复判断。

## 验证记录

- 命令: `xcodebuild test -quiet -project ios-app/App/CoupleLife/CoupleLife.xcodeproj -scheme CoupleLife -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.6'`
- 手测: 未做 Simulator 交互手测；已通过表单与 service 层代码检查确认记录创建/编辑、任务创建/编辑均接入统一 policy。
- 遗留风险: `summaryShared` 的共享投影与本地预览已落地，但真正跨设备同步到共享库、以及伴侣端读取该投影，仍需在 720 CloudKit/共享视图链路中接入。

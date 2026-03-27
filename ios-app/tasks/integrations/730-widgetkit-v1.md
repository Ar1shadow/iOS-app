# 730 WidgetKit 小组件 v1

- Phase: Phase 4 (生态增强)
- 模块: Integrations
- 依赖: 500、600、300（按组件内容不同）
- 目标: 增加基础 Widget：今日任务、今日步数、纪念日倒计时，形成 Apple 生态增强体验。
- 非目标: 不做 Apple Watch 配套（另拆任务）；不做 Live Activities（另拆任务）。

## 交付物

- Widget Extension：Timeline Provider + SwiftUI widget UI
- 首期组件：
  - 今日任务摘要（数量/最近一条）
  - 今日步数摘要（或活动能量）
  - 纪念日倒计时（来自 CoupleSpace 或设置）
- 刷新策略：频率、占位、无权限/无数据降级

## 验收标准

- 组件能在桌面正确显示并按策略更新
- 无权限/无数据时仍有明确展示，不出现空白
- 与 SharedUI 保持风格一致（在 Widget 能力允许范围内）

## 实施要点

- 组件数据来源优先复用现有缓存/仓储接口，避免 Widget 内做重负载查询
- 明确隐私边界：Widget 展示内容避免泄露敏感记录细节（尤其在锁屏/桌面场景）

## Skills 使用

- `$swiftui-feature-builder`: 用于快速搭建 Widget UI 与状态分支（占位/空/有数据）；适用于“Widget 视图落地”。
- `$xcode-simulator-debug`: 用于排查 extension 构建、运行、预览与 scheme/destination；适用于“Widget 开发排障”。


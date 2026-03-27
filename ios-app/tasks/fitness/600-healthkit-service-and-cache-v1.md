# 600 HealthKit 服务与缓存 v1

- Phase: Phase 1 (MVP)
- 模块: Fitness / Integrations
- 依赖: 110、200、210
- 目标: 建立 `HealthDataService`，按需申请权限并读取首期健康指标，同时落地展示缓存 `HealthMetricSnapshot` 以减少频繁查询开销。
- 非目标: 不做完整 Workout 体系；不一次申请过多权限；不把 HealthKit API 直接暴露给 UI。

## 交付物

- 权限策略：按需申请（步数/睡眠/心率等首期指标），并明确失败/未授权的 UI 语义
- 读取与映射：把 HealthKit 数据映射为内部 metric 模型
- 缓存策略：按 day/week/month bucket 写入 `HealthMetricSnapshot`（仅用于展示）

## 验收标准

- 未授权时页面不会崩溃，且能清晰提示用户如何开启
- 有权限时可以读取到数据（HealthKit 更可靠的验收通常需要真机）
- 缓存减少重复读取，且缓存失效策略明确（例如按天刷新）

## 实施要点

- Simulator 能力限制：HealthKit 数据在模拟器上不一定完整，需准备“无数据/不可用”的降级路径
- 读写边界：缓存写入在 Data 层，UI 通过仓储读缓存，不直接调用 HealthKit

## Skills 使用

- `$xcode-simulator-debug`: 用于排查权限弹窗、运行时崩溃与构建问题；适用于“系统能力接入的排障”。
- `$ios-performance-audit`: 用于验证缓存策略是否有效，以及定位读取/解码/渲染带来的卡顿；适用于“性能测量与优化”。


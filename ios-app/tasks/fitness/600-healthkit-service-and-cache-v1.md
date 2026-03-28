# 600 HealthKit 服务与缓存 v1

- Phase: Phase 1 (MVP)
- 模块: Fitness / Integrations
- 状态: Done
- 最后更新: 2026-03-28
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

## 实施记录

- 开工: 2026-03-28
- 进展:
  - 扩展 `HealthDataService` 为“显式授权 + 手动刷新今日缓存”最小契约；HealthKit 访问集中在 `Integrations/HealthKit/HealthKitHealthDataService.swift`。
  - 首页继续只读 `HealthSnapshotRepository` 缓存；`HomeDashboardViewModel` 负责显式触发授权/刷新，不在 SwiftUI View 中直接调用 HealthKit。
  - `HealthMetricSnapshot` 增加 `HealthMetricBucket`，仓储按 `(bucket, bucketStart, ownerUserId)` 查询与 upsert，避免 day/week/month 快照冲突。
  - 首期读取指标覆盖步数、睡眠、静息心率；刷新今日时同步维护 day/week/month 三个展示快照。
  - `availabilityStatus()` 仅依赖 `getRequestStatusForAuthorization` 判定是否可尝试读取，避免把 HealthKit 的 share/write 授权误当作 read 授权。
  - 真正的读取拒绝在 `readMetrics(...)` 查询阶段识别；若 HealthKit 返回 `authorizationDenied`，`refreshTodaySnapshot` 会回落为 `.notAuthorized`，而不是误报一般失败。
  - 工程新增 `CoupleLife.entitlements`，并通过 `CODE_SIGN_ENTITLEMENTS` 接入 app target，补齐最小 HealthKit capability 配置。
  - 模拟器显式走降级路径：`LiveHealthKitClient` 在 simulator 返回不可用，避免依赖不稳定的模拟器 HealthKit 数据与 entitlement 环境。
- 下一步:
  - 真机补齐 HealthKit capability / entitlement 后验证真实授权弹窗、步数/睡眠读取与缓存刷新。

## 关键决策

- 权限策略：不在 app launch 自动弹框；仅用户点击首页“连接健康数据”时请求步数、睡眠、静息心率读取权限。
- 可用态判定：`availability` 只表达“当前可以尝试发起读取请求”；`getRequestStatusForAuthorization == .unnecessary` 时返回 `.available`，不额外伪造 read 授权判断。
- 缓存策略：`refreshTodaySnapshot` 默认按“同一天仅刷新一次”命中 day cache；命中失效后同次刷新内一起重建 day/week/month 三个 bucket，缓存写入仍在 Data 层仓储中完成。
- 降级策略：未授权显示引导文案；模拟器/无能力环境显示 `notSupported`；真机 capability 缺失视为环境风险，不向 UI 泄漏 HealthKit 细节。

## 验证记录

- 命令:
  - `xcodegen generate --spec ios-app/App/CoupleLife/project.yml`
  - `xcodebuild build-for-testing -project ios-app/App/CoupleLife/CoupleLife.xcodeproj -scheme CoupleLife -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/task-600-deriveddata`
  - `xcodebuild test -project ios-app/App/CoupleLife/CoupleLife.xcodeproj -scheme CoupleLife -destination 'id=5EF18BBB-1C49-45C8-BBD4-A831BDDA53B6' -derivedDataPath /tmp/task-600-deriveddata -only-testing:CoupleLifeTests/HealthKitHealthDataServiceTests`
  - `xcodebuild test -project ios-app/App/CoupleLife/CoupleLife.xcodeproj -scheme CoupleLife -destination 'id=5EF18BBB-1C49-45C8-BBD4-A831BDDA53B6' -derivedDataPath /tmp/task-600-deriveddata`
- 结果:
  - `build-for-testing` 通过。
  - `HealthKitHealthDataServiceTests` 定向通过，覆盖“`.unnecessary` => `.available`”以及“读取期 `authorizationDenied` => `.notAuthorized`”路径。
  - `xcodebuild test` 全量通过：53 tests, 0 failures。
  - 额外观察：entitlement 已进入模拟器签名产物，但 HealthKit 真正授权与数据可用性仍需真机 capability / App ID 配置共同满足。

## 已知风险/遗留

- 仓库已签入 `com.apple.developer.healthkit` entitlement，但真机仍需在 Apple Developer App ID / provisioning profile 侧同步开启 HealthKit capability。
- 当前 v1 已覆盖 day/week/month bucket 与步数、睡眠、静息心率；距离/卡路里/锻炼分钟等其余指标仍待后续任务扩展。
- HealthKit 真机验收仍需补“已授权/拒绝后去设置开启/当天无数据”三条手测路径。

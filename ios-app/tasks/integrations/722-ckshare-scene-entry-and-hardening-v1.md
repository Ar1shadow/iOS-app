# 722 CKShare Scene 入口与接受链路加固 v1

- Phase: Phase 2 (情侣共享)
- 模块: Integrations
- 状态: Done
- 最后更新: 2026-04-14
- 依赖: 721
- 目标: 把 CKShare 接受共享的系统入口（Scene running + cold launch）做对，并优先使用系统提供的 share metadata 直接 accept；同时收紧 share URL 校验与 availability 语义，让诊断更稳定。
- 非目标: 不做完整产品级共享 UX；不做 CKShare 创建/撤销/重邀（另拆 723）；不要求在 Simulator 上完成真实 iCloud 接受（以编译/逻辑/诊断可用为主）。

## 交付物

- UIKit lifecycle（AppDelegate + SceneDelegate）承载 SwiftUI root，保证拿到 Scene 回调。
- Scene-based CKShare 入口：
  - `scene(_:willConnectTo:options:)` 处理 `connectionOptions.cloudKitShareMetadata`（冷启动）
  - `windowScene(_:userDidAcceptCloudKitShareWith:)`（运行/挂起态）
  - `scene(_:openURLContexts:)`（URL fallback）
- 接受共享流程：
  - metadata 路径：直接 accept（不再丢弃系统 metadata 再用 URL 反查）
  - URL 路径：保留（fetch metadata -> accept），用于手动输入与无 metadata 场景
- 校验与语义：
  - share URL 本地校验：scheme/host + path 形状（`/share/<token>`），输出稳定错误码
  - CloudKit availability：把 transient/unknown 状态映射为 `.failed(...)`，避免误判为未授权

## 验收标准（CI 可跑）

- `cd ios-app/App/CoupleLife && xcodegen generate` 成功
- `cd ios-app/App/CoupleLife && xcodebuild test`（Simulator）成功
- 单测覆盖：
  - URL 校验新增 path 分支（例如 `unsupported_path`/`missing_token`）
  - 状态机分支（processing/accepted/failed/not_authorized）仍保持可测
- 编译门禁：CloudKit 相关实现均在 `canImport(CloudKit)` 下可编译；无 CloudKit 环境下优雅降级

## 实施要点

- 入口迁移：从 SwiftUI `@main App` 迁到 UIKit `AppDelegate + SceneDelegate`，SceneDelegate 用 `UIHostingController` 承载 `RootTabView`。
- 入口归一：SceneDelegate 收到 metadata/URL 后只负责路由到 use case；CloudKit 调用与状态推进在 service/client 内封装。
- 诊断刷新：接受流程完成后发 `CloudShareNotifications.acceptanceDidUpdate`，Profile 监听刷新状态。

## 实施记录

- 开工: 2026-04-14
- 完成: UIKit lifecycle（AppDelegate + SceneDelegate）承载 SwiftUI root；补齐 CKShare metadata 的 cold launch + running 入口；accept 优先走 metadata；URL 校验收紧并补齐单测。
- 下一步: 如需真机联调，再拆 723/724（创建 share、双端邀请/接受、schema/容器排障与诊断固化）。

## Definition of Done

- Scene-based metadata 入口（cold + running）已接入并能触发接受流程（至少推进到 `.processing`，失败也有稳定错误码）
- URL 校验收紧并有单测覆盖
- `xcodegen generate` + `xcodebuild test` 可复现通过
- 任务文件回填验证记录与已知风险/遗留

## 验证记录

- `cd ios-app/App/CoupleLife && xcodegen generate`
- 结果: ✅ 2026-04-14 通过
- `cd ios-app/App/CoupleLife && xcodebuild test -quiet -project CoupleLife.xcodeproj -scheme CoupleLife -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.6' -derivedDataPath /tmp/CoupleLifeDerivedData-task722-2`
- 结果: ✅ 2026-04-14 通过（exit 0；有既有重复 destination warning）

## 已知风险/遗留

- metadata 路径在 XCTest 中无法方便构造真实 `CKShare.Metadata`；以编译与真机联调为主验证，URL 路径继续保持单测覆盖。
- 真机 iCloud 双端联调仍是后续关键路径（见 723/724）。

## 执行规范

- 见 `workflow.md`（任务状态流转、回填规则、最小增量原则）

# 723 CKShare 创建/邀请/撤销/重邀最小闭环 v1

- Phase: Phase 2 (情侣共享)
- 模块: Integrations
- 状态: Todo
- 最后更新: 2026-05-08
- 依赖: 720、721、722、800、810
- 目标: 落地“当前用户作为 share owner，从 App 内创建 CKShare、生成邀请链接、撤销 share、对单个 participant 重邀”的最小闭环；与 722 的接受链路打通，形成 owner ↔ participant 双端可观测的 share 生命周期。
- 非目标: 不做产品级共享 UX（头像、邀请人选择器美化等）；不做多 share 合并/转移所有权；不做共享数据的字段级权限再细分（沿用 810 的可见性规则）。

## 交付物

- CKShare 创建管道（最小可编译/可测试结构）：
  - `CloudShareInvitationService`（或同等职责）封装“为指定共享根记录（CoupleSpace 根 zone/记录）创建 CKShare -> 持久化 share recordID -> 生成 `UICloudSharingController` 可消费的 share 对象 / share URL”。
  - 通过协议注入 `CloudKitShareInvitationClient`，CI 单测以 fake client 驱动状态机；真实实现走 `CKContainer.privateCloudDatabase` + `CKModifyRecordsOperation`。
- 邀请入口（最小 UI）：
  - Profile「同步与诊断」中新增“创建/管理共享”入口；首期承载 `UICloudSharingController`（系统弹窗）走通分享。
  - 创建成功后展示 share URL（可复制），失败展示稳定错误码。
- 撤销与重邀：
  - `revokeShare()`：删除当前 CKShare 记录，回退到“未共享”状态；保留诊断中“lastRevokeAt / lastErrorCode”。
  - `reinvite(participant:)`：对单个 participant 重新发出邀请（删除 + 重新加入或调用 `add(_:)`，按 CK 行为决定）；首期允许“整 share 撤销 + 重新创建”作为 fallback。
- 状态与诊断：
  - 扩展 `CloudShareInvitationStatus`：`idle / creating / active(shareURL) / revoking / revoked / failed(code)` + `lastUpdatedAt`。
  - Profile 页展示当前 share 状态、participant 列表占位（最少 owner + 受邀者数量），并提供“撤销 / 重邀 / 复制诊断信息”操作。

## 验收标准（CI 可跑 + 真机分级）

- 构建与测试（CI 必须）：
  - `cd ios-app/App/CoupleLife && xcodegen generate` 成功
  - `xcodebuild test`（Simulator）成功；新增单测覆盖：
    - 创建状态机（`idle -> creating -> active`、失败映射稳定错误码）
    - 撤销状态机（`active -> revoking -> revoked`，失败回退到 `active` 或 `failed`）
    - 重邀路径至少有一个分支（成功 / 失败）的可断言行为
- 编译门禁：所有 CKShare 创建相关实现均在 `canImport(CloudKit)` 下；非 CloudKit 环境优雅降级为 `.unavailable`。
- 真机行为（接 724 联调，本任务只要求“可触达”）：
  - 设备 A 在 App 内创建 share，能拿到 share URL 并通过系统分享面板发送
  - 设备 B 通过 722 入口接受 share，状态推进到 `accepted`
  - 设备 A 撤销 share 后，设备 B 再次打开链接进入 `failed(...)` 且诊断有稳定错误码

## 实施要点

- 共享根的选择：与 720 的 `CloudSyncScope.shared` 对齐 —— 把 CoupleSpace 根记录作为 share root，`CKShare.RootRecord` = couple space record；其它共享对象通过 parent reference 归属到该 root，避免多 share 切碎。
- 调用边界：
  - 创建 / 撤销 / 重邀全部通过 service 层走，View 只触发意图 + 显示状态。
  - `UICloudSharingController` 作为首期 UI 容器，但其 share 生成 / 完成回调统一汇聚到 `CloudShareInvitationService`，保证状态机单一事实源。
- 错误码语义：
  - 创建失败：`.notAuthorized` / `.networkUnavailable` / `.containerNotAvailable` / `.unknown(...)`
  - 撤销失败：`.shareNotFound` / `.networkUnavailable` / `.unknown(...)`
- 与 721/722 的协同：
  - 接受端状态推进保持 722 的 `CloudShareAcceptanceStatus` 不变；本任务新增 `CloudShareInvitationStatus`，二者通过 `CloudShareNotifications` 解耦。
  - Profile 设置页同时展示“我作为发起方 (invitation) / 我作为接受方 (acceptance)”两条状态线，避免互相覆盖。

## Skills 使用

- `$build-ios-apps:swiftui-feature-builder`: 创建 / 管理共享的最小 UI 入口。
- `$xcode-simulator-debug`: CKShare 创建错误（entitlements / container / schema）排障；与 724 的真机联调记录互相支撑。

## 实施记录

- 开工: <YYYY-MM-DD>
- 进展: <1-3 行>
- 下一步: <1 行>

## Definition of Done

- 创建 / 撤销 / 重邀 三条路径均能在单测中复现并断言到状态机
- Profile 页能展示发起方状态、share URL 与撤销/重邀入口
- `xcodegen generate` + `xcodebuild test` 可复现通过
- 任务文件回填验证记录与已知风险/遗留
- 真机闭环验证（owner 创建 → participant 接受 → owner 撤销 → participant 失败）至少跑通一次（与 724 联调）

## 验证记录

- 命令: `cd ios-app/App/CoupleLife && xcodegen generate`
- 命令: `cd ios-app/App/CoupleLife && xcodebuild test -quiet -project CoupleLife.xcodeproj -scheme CoupleLife -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.6'`
- 手测: 待补（接 724 真机联调记录）
- 遗留风险: 待补

## 已知风险/遗留

- `UICloudSharingController` 在 iOS 17+ 行为细节（`itemProvider` 与 share completion）需要在真机验证；首期允许仅落 share URL 复制路径作为 fallback。
- 重邀语义：CK 不区分“重新邀请同一 participant”，可能需要 revoke + recreate；对外语义需在文档中对齐。
- Schema 部署：share root record type 必须在 CloudKit Console 部署到 Production 才能在真机看到；联调前确认（见 724）。

## 执行规范

- 见 `workflow.md`（任务状态流转、回填规则、最小增量原则）

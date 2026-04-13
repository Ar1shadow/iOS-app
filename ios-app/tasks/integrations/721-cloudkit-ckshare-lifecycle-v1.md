# 721 CloudKit CKShare 生命周期 v1

- Phase: Phase 2 (情侣共享)
- 模块: Integrations
- 状态: In Progress
- 最后更新: 2026-04-13
- 依赖: 720、900（以及 800/810 的共享边界约定）
- 目标: 落地 CKShare 邀请/接受的最小生命周期“可跑通管道 + 可观测诊断”，重点覆盖“通过 URL 接受共享”并在设置页展示状态，确保后续真机双端联调有抓手。
- 非目标: 不做完整产品级共享 UX；不做复杂 share 管理（撤销/重邀/多 share 合并等）；不把共享范围扩展到多实体全量同步（保持 720 的最小共享边界）。

## 交付物

- 共享邀请入口（最小）：
- 支持通过 `onOpenURL` 接收 share URL（Universal Link / 自定义 scheme 二选一即可，优先按当前工程实际配置）
- 可选：在“我的/设置/同步与诊断”提供一个手动输入 share URL 的诊断入口（便于无 Universal Link 环境下联调）
- CKShare 接受管道（最小可编译/可测试结构）：
- `CloudShareAcceptanceService`（或同等职责）封装“解析 URL -> 拉取 share metadata -> accept shares -> 更新状态/错误语义”的流程
- 通过协议注入 `CloudKitShareClient`（或同等抽象）以支持 XCTest 单测（CI 侧不依赖真实 iCloud）
- 诊断与状态展示：
- 扩展现有 `CloudSyncStatus`/诊断模型，新增“共享邀请/接受”维度（例如：idle / processing / accepted / failed + lastURL/lastErrorCode/lastUpdatedAt）
- Profile 设置页在“同步与诊断”区展示该状态，并提供“复制诊断信息/重试”类的最小操作（不追求美观）

## 验收标准（尽可能 CI 可验证）

- 构建与测试（CI 可跑）：
- `ios-app/App/CoupleLife` 下 `xcodegen generate` 成功
- `xcodebuild test`（Simulator）成功，且新增单测覆盖 share URL 解析与状态机（不触达真实 CloudKit 网络）
- 编译门禁：所有 CloudKit 相关实现均在 `canImport(CloudKit)` 条件下可编译；在不支持 CloudKit 的 target/环境下能优雅降级（例如返回 `.unavailable`）
- 行为（可在 Simulator/CI 验证到逻辑层）：
- 给定合法 share URL：路由能进入“接受共享”流程并把状态推进到 `.processing`
- 给定不合法/不支持 URL：立即失败并记录可诊断的错误码（例如 `.invalidURL` / `.unsupportedURLHost`）
- 失败时不崩溃：错误被映射为稳定的诊断语义，设置页能展示“失败原因 + 建议动作”（文本即可）

## 实施要点

- 共享边界（本任务只做诊断展示，不扩展同步面）：
- 明确本任务只解决“能接受共享 + 能看到状态/错误”，共享库里实际读写/同步对象仍按 720 的 `CloudSyncScope.shared` 最小范围执行
- 若现有实现尚未区分“共享库可用但未加入 share/未接受邀请”等状态，需要把该差异编码进诊断语义（避免把“没有 share”误判为“同步失败”）
- URL 处理策略：
- `onOpenURL` 入口只负责“记录 URL + 触发 use case”，不直接做 CloudKit 调用（避免 UI 线程/生命周期耦合）
- 对 URL 进行严格校验与归一化（例如只接受 `https://icloud.com/share/...` 或预期 host/path；具体白名单按实际 CloudKit 分享链接格式落地）
- CloudKit 抽象与可测性：
- CloudKit 的 `CKContainer`/`CKAcceptSharesOperation` 等 API 通过薄封装层隔离，单测通过 fake client 驱动状态机
- 所有状态推进都必须可在单测里复现（成功/失败/重试幂等）

## Skills 使用

- `$xcode-simulator-debug`: 用于排查 share URL 入口、entitlement/capability、CloudKit 运行时错误与设备联调；适用于“CloudKit 分享生命周期调试”。

## 实施记录

- 开工: 2026-04-13
- 进展: 已定义 CKShare 接受链路的最小交付物/验收标准与真机验证清单（本任务文档落地）。
- 下一步: 先补齐 URL 路由与状态模型骨架并加上单测（CI 可跑），再接入设置页诊断展示与最小重试入口；真机可用时按“设备验证清单”走一遍，补齐实际 share 链接格式白名单与错误映射。

## Definition of Done

- 任务文件回填“验证记录”（至少包含可复制的 `xcodebuild` 命令）与“已知风险/遗留”（若仍依赖真机）
- Share URL 入口（`onOpenURL` 或手动输入）可触发接受流程，且状态在设置页可见
- 新增 XCTest 覆盖 URL 解析与状态机分支（成功/失败/不支持）

## 验证记录

- CI/Simulator（必须可复现）：
- `cd ios-app/App/CoupleLife && xcodegen generate`
- `cd ios-app/App/CoupleLife && xcodebuild test -project CoupleLife.xcodeproj -scheme CoupleLife -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.6'`
- 真机/iCloud（需要设备与 Apple ID，具备后再补）：
- 前置条件: 真机登录 iCloud；App 启用 CloudKit capability；CloudKit container/schema 已部署；两端设备使用不同 Apple ID（邀请/接受更贴近真实）
- 验证步骤:
- 设备 A 获取 share 邀请 URL（来源可以是后续“创建 share”调试入口或外部工具/示例工程）
- 设备 B 打开 share URL（Safari/消息）并跳转到 App（Universal Link 或复制到手动输入框）
- App 显示“processing -> accepted/failed”，并在设置页记录 lastUpdatedAt/lastErrorCode
- 若失败: 记录系统错误码与建议动作（例如重新登录 iCloud、检查网络、检查 container、检查 schema 部署）

## 执行规范

- 见 `workflow.md`（任务状态流转、回填规则、最小增量原则）

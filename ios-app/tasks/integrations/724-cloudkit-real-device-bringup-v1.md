# 724 真机 iCloud 双端联调与 CloudKit Schema 部署/排障流程 v1

- Phase: Phase 2 (情侣共享)
- 模块: Integrations / Quality
- 状态: Todo
- 最后更新: 2026-05-08
- 依赖: 720、721、722、723
- 目标: 把 CKShare owner ↔ participant 的端到端流程在真机 iCloud 环境跑通一次，并把“CloudKit container/schema 部署 + 常见错误诊断”流程文档化，让后续 CKShare/CloudKit 相关任务有可复现的排障基线。
- 非目标: 不做新功能；不重写 720/721/722/723 的实现；不覆盖商店发布前的 Production CK schema 全量审计（按需另拆）。

## 交付物

- 真机联调记录（写入本任务文件）：
  - 设备 A（owner）+ 设备 B（participant）至少跑通一次完整链路：创建 share -> 发送邀请 -> 接受 -> 双端可见共享数据 -> 撤销 -> 接受端可观察到失败
  - 每一步记录命令/操作、设备状态、CK 容器使用的 environment（Development/Production）、entitlement、Apple ID
- 排障 Playbook（新增到 `ios-app/tasks/quality/` 或在本任务文件内成段）：
  - CloudKit Console schema 部署步骤（Development -> Production）
  - 常见错误码与处置：`partialFailure` / `notAuthenticated` / `serverRecordChanged` / `participantAlreadyInvited` / `quotaExceeded` 等
  - Universal Link / share URL host 校验在真机上的实际表现（icloud.com vs www.icloud.com）
  - 真机日志抓取流程（Xcode Console / `os_log` 过滤）
- 诊断补强（按需，最小增量）：
  - Profile「同步与诊断」补充“当前 CK environment / container ID / iCloud account state”只读展示
  - `CloudShareNotifications` 与 invitation/acceptance 状态机在真机日志可识别（统一前缀 / category）

## 验收标准

- CI 不退化：
  - `cd ios-app/App/CoupleLife && xcodegen generate` 成功
  - `xcodebuild test`（Simulator）通过
- 真机（必须）：
  - 至少一次完整 owner ↔ participant 闭环（按上述链路）有截图或日志记录
  - 至少覆盖一次失败路径（如撤销后 participant 重试），并记录错误码
- 文档（必须）：
  - 本任务文件“验证记录”包含可复现操作步骤与命令
  - 排障 Playbook 至少覆盖 5 个常见 CK 错误的解释与处置

## 实施要点

- Container / Environment：
  - 联调使用 Development 环境；Production 部署只在“能复现且 stable”后再做
  - 所有共享相关 record type / index 必须先在 Development 部署后再到 Production
- 双 Apple ID：
  - owner 与 participant 必须使用不同 Apple ID，否则 CK 不会真正走 share
  - 测试前确认两端 iCloud Drive / iCloud 账户登录正常，无“需要再次登录”提示
- 失败优先：
  - 优先记录失败链路（哪一步出错、错误码、屏幕截图、设备日志），让后续问题可定位
  - 把 transient 错误（网络/账户漂移）与配置错误（schema/entitlement/container）区分清楚
- Entitlements 检查清单：
  - `com.apple.developer.icloud-services`（CloudKit）
  - `com.apple.developer.icloud-container-identifiers`（容器一致）
  - `com.apple.developer.ubiquity-kvstore-identifier`（如使用）
  - Background Modes: Remote notifications（CKShare 邀请通知通常依赖 push）

## Skills 使用

- `$xcode-simulator-debug`: 真机 + Simulator 排障（运行/测试/签名/CK 错误）
- `$build-ios-apps:ios-debugger-agent`: 真机日志、截图、复现路径捕获

## 实施记录

- 开工: <YYYY-MM-DD>
- 进展: <1-3 行>
- 下一步: <1 行>

## Definition of Done

- 真机闭环跑通一次并记录在“验证记录”中
- 至少一次失败路径与错误码已捕获并归类
- 排障 Playbook 章节覆盖 ≥ 5 个常见 CK 错误
- 任务文件回填“验证记录”“已知风险/遗留”
- 关键诊断信息（CK environment / container / 账户状态）在 App 内可读

## 验证记录

- 命令: `cd ios-app/App/CoupleLife && xcodegen generate`
- 命令: `cd ios-app/App/CoupleLife && xcodebuild test -quiet -project CoupleLife.xcodeproj -scheme CoupleLife -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.6'`
- 真机:
  - 设备 A: <型号 / iOS 版本 / Apple ID 后缀>
  - 设备 B: <型号 / iOS 版本 / Apple ID 后缀>
  - 步骤: 待联调时填写（创建 -> 邀请 -> 接受 -> 撤销）
  - 截图/日志位置: 待补
- 遗留风险: 待补

## 已知风险/遗留

- 真机联调强依赖 Apple ID 与 iCloud 状态，若 CI 无法持续复现，则文档化“最近一次成功联调”作为基线。
- CK Production schema 部署是单向操作，需在确认 Development 流程稳定后再切。
- Universal Link 的 host/path 在真实 share URL 中可能与文档不一致，以实测为准并回填到 722 的 URL 校验。

## 执行规范

- 见 `workflow.md`（任务状态流转、回填规则、最小增量原则）

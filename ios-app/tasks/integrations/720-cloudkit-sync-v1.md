# 720 CloudKit 同步与共享 v1

- Phase: Phase 2 (情侣共享)
- 模块: Integrations
- 状态: Done
- 最后更新: 2026-04-09
- 依赖: 800、810、200、210
- 目标: 基于 CloudKit 实现个人数据与共享数据的同步，落地情侣共享空间的数据边界、冲突处理与同步状态展示。
- 非目标: 不考虑跨平台后端；不一次支持过多实体的全量复杂同步（按 MVP 共享范围逐步扩展）。

## 交付物

- CloudKit 分库策略：个人数据使用私有数据库，共享数据使用共享数据库
- 同步对象：共享任务、共享记录（按产品选择最小集合），以及相关权限字段
- 冲突策略：用 `updatedAt/version/source` 等字段做最小可解释的合并策略
- 同步状态：在“我的/设置”提供同步状态与诊断入口（与 900 联动）

## 验收标准

- 两端设备在相同 Apple ID/共享空间条件下可同步到共享数据
- 冲突场景有可解释的结果（不 silent overwrite 且不丢数据）
- 未登录/不可用/网络异常时 UI 有明确提示与降级

## 实施要点

- 先定义“共享范围与权限规则”，再实现同步（避免把不确定的产品规则写死在同步层）
- 同步层不直接耦合 UI：对外暴露同步状态与错误语义即可

## Skills 使用

- `$xcode-simulator-debug`: 用于排查 CloudKit 权限、容器配置、运行时错误与构建问题；适用于“系统云能力接入排障”。
- `$swiftui-feature-builder`: 用于实现同步状态/共享开关等设置 UI；适用于“与同步层交互的页面落地”。

## 实施记录

- 开工: 2026-04-09
- 进展: 已完成 810，可直接复用 `VisibilityPolicy` 决定哪些任务/记录进入私有库或共享库，以及 `summaryShared` 的共享投影。
- 完成: 新增 `CloudSyncStatus`、诊断模型、双 scope 同步 payload、route planner、冲突 resolver、SwiftData source/sink 与 `DefaultCloudSyncService`。
- 完成: `CloudKitCloudSyncClient` 接入 CloudKit account status、私有库/共享库 fetch/save 路径，并按 `CloudSyncScope` 写入 private/shared database。
- 完成: Profile 同步诊断区从占位文案改为真实状态、刷新动作、最近同步摘要与恢复建议。
- 完成: 增加 CloudKit capability/entitlement，并在 SwiftData `ModelContainer` 中显式关闭自动 CloudKit mirroring，避免当前 schema 触发 SwiftData 自动同步约束崩溃。
- 完成: `summaryShared` 只推共享摘要投影；私有库保留完整 canonical 记录；无激活情侣空间时只推私有库。

## 验证记录

- 命令: `xcodebuild build-for-testing -quiet -project ios-app/App/CoupleLife/CoupleLife.xcodeproj -scheme CoupleLife -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/CoupleLifeDerivedData-task720`
- 结果: 通过，exit code 0。
- 命令: `xcodebuild test -quiet -project ios-app/App/CoupleLife/CoupleLife.xcodeproj -scheme CoupleLife -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.6' -derivedDataPath /tmp/CoupleLifeDerivedData-task720 -only-testing:CoupleLifeTests/CloudSyncRoutePlannerTests -only-testing:CoupleLifeTests/CloudSyncConflictResolverTests -only-testing:CoupleLifeTests/DefaultCloudSyncServiceTests -only-testing:CoupleLifeTests/ProfileSettingsViewModelTests`
- 结果: 通过，exit code 0。
- 命令: `xcodebuild test -quiet -project ios-app/App/CoupleLife/CoupleLife.xcodeproj -scheme CoupleLife -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.6' -derivedDataPath /tmp/CoupleLifeDerivedData-final`
- 结果: 通过，exit code 0；仍有既有 warning：widget extension `CFBundleVersion` 与宿主 app 不一致。
- 手测: 未做真机/iCloud 双端联调。
- 遗留风险: 真机 iCloud 账号、CloudKit schema 部署、共享库 zone/邀请关系仍需设备联调；当前验证覆盖代码路径、权限降级、路由、冲突与本地投影规则。

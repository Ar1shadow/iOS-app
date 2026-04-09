# 900 设置、隐私与权限状态 v1

- 状态: Done
- 最后更新: 2026-04-09
- Phase: Phase 1 (MVP) + Phase 2 增量
- 模块: Profile
- 依赖: 110（服务协议）、700/710/600（若已接入则展示状态）
- 目标: 在“我的”页面提供权限状态、隐私配置、同步状态与诊断入口，让用户能理解数据去向并可撤销授权/共享。
- 非目标: 不做复杂账号管理；不做完整数据导出 UI（可先占位说明，后续补齐）。

## 交付物

- 权限状态：HealthKit / EventKit / 通知 的当前状态与引导入口
- 隐私配置：共享相关开关与解释（Phase 2 与 810/720 联动）
- 同步状态：CloudKit 同步状态与错误诊断入口（Phase 2）

## 验收标准

- 用户可以在一个地方看到权限与同步状态，不需要到处找入口
- 未接入的能力有明确占位与说明，不误导用户已启用
- 敏感数据的共享边界有清晰说明

## 实施要点

- 不要在设置页触发大量系统弹窗；优先“解释 + 明确按钮触发”
- 诊断信息对用户友好：错误要能转化为可行动的步骤

## Skills 使用

- `$swiftui-feature-builder`: 用于实现设置页的分组与状态展示；适用于“信息密集但需清晰层级的页面”。
- `$xcode-simulator-debug`: 用于排查权限/设置跳转/构建与运行时问题；适用于“系统能力联动排障”。

## 实施记录

- 已用 `ProfileSettingsViewModel` 替换 Profile 占位页：集中加载 HealthKit / EventKit / 通知 / CloudKit 状态，并提供显式授权与系统设置入口。
- 已复用 `DefaultCalendarSyncSettingsController` 处理日历同步开关，设置页文案与状态标签与现有 Planning 同步模式保持一致。
- 已补齐 “共享与隐私” / “同步与诊断” Phase 2 占位说明，明确当前分支未接入通知与 CloudKit。
- 2026-04-09: 720 合入后，同步诊断区接入真实 `CloudSyncStatus`、刷新动作、同步计数、诊断类型标签、恢复建议和共享边界说明。
- 2026-04-09: 诊断文案明确区分个人库 canonical 数据、伴侣端共享投影、`summaryShared` 的隐藏字段，以及“未加入情侣空间时只同步个人库”的降级行为。

## 验证记录

- `cd ios-app/App/CoupleLife && xcodegen generate`
- `cd ios-app/App/CoupleLife && xcodebuild test -project CoupleLife.xcodeproj -scheme CoupleLife -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.6' -only-testing:CoupleLifeTests/ProfileSettingsViewModelTests`
- `cd ios-app/App/CoupleLife && xcodebuild test -project CoupleLife.xcodeproj -scheme CoupleLife -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.6' -only-testing:CoupleLifeTests`
- `xcodebuild -project ios-app/App/CoupleLife/CoupleLife.xcodeproj -scheme CoupleLife -showdestinations`
- 结果: 未发现实体 iPhone destination；真机 CloudKit 联调无法在当前环境执行。
- `xcodebuild test -quiet -project ios-app/App/CoupleLife/CoupleLife.xcodeproj -scheme CoupleLife -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.6' -derivedDataPath /tmp/CoupleLifeDerivedData-main-final4`
- 结果: 通过，exit code 0；主 app 与 widget `CFBundleVersion` 均为 `1`，版本号 warning 已消失。

## 已知风险/遗留

- CloudKit 诊断已接入真实状态模型，但真机 iCloud 账号、CloudKit schema、CKShare/邀请/接受共享流程仍未验证；该风险继续归属 720/后续联调任务。
- 本次验证覆盖了 ViewModel 与现有单测；设置页 UI 本身尚未做单独快照或手动 Simulator 走查记录。

# 730 WidgetKit 小组件 v1

- 状态: Done
- 最后更新: 2026-04-06

- Phase: Phase 4 (生态增强)
- 模块: Integrations
- 依赖: 500、600、300（按组件内容不同）
- 目标: 增加基础 Widget：今日任务、今日步数、纪念日倒计时，形成 Apple 生态增强体验。
- 非目标: 不做 Apple Watch 配套（另拆任务）；不做 Live Activities（另拆任务）。

## 交付物

- `CoupleLifeWidgets` Widget Extension：通过 Xcodegen 生成 target、scheme 与显式 `Info.plist`
- 首期 3 个组件：
  - 今日任务摘要：当前以空态为主（Preview/placeholder 使用 sample），并提示去应用内添加今日计划
  - 今日步数摘要：当前以无权限/无数据空态为主（Preview/placeholder 使用 sample），并提示去应用内开启 Health 权限
  - 纪念日倒计时：当前以占位说明态为主（Preview/placeholder 使用 sample），待 CoupleSpace 落地后接入真实日期来源
- 刷新策略：任务每 30 分钟刷新、步数每 1 小时刷新、纪念日按天刷新；均提供 placeholder / no-data 降级

## 验收标准

- Xcodegen 能生成包含 `CoupleLifeWidgets` target 与独立 scheme 的工程
- Widget Extension 可命令行构建，且包含今日任务、今日步数、纪念日倒计时 3 个 widget
- 无权限/无数据时仍有明确展示，不出现空白；文案能提示下一步操作
- Widget 视觉保持干净、可读，与主应用配色风格一致（在 WidgetKit 能力允许范围内）

## 实施要点

- 本次先不引入 App Group / 共享缓存；Widget 采用 sample data + 明确空态，避免在 extension 内做重查询
- 显式 `Info.plist` 使用 `com.apple.widgetkit-extension`，并设置 `WKAppBundleIdentifier = com.ar1shadow.couplelife`
- UI 采用 widget 友好的渐变背景、胶囊标签与简短层级，避免在桌面/锁屏场景暴露过多细节
- 数据与权限降级：
  - 任务：无数据时提示去应用内添加今日计划
  - 步数：无权限/无共享数据时提示去应用内开启 Health 权限
  - 纪念日：CoupleSpace 未实现前显示占位说明，而非空白

## Skills 使用

- `$swiftui-feature-builder`: 用于快速搭建 Widget UI 与状态分支（占位/空/有数据）；适用于“Widget 视图落地”。
- `$xcode-simulator-debug`: 用于排查 extension 构建、运行、预览与 scheme/destination；适用于“Widget 开发排障”。

## 实施记录

- 在 `ios-app/App/CoupleLife/project.yml` 增加 `CoupleLifeWidgets` Widget Extension target，并把 extension 嵌入主 app；未手改 `.xcodeproj`
- 新增 `ios-app/App/CoupleLife/CoupleLifeWidgets/`，实现 `WidgetBundle` 与 3 个 widget：
  - `TodayTasksWidget`
  - `TodayStepsWidget`
  - `AnniversaryCountdownWidget`
- 为 extension 添加显式 `Info.plist`，配置 WidgetKit extension point 与宿主 app bundle identifier
- 首轮构建时，`#Preview` 宏在当前 CLI/Xcode 环境下触发 `PreviewsMacros.Common` 错误；已移除这些预览宏，保留可构建实现

## 验证记录

- `cd ios-app/App/CoupleLife && xcodegen generate`
  - 结果：成功生成工程，包含 `CoupleLifeWidgets` target
- `cd ios-app/App/CoupleLife && xcodebuild -list -project CoupleLife.xcodeproj`
  - 结果：成功列出 targets/schemes；`CoupleLifeWidgets` target 与 `CoupleLifeWidgets` scheme 均存在
- `cd ios-app/App/CoupleLife && xcodebuild build -project CoupleLife.xcodeproj -scheme CoupleLifeWidgets -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/CoupleLifeDerivedData`
  - 结果：构建成功（`** BUILD SUCCEEDED **`）
  - 说明：原始 simulator destination 在当前环境下受 `CoreSimulatorService`/默认 DerivedData 写权限限制；改用可复现的等价命令 `generic/platform=iOS Simulator` + `/tmp` 派生目录完成验证
- 未进行手动添加桌面 widget、锁屏展示或真机/Simulator UI 交互验证；本次仅确认生成与命令行构建通过

## 已知风险/遗留

- 目前 widget 仍以 placeholder/sample data 为主，尚未接入 App Group、共享缓存或真实 CoupleSpace/HealthKit 摘要数据
- 未做桌面/锁屏手测，仍需后续在 Simulator 或真机验证不同 family 的实际排版与文案长度
- 纪念日组件当前为占位实现；待 CoupleSpace 数据模型落地后，需要补真实日期来源与隐私策略

# 100 App 骨架与 Tab

- Phase: Phase 1 (MVP)
- 模块: AppCore
- 状态: Done
- 最后更新: 2026-03-27
- 依赖: 无
- 目标: 搭建可运行的 SwiftUI 应用骨架，包含底部 Tab、基础路由与占位页面，为后续模块开发提供稳定入口。
- 非目标: 不实现任何真实业务功能（数据模型/存储/同步/HealthKit/EventKit 都不在本任务内落地）。

## 交付物

- 5 个底部 Tab：首页 / 日历 / 计划 / 运动 / 我的（可先占位页面）
- 每个 Tab 独立导航栈（为后续深层页面导航做准备）
- 应用启动后可直接进入首页，无权限弹窗“强制打断”

## 验收标准

- App 可在 Simulator 启动并稳定切换 Tab
- 导航结构清晰，后续模块可以在各自 Tab 内继续追加页面而不需要重改入口
- 无明显架构反模式（例如把业务逻辑写进 `App`/根视图）

## 实施要点

- Tab 与导航：优先在每个 Tab 内维护自己的 `NavigationStack`，避免跨 Tab 的隐式 push
- 统一命名与信息架构：与 `project.md` 的 5 个 Tab 约定一致（首页/日历/计划/运动/我的）
- 预留依赖注入入口：在根层预留注入容器/服务的挂载点（实现见 110）

## Skills 使用

- `$swiftui-feature-builder`: 用于快速产出 Tab 骨架与占位页的 SwiftUI 实现；适用于“从信息架构到可编译 UI”。
- `$xcode-simulator-debug`: 用于处理 scheme/destination、Simulator 启动、构建失败等基础工程问题；适用于“最小可复现的 build/run 排障”。

## 实施记录

- 开工: 2026-03-27
- 进展: 已建立独立 worktree `task/100-app-scaffold-and-tabs`。
- 进展: 已完成 `xcodebuild -runFirstLaunch`，修复 Xcode 首次启动插件加载问题，为后续 CLI 构建做准备。
- 进展: 已使用 XcodeGen 生成 `CoupleLife.xcodeproj`，并落地 5 个 Tab + 每个 Tab 独立 `NavigationStack` 占位页。
- 下一步: 进入 110，补齐 DI/路由/服务协议边界（不在本任务内实现真实系统集成）。

## Definition of Done

- 存在可运行的 SwiftUI App 骨架，启动即进入 5 Tab 入口。
- 每个 Tab 拥有独立导航栈和占位首页，结构可继续扩展。
- 任务文件回填了实施记录、验证方式和已知风险。
- 至少有一种可复现验证方式（若尚无测试，则提供明确的手测路径）。

## 验证记录

- 命令: `git worktree add .worktrees/task-100-app-scaffold-and-tabs -b task/100-app-scaffold-and-tabs`
- 命令: `xcodebuild -list`
- 结果: 初次失败（exit 70），提示 `A required plugin failed to load`，需执行 `xcodebuild -runFirstLaunch`。
- 命令: `xcodebuild -runFirstLaunch`
- 结果: 成功（`Install Succeeded`）。
- 命令: `xcodebuild -list`
- 结果: 当前失败点为“目录不包含 Xcode project/workspace/package”（exit 66），说明需要先生成工程骨架。
- 命令: `cd ios-app/App/CoupleLife && xcodegen generate`
- 命令: `xcodebuild -project ios-app/App/CoupleLife/CoupleLife.xcodeproj -scheme CoupleLife -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/CoupleLifeDerivedData CODE_SIGNING_ALLOWED=NO build`
- 结果: `BUILD SUCCEEDED`
- 命令: `xcodebuild -downloadPlatform iOS`
- 备注: 若环境缺少 iOS Simulator runtime，需先安装，否则会出现 “iOS xx.x is not installed” 的 destination 错误。
- 命令: `xcrun simctl boot 5EF18BBB-1C49-45C8-BBD4-A831BDDA53B6 && xcrun simctl install 5EF18BBB-1C49-45C8-BBD4-A831BDDA53B6 /tmp/CoupleLifeDerivedData/Build/Products/Debug-iphonesimulator/CoupleLife.app && xcrun simctl launch 5EF18BBB-1C49-45C8-BBD4-A831BDDA53B6 com.ar1shadow.couplelife`
- 结果: 启动成功（PID 返回）
- 命令: `xcrun simctl io 5EF18BBB-1C49-45C8-BBD4-A831BDDA53B6 screenshot /tmp/couplelife-task100.png`

## 已知风险/遗留

- iOS Simulator runtime 缺失会导致 `xcodebuild` 无法选择 destination（可通过 `xcodebuild -downloadPlatform iOS` 修复）。

## 执行规范

- 见 `workflow.md`（任务状态流转、回填规则、最小增量原则）

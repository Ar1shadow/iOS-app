# 100 App 骨架与 Tab

- Phase: Phase 1 (MVP)
- 模块: AppCore
- 状态: In Progress
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
- 进展: 已复现 `xcodebuild` 失败并定位首个可行动错误；完成 `xcodebuild -runFirstLaunch` 修复 Xcode 首次启动组件。
- 下一步: 由实现 agent 创建最小 Xcode/SwiftUI 工程后，重新执行 `xcodebuild -list` 与 Simulator 构建验证。

## 验证记录

- 命令: `xcodebuild -list`
- 结果: 初次失败（exit 70），提示 `A required plugin failed to load` 与 `xcodebuild -runFirstLaunch`。
- 命令: `xcodebuild -runFirstLaunch`
- 结果: 修复成功（`Install Succeeded`）。
- 命令: `xcodebuild -list`
- 结果: 当前失败点变为 `The directory ... does not contain an Xcode project, workspace or package.`（exit 66）。

## 已知风险/遗留

- 当前仓库无 `.xcodeproj/.xcworkspace`，无法继续进行 scheme/destination 级别调试。
- 在工程创建前，`xcodebuild` 只能做环境可用性验证，不能覆盖任务验收中的“Simulator 启动与 Tab 切换”。

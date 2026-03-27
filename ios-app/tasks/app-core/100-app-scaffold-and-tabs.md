# 100 App 骨架与 Tab

- Phase: Phase 1 (MVP)
- 模块: AppCore
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


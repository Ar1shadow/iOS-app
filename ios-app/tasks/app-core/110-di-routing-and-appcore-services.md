# 110 依赖注入、路由与核心服务协议

- Phase: Phase 1 (MVP)
- 模块: AppCore
- 依赖: 100
- 目标: 定义清晰的依赖注入与路由边界，以及核心系统集成服务的协议层，确保各模块不直接耦合系统 API。
- 非目标: 不在此任务内实现 EventKit/HealthKit/CloudKit 的完整功能，仅建立可替换的协议与默认实现（可为 no-op 或 mock）。

## 交付物

- 依赖注入容器（DI）约定：服务实例的生命周期、创建位置、注入方式
- 路由约定：模块内导航与跨模块导航的边界（先以“各 Tab 内路由”为主）
- 核心服务协议（示例）：`CalendarSyncService`、`HealthDataService`、`NotificationScheduler`、`CloudSyncService`（可先占位）

## 验收标准

- Presentation 层（SwiftUI）不直接调用 EventKit/HealthKit 等系统 API
- 模块间依赖通过协议与注入完成，替换实现不会影响调用方
- 项目结构能支撑后续把实现迁移到 Integration/Data 层

## 实施要点

- 协议先行：先定义调用方真正需要的方法与数据形状，避免“把系统 API 原样透出”
- 依赖可测试：为后续单元测试或 Preview 注入 mock 提供入口
- 错误与权限语义：服务返回值要能表达“未授权/不可用/失败/无数据”等状态（避免只返回 `nil`）

## Skills 使用

- `$swiftui-ui-refactor`: 用于整理入口与注入点的 SwiftUI 结构，避免 DI/路由逻辑散落在多个视图里；适用于“保持行为不变的结构重排”。
- `$xcode-simulator-debug`: 用于定位编译错误、模块导入与构建设置问题；适用于“通过 xcodebuild 还原首个错误点”。


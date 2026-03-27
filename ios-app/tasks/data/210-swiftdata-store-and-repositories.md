# 210 SwiftData 存储与仓储层

- Phase: Phase 1 (MVP)
- 模块: Data
- 状态: Done
- 最后更新: 2026-03-27
- 依赖: 200
- 目标: 建立本地优先的持久化能力（SwiftData 起步），并提供面向业务的仓储接口，支撑日历记录与任务功能的 CRUD 与查询。
- 非目标: 不做 CloudKit 同步（见 720）；不做过度抽象的通用 ORM 包装。

## 交付物

- SwiftData 容器与 Schema（覆盖 `Record/Task/HealthMetricSnapshot`，`Goal` 可按需）
- 仓储层（Repository）协议与默认实现：创建/更新/删除/按日期区间查询
- 最小查询约定：按天、按范围、按状态、按层级等（仅覆盖 MVP 页面需要）

## 验收标准

- 记录与任务可离线创建、编辑、删除，并在重启后仍存在
- 列表查询不会在主线程做明显重负载工作（例如大范围同步过滤）
- 仓储接口能被 UI 与后续同步层复用，不把 SwiftData 细节泄露到 View

## 实施要点

- 先做“能用的查询”，再按真实页面需求补齐索引与优化点
- 预留迁移策略：字段变更时至少能平滑演进（不要求一次到位）
- 若出现滚动卡顿或内存增长，再引入性能测量与优化（见 960）

## Skills 使用

- `$xcode-simulator-debug`: 用于排查 SwiftData 模型/Schema/构建配置导致的编译或运行时问题；适用于“xcodebuild 复现与定位”。
- `$ios-performance-audit`: 当列表查询或数据加载出现卡顿/内存增长时用于做测量与定位；适用于“以数据层为源头的性能问题”。

## 实施记录

- 开工: 2026-03-27
- 进展: 新增 SwiftData `ModelContainerFactory`（Schema 覆盖 `Record/TaskItem/HealthMetricSnapshot`），并实现 v1 仓储接口与默认实现（SwiftData ModelContext）；补齐 in-memory XCTest 覆盖。
- 下一步: 进入 300/350/400 等页面任务时，通过仓储层提供 CRUD/query，而不是在 View 中直接操作 SwiftData。

## 验证记录

- 命令: `cd ios-app/App/CoupleLife && xcodegen generate`
- 命令: `xcodebuild -project ios-app/App/CoupleLife/CoupleLife.xcodeproj -scheme CoupleLife -destination 'platform=iOS Simulator,id=5EF18BBB-1C49-45C8-BBD4-A831BDDA53B6' -derivedDataPath /tmp/CoupleLifeDerivedData210 CODE_SIGNING_ALLOWED=NO test`
- 结果: `TEST SUCCEEDED`

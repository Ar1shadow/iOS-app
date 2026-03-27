# 200 核心领域模型 v1

- Phase: Phase 1 (MVP)
- 模块: Data / Domain
- 状态: Done
- 最后更新: 2026-03-27
- 依赖: 110（协议边界约定）
- 目标: 落地最小可用的数据模型集合，覆盖日历记录、任务计划与健康展示缓存，并为共享/同步/冲突预留扩展字段。
- 非目标: 不在本任务内实现 CloudKit 映射或复杂迁移策略；先保证模型清晰与可扩展。

## 交付物

- 领域实体（MVP）：`Record`、`Task`、`Goal`（可先占位）、`HealthMetricSnapshot`
- 通用字段约定：`ownerUserId`、`coupleSpaceId?`、`visibility`、`source`、`createdAt/updatedAt`、`version?`
- 关键枚举：记录类型、任务状态、计划层级、数据来源等（按需最小化）

## 验收标准

- 模型能覆盖 `project.md` 首期需求字段（不必一次实现所有未来字段）
- 添加新 `Record.type` 不需要推倒重来（以扩展为主，避免硬编码分支）
- 为同步冲突保留最小的时间戳/版本语义（例如 `updatedAt` + `version`）

## 实施要点

- `Record` 统一承载喝水/排便/月经/睡眠/活动等，避免为每种记录建独立表导致模型失控
- `Task` 与系统日历事件解耦：仅保留映射 ID（EventKit 实现见 700）
- `HealthMetricSnapshot` 作为展示缓存，不替代 HealthKit 的事实来源（实现见 600）

## Skills 使用

- `$xcode-simulator-debug`: 用于快速定位模型定义、模块引用、编译与迁移相关的构建错误；适用于“先让模型在工程里稳定通过编译”。

## 实施记录

- 开工: 2026-03-27
- 进展: 新增 SwiftData v1 领域模型 `Record` / `TaskItem` / `HealthMetricSnapshot` 及相关枚举；`TaskItem` 用于规避与并发 `Task` 的命名冲突。
- 下一步: 进入 210，建立 SwiftData 容器与仓储层。

## 验证记录

- 命令: `cd ios-app/App/CoupleLife && xcodegen generate`
- 命令: `xcodebuild -project ios-app/App/CoupleLife/CoupleLife.xcodeproj -scheme CoupleLife -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/CoupleLifeDerivedData200 CODE_SIGNING_ALLOWED=NO build`
- 结果: `BUILD SUCCEEDED`

# 410 记录 CRUD 与快捷打卡 v1

- Phase: Phase 1 (MVP)
- 模块: Calendar
- 依赖: 200、210、400、300
- 状态: Done
- 最后更新: 2026-03-28
- 目标: 支持在某天详情页查看/新增/编辑/删除记录，并提供首期记录项的快捷打卡能力。
- 非目标: 不做周期预测、健康深度分析；不默认共享敏感数据（共享边界见 810）。

## 交付物

- 某天详情页：同一天多条记录列表 + 基础筛选/分组（MVP）
- 记录新增/编辑表单：备注、标签、时间段、状态值（按类型最小化）
- 快捷打卡：对高频记录（喝水/排便等）提供一键新增入口

## 验收标准

- 支持未来补录与过去补录（按日期创建记录）
- 同一天多条记录不会覆盖或丢失
- 记录类型展示一致（图标/颜色来自 SharedUI 映射）

## 实施要点

- `Record` 结构保持统一，差异字段放在 `metadata/value/unit/status` 等可扩展位
- 表单的状态与校验尽量清晰：避免在 `body` 内做复杂转换
- 预留 `visibility` 字段的 UI 入口（默认 private，Phase 2 再做共享策略）

## 实施记录

- 已将 Day Detail 升级为真实记录页：支持按类型分组浏览、类型筛选、空状态、点按编辑、上下文删除与快捷打卡。
- 新增 `CalendarDayRecordService` + `CalendarDayDetailViewModel`，把 CRUD、默认时间、校验与回调刷新移出 SwiftUI `body`。
- 扩展 `Record` 与 `RecordRepository` 以支持 `tagsRaw`/`valueText`/`update(_:)`，并补充测试覆盖标签归一化、快捷打卡时间规则、详情页状态同步。

## 验证记录

- `cd ios-app/App/CoupleLife && xcodegen generate`
- `xcodebuild -project ios-app/App/CoupleLife/CoupleLife.xcodeproj -scheme CoupleLife -destination 'platform=iOS Simulator,id=5EF18BBB-1C49-45C8-BBD4-A831BDDA53B6' -derivedDataPath /tmp/CoupleLifeDerivedData410 CODE_SIGNING_ALLOWED=NO test`
- 自动化结果：26 tests, 0 failures（包含记录 CRUD 数据层、快捷打卡时间规则、Day Detail ViewModel 过滤/刷新）

## 已知风险/遗留

- 已通过回调触发 `CalendarTab` 摘要刷新，但尚未在真机/手动导航路径上逐项确认月/周/日三种模式的 UI 动效与滚动位置。
- Day Detail 目前使用上下文菜单删除；若后续需要更强 discoverability，可再补充 swipe action 或批量编辑。

## Skills 使用

- `$swiftui-feature-builder`: 用于实现“列表 + 表单 + 多状态（空/有数据/编辑）”的完整闭环；适用于“表单型业务页面”。
- `$xcode-simulator-debug`: 用于排查 SwiftData/路由/运行时崩溃与日志；适用于“复现并定位首个错误”。
- `$ios-performance-audit`: 当某天记录数量增大导致滚动卡顿时用于测量与优化；适用于“列表渲染与查询性能问题”。

# 300 设计系统与通用组件 v1

- Phase: Phase 1 (MVP)
- 模块: SharedUI
- 状态: Done
- 最后更新: 2026-03-27
- 依赖: 100
- 目标: 建立统一的 UI 设计系统（色板/字体/间距/卡片/空状态/图标映射），让后续页面实现风格一致且易维护。
- 非目标: 不追求一次性完成全部视觉设计；先建立可复用的最小集合。

## 交付物

- Design tokens：颜色、字体、圆角、阴影、间距的统一入口
- 通用组件：卡片、分区标题、标签、空状态、加载态（按需最小化）
- `Record.type` 到图标/颜色的映射表（与 `project.md` 首期记录项一致）

## 验收标准

- 新页面优先复用 SharedUI 组件而非重复造轮子
- 组件命名与职责清晰，避免“万能组件”导致难维护
- 支持动态字体与基础可访问性（至少不阻碍后续完善）

## 实施要点

- 先做高频组件：卡片/列表行/空状态/状态徽标
- 图表风格先统一容器与排版，具体图表实现放到 Fitness 模块再细化
- 与 Liquid Glass 的关系：SharedUI 先提供普通卡片，玻璃风格另做封装（见 310）

## Skills 使用

- `$swiftui-feature-builder`: 用于快速实现通用组件与示例用法；适用于“从规则到可复用 SwiftUI 组件”。
- `$swiftui-ui-refactor`: 用于把重复的样式与 modifier 收敛为明确的组件/扩展；适用于“减少重复与提升可读性”。

## 实施记录

- 开工: 2026-03-27
- 进展: 新增 SharedUI token 入口（颜色/字体/间距/圆角/阴影）与通用组件（卡片、分区标题、列表行、状态徽标、空状态、加载态）。
- 进展: 根据规格补齐通用标签组件 `SharedTag`，并将 `SharedStatusBadge` 收敛为薄封装。
- 进展: 修正 HomeTab 为“SharedUI 静态展示占位”文案，避免伪造业务数据；优化 `SharedListRow` 在无障碍大字号时切换纵向布局。
- 进展: 新增 `RecordType` 视觉映射目录与 `RecordType.visualStyle` 扩展，并在 HomeTab 采用 SharedUI 组件完成示例落地。
- 进展: 采用测试先行方式新增 `RecordTypeStyleTests`，先验证失败后补齐实现并通过全量测试。
- 下一步: 在后续业务页面继续替换重复样式为 SharedUI 组件。

## 验证记录

- 命令: `cd ios-app/App/CoupleLife && xcodegen generate`
- 命令: `xcodebuild -project CoupleLife.xcodeproj -scheme CoupleLife -destination 'id=5EF18BBB-1C49-45C8-BBD4-A831BDDA53B6' -only-testing:CoupleLifeTests/RecordTypeStyleTests test`
- 结果: 初次失败（RED），提示缺少 `RecordType.visualStyle` 与 `RecordTypeVisualCatalog`；实现后复跑通过（2 tests passed）。
- 命令: `xcodebuild -project CoupleLife.xcodeproj -scheme CoupleLife -destination 'id=5EF18BBB-1C49-45C8-BBD4-A831BDDA53B6' test`
- 结果: 通过（6 tests, 0 failures）。
- 命令: `xcodebuild -project CoupleLife.xcodeproj -scheme CoupleLife -destination 'generic/platform=iOS Simulator' build`
- 结果: `BUILD SUCCEEDED`。
- 命令: `xcodebuild -project CoupleLife.xcodeproj -scheme CoupleLife -destination 'id=5EF18BBB-1C49-45C8-BBD4-A831BDDA53B6' test`（标签补齐后复验）
- 结果: 通过（6 tests, 0 failures）。
- 命令: `xcodebuild -project CoupleLife.xcodeproj -scheme CoupleLife -destination 'id=5EF18BBB-1C49-45C8-BBD4-A831BDDA53B6' -only-testing:CoupleLifeTests/SharedUIRegressionTests test`
- 结果: 通过（2 tests, 0 failures），覆盖 HomeTab 展示文案与 `SharedListRow` 动态字体布局策略。

## 已知风险/遗留

- HomeTab 当前为示例性接入，Calendar/Planning/Fitness 等页面仍未迁移到 SharedUI 组件。

# 350 首页聚合仪表盘 v1

- Phase: Phase 1 (MVP)
- 模块: Home
- 状态: Done
- 最后更新: 2026-03-27
- 依赖: 300、210（至少需要能读取任务/记录/健康缓存的最小接口）
- 目标: 实现首页总览页，聚合展示今日任务、今日记录摘要、今日运动摘要、重要事件与快捷入口。
- 非目标: 不做复杂统计分析与洞察（见 Phase 3）；不做完整情侣对比（见 Phase 2/3）。

## 交付物

- 首页布局：卡片式信息分区 + 快捷入口（新增记录/新增任务等）
- 数据策略：优先本地读取；无权限/无数据时展示清晰空态
- 组件复用：尽量使用 SharedUI，避免首页变成样式孤岛

## 验收标准

- 首页不会在无权限/无数据状态下出现空白或崩溃
- 滚动与进入速度在正常数据量下无明显卡顿
- 首页结构可扩展：后续新增模块卡片不需要重写整体布局

## 实施要点

- 先实现 MVP 摘要：任务数/完成数、记录类型标记、步数/睡眠摘要等
- 避免首页直接承担复杂业务逻辑：聚合逻辑放在 Domain/Service 层

## Skills 使用

- `$swiftui-feature-builder`: 用于快速搭建首页卡片布局与状态分支（加载/空/有数据）；适用于“聚合型页面落地”。
- `$ios-liquid-glass`: 用于首页卡片的层次与材质处理（试点）；适用于“增强高级感但不影响阅读”。
- `$swiftui-ui-refactor`: 当首页 `body` 变大时用于拆分组件与收敛状态；适用于“保持可维护性”。

## 实施记录

- 完成首页聚合服务 `DefaultHomeDashboardService`，按“今日”聚合任务、记录、健康缓存，避免在叶子 View 直接做 SwiftData 查询。
- HomeTab 改为真实仪表盘结构（加载/空态/已加载/失败），复用 SharedUI 卡片、分区标题、标签、空态、加载态与列表行。
- 在 RootTabView 做仓库注入，首页仅消费服务与摘要模型，保持后续模块卡片可扩展。
- 补齐“重要事件”区块（未来 7 天内最多 3 条排期任务）并增加无事件空态；任务/记录聚合已按 `ownerUserId` 过滤，默认用户改为 `CurrentUser.id = "local"`。
- 追加质量修复：`hasAnyData` 纳入重要事件；新增 `TaskRepository.tasks(scheduledFrom:to:ownerUserId:status:)` 用于减少首页加载时的无效数据扫描（SwiftData Optional<Date> 谓词限制下采用仓库内存过滤实现）。

## 验证记录

- `cd ios-app/App/CoupleLife && xcodegen generate` 通过（2026-03-27）。
- `xcodebuild -project ios-app/App/CoupleLife/CoupleLife.xcodeproj -scheme CoupleLife -destination 'platform=iOS Simulator,id=5EF18BBB-1C49-45C8-BBD4-A831BDDA53B6' -derivedDataPath /tmp/CoupleLifeDerivedData350 CODE_SIGNING_ALLOWED=NO test` 通过（9 passed, 0 failed）。
- 同命令复验通过（2026-03-27）：10 passed, 0 failed（新增 HomeDashboardService owner 过滤与重要事件覆盖测试）。
- 同命令再次复验通过（2026-03-27）：12 passed, 0 failed（新增 TaskRepository 时间窗查询用例与 `hasAnyData` 覆盖）。

## 遗留风险

- 健康摘要当前依赖缓存快照，若后台同步延迟会出现“数据非最新”的短暂窗口。
- 快捷入口按钮目前为占位交互（仅展示入口），后续需接入真实导航与创建流程。
- 首页摘要加载仍包含主线程同步读取与聚合（已减少无效扫描，但未完全异步化）；若后续任务/记录规模增大出现卡顿，按 960 的流程做测量后再优化数据路径。

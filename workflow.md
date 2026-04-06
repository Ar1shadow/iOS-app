# 工作流程（Agent Ready）

目标：让“无记忆 agent”只靠本仓库文档就能接手任务，并且由执行任务的 agent 负责最小化更新记录。

## Agent Quickstart

1. 打开 `workflow.md`，按本文流程执行。
2. 打开 `ios-app/tasks/` 选择一个任务文件（例如 `ios-app/tasks/app-core/100-app-scaffold-and-tabs.md`）。
3. 把任务状态更新为 `In Progress`，并写下“最后更新/实施记录”的最小信息。
4. 只做该任务的范围，按“单任务执行循环”推进，完成后回填“验证记录”，再标记 `Done`。
5. 需要全局索引与阶段顺序时，查 `organization.md`。

## 任务生命周期（状态流转）

- `Todo`：未开始。
- `In Progress`：正在执行；任务文件必须包含当前进展与下一步。
- `Blocked`：被阻塞；必须写明阻塞原因、解除阻塞的下一步动作、以及需要谁/什么输入。
- `Done`：完成；必须有可复现的验证记录与已知风险说明（若有）。

状态只允许一个主状态，避免“半完成/快完成”。

## 单任务执行循环（固定步骤）

1. 读任务文件：确认 `目标/非目标/依赖/验收标准` 是否足够清晰。
2. 补齐最小微设计（写回任务文件的“实施要点/实施记录”）：
   - UI 状态：空/加载/错误/成功（只写任务相关的）。
   - 数据路径：View/State -> UseCase -> Repository/Service -> Store/Integration。
   - 权限与降级：未授权/不可用时 UI 怎么表现，是否延迟请求权限。
3. 实现：以“纵切闭环”为原则，优先把一个可运行闭环做通，再扩展覆盖面。
4. 验证：
   - 先做最小可复现验证（优先命令行复现，例如 `xcodebuild`）。
   - 再做关键手测路径（按验收标准逐条点检）。
5. 回填任务文件：
   - 更新状态与最后更新时间。
   - 记录关键决策（1-3 条即可）。
   - 写下验证命令/手测路径/已知风险。
6. 标记 `Done`。

## 文档更新规则（执行者负责，最小增量）

你执行的每个任务，必须更新该任务文件；你修改了流程本身时，才更新 `workflow.md`。

### 必须更新（每次任务推进都要写）

- `状态`（Todo/In Progress/Blocked/Done）
- `最后更新`（日期即可）
- `实施记录`：本次做了什么，下一步是什么（1-3 行）
- `验证记录`：跑了什么命令、验证了哪些路径（要可复现）
- `已知风险/遗留`：若存在，用 1-3 行列出

### 禁止更新（避免臃肿）

- 把 `project.md` 或其它文档整段复制到任务文件
- 写长篇过程日志、聊天记录式流水账
- 在多个地方重复同一原则（原则写在 `workflow.md`，任务文件只写“本任务的特例与决策”）

## DoD（Definition of Done）

任务只有满足以下条件才可标记 `Done`：

- 功能完成：交付物已实现，且不超出非目标
- 可复现验证：记录至少一种验证方式（命令或明确手测步骤）
- 关键边界已验证：空/错误/未授权等降级路径至少覆盖 1 次
- 文档已更新：任务文件已回填“实施记录/验证记录/遗留风险”
- 若涉及敏感能力：权限引导与隐私边界已说明且可用

## Skills 使用（何时用）

- 新页面/组件/流程落地：用 `$swiftui-feature-builder`
- SwiftUI 交互/导航/状态/Sheet/TabView 模式选型：用 `$build-ios-apps:swiftui-ui-patterns`（先查模式再写）
- SwiftUI 单文件结构整理（拆分大 `body`、抽子视图、移出副作用）：用 `$build-ios-apps:swiftui-view-refactor`
- SwiftUI 结构整理（不改行为、偏低风险重排）：用 `$swiftui-ui-refactor`
- SwiftUI 性能问题（过度重渲染/列表卡顿/布局抖动）：用 `$build-ios-apps:swiftui-performance-audit`（先测量再改）
- 通用性能问题（启动慢/主线程阻塞/内存增长/I/O）：用 `$ios-performance-audit`（先测量再改）
- 玻璃材质风格（通用玻璃/半透明分层）：用 `$ios-liquid-glass`（只用于合适表面，并验证可读性与无障碍回退）
- 仅当采用 iOS 26+ Liquid Glass API（`glassEffect` 等）：用 `$build-ios-apps:swiftui-liquid-glass`（注意 `#available` 与回退）
- 构建/运行/测试/Simulator 排障：用 `$xcode-simulator-debug`
- 需要通过 XcodeBuildMCP 直接在 Simulator 运行/交互/截图/抓日志：用 `$build-ios-apps:ios-debugger-agent`

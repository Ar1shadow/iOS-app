# 970 无障碍 QA 清单

- 状态: Done
- 最后更新: 2026-04-06
- Phase: Phase 1 (持续)
- 模块: Quality
- 依赖: 300（设计系统落地后更易统一处理）
- 目标: 建立一份可执行、可复测的无障碍 QA 清单，覆盖常见 iOS 可访问性设置、基础语义与交互边界。
- 非目标: 不在本任务内逐页整改所有问题；本任务只定义检查项、验收口径和前置门禁。

## 交付物

- 一份可直接照着执行的 QA 检查表，覆盖：
  - Dynamic Type
  - VoiceOver
  - Reduce Transparency
  - Reduce Motion
  - Increase Contrast
  - Differentiate Without Color
  - Button hit targets
  - Focus order
  - labels / traits / hints
  - images / icons
  - charts / graphs
  - forms
  - alerts / sheets
  - navigation titles
- Simulator 手测步骤：说明如何在 `Settings > Accessibility` 切换相关设置，以及切换后要观察什么。
- SharedUI-first 原则：优先在组件/修饰器层修复，避免页面逐个补丁。
- Liquid Glass 兼容要求：玻璃材质在 `Reduce Transparency` 下必须有清晰 fallback。
- PR gate：UI 改动合并前必须过的最小无障碍检查。

## 验收标准

- 新增或修改的 UI 在合并前至少完成一次本清单的 PR gate（见第 9 节）全项检查。
- 关键控件具备可读的语义信息，且 VoiceOver 顺序符合视觉与操作预期。
- 在大字号、强对比、减弱透明度、减少动效场景下，页面仍可用且不丢信息。
- 涉及 SharedUI 的修复优先收敛到通用组件或 modifier，而不是分散在各页面重复修。

## 实施要点

### 判定口径（尽量可操作）

- 点击区域：核心可点击元素（按钮/图标按钮/列表行）命中区域不少于 **44x44pt**，且不会被透明层遮挡。
- 文案与信息：关键标题/数值/状态文本在大字号下不应被截断到不可理解；必要时允许换行或滚动。
- VoiceOver：关键控件必须有可读 label；Sheet/模态关闭后焦点回到触发控件或合理上下文。

### 1) 先在 Simulator 复现系统设置

- 打开 Simulator 中的 `Settings > Accessibility`，逐项切换：
  - `Display & Text Size`：`Larger Text`、`Increase Contrast`、`Differentiate Without Color`、`Reduce Transparency`
  - `Motion`：`Reduce Motion`
  - `VoiceOver`：开启后重新浏览主要页面
- 说明：Simulator 是最小基线；若条件允许，发布前对关键路径做一次真机 spot-check（尤其是 VoiceOver 焦点与触控命中）。
- 每次只改一个设置，回到目标页面观察：
  - 布局是否截断、重叠、遮挡或出现不可滚动内容
  - 信息是否只靠颜色表达，导致开启辅助功能后失去区分
  - 动画、过渡和玻璃层是否仍保持清晰与可操作
  - 语音读出是否准确、顺序是否合理、是否跳过了关键内容

### 2) Dynamic Type

- 检查标题、正文、标签、按钮文案、卡片摘要在大字号下是否自动换行或可滚动。
- 重点看是否存在固定高度、硬编码宽度、截断后无法理解的文案。
- 对表单、列表、图表说明，优先保证信息完整，其次再考虑压缩排版。

### 3) VoiceOver

- 每个可点控件都应有清晰 `label`；仅图标按钮尤其要检查。
- 必要时补 `traits`，让按钮、开关、链接、选中态被正确识别。
- `hint` 只在操作意图不明显时补充，不要把本来就清楚的按钮变得冗余。
- 检查焦点顺序是否与视觉布局一致：从上到下、从左到右，避免跳跃。

### 4) 触控与表单

- 按钮和可点区域要满足足够的 hit target，图标按钮不能只靠图形可点。
- 表单字段应有可读标题、错误提示和提交反馈；聚焦后不应被键盘遮挡。
- 验证 Alert / Sheet 中按钮是否可被完整朗读，关闭动作是否明确。

### 5) 图片、图标、图表

- 装饰性图片应标记为非信息内容；承载信息的图片必须有可读替代描述。
- 图标不要成为唯一信息源，必要时配文本或辅助说明。
- 图表/图形需要能被理解：至少有标题、摘要、单位、关键趋势说明；不要只给一张“看不懂但好看”的图。

### 6) 导航与页面结构

- Navigation title 要稳定、简洁、能反映当前页面。
- 进入新页面后，VoiceOver 的初始焦点应落在合理位置，例如标题或首个核心操作。
- Sheet / 模态页关闭后，焦点应回到触发它的上下文。

### 7) Liquid Glass 与透明度回退

- 只在需要层次感的容器上使用玻璃材质，不要让效果盖过内容可读性。
- 开启 `Reduce Transparency` 时，玻璃背景必须切换为高对比、低噪点的实底或弱透明样式。
- 检查高亮、浮层、卡片边界是否仍清楚，避免“看起来高级但读不清”。

### 8) SharedUI-first 修复策略

- 发现同类问题时，优先修 SharedUI 组件、样式 modifier、文案组件或图标按钮封装。
- 页面层只保留业务差异，不重复写 accessibility 逻辑。
- 如果一个问题会影响多个页面，先修共享入口，再回测具体页面。

### 9) PR gate

- 合并前至少确认：
  - 大字号不崩版
  - VoiceOver label / trait / hint 正确
  - hit target 足够
  - 色彩不是唯一信息通道
  - `Reduce Transparency` / `Reduce Motion` 下仍可用
  - 影响 SharedUI 时已走通用修复，而不是临时页面补丁

## Skills 使用

- `$swiftui-ui-refactor`: 用于把无障碍标注、语义和结构收敛到共享组件与修饰器，减少页面级重复修复。
- `$ios-liquid-glass`: 用于检查玻璃材质在无障碍设置下的可读性与回退策略。

## 实施记录

- 已将原始概述扩展为可直接执行的 QA 清单，补齐了 Simulator 复现步骤、检查维度和 PR gate。
- 已明确 SharedUI-first 原则：无障碍修复优先落到共享组件 / modifier，避免在页面层散修。
- 已补入 Liquid Glass 与 `Reduce Transparency` 的回退要求，防止视觉效果影响信息可读性。

## 验证记录

- 已进行文档结构自检：包含 `状态`、`最后更新`、`Phase/模块/依赖/目标/非目标`，以及必需章节 `交付物 / 验收标准 / 实施要点 / Skills 使用 / 实施记录 / 验证记录 / 已知风险/遗留`。
- 已对照仓库中同类 Done 任务的写法，确认本文件属于“可执行清单 + 验收口径”类型，而不是实现说明。
- 建议后续在 Simulator 中按文档逐项手测，但本次未实际运行 UI 无障碍检查，因此不声称已完成设备级验证。

## 已知风险/遗留

- 这是 QA 清单，不替代具体页面的修复工作；实际缺陷仍需在对应任务中落地整改。
- 不同 simulator / iOS 版本对辅助功能行为可能略有差异，手测时应记录设备与系统版本。
- 图表与复杂内容的可访问性往往需要页面级补充说明，必要时还要为数据可读性单独设计摘要文案。

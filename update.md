# Update（截至 2026-03-28）：字体 / 界面美化 / 动效 / 多语言

面向当前代码与任务进度，对后续 **字体显示优化、界面美化、动效、多语言（i18n/l10n）** 给出：**可行性 → 可能问题 → 实现路径**，并标注关键文件、依赖关系与注意事项（不提供具体代码实现方案）。

## 0. 当前项目概览（现状与依赖）

- 工程生成：使用 `xcodegen`，规范文件为 `ios-app/App/CoupleLife/project.yml`；`ios-app/App/CoupleLife/CoupleLife.xcodeproj` 为生成物，不手改。
- 技术栈：SwiftUI + SwiftData。
- 系统能力：HealthKit、EventKit 已接入基础能力，涉及权限与设备差异（模拟器/真机表现不同）。
- UI 基础：已建立 SharedUI 设计 Token 与通用组件（卡片/标签/列表行/空状态/加载态等），但仍有部分页面/模块存在硬编码样式与文案。
- 本地化现状：大量文案为硬编码中文；当前工程内未发现 `.xcstrings` / `*.lproj` 资源；存在多处中文模板日期格式（如 `M月d日`、`yyyy年`）。

### 关键文件与依赖关系（简图）

- 设计 Token：`ios-app/App/CoupleLife/CoupleLife/SharedUI/Tokens/DesignTokens.swift`
  - 依赖方向：被 SharedUI 组件与页面直接使用，影响字体、间距、圆角、阴影与颜色表现。
- 通用组件：`ios-app/App/CoupleLife/CoupleLife/SharedUI/Components/*`
  - 依赖方向：被 `ios-app/App/CoupleLife/CoupleLife/UI/Tabs/*`（Home/Calendar/Planning）复用，适合承载“统一字体/动效/风格”的收敛点。
- Tab 信息架构：`ios-app/App/CoupleLife/CoupleLife/UI/Root/AppTab.swift` + `ios-app/App/CoupleLife/CoupleLife/UI/Root/RootTabView.swift`
  - 依赖方向：决定 Tab 文案与图标；多语言改造会影响测试 `ios-app/App/CoupleLife/CoupleLifeTests/AppTabTests.swift`。
- 日历/计划的日期格式化：
  - `ios-app/App/CoupleLife/CoupleLife/Calendar/Presentation/CalendarViewModel.swift`
  - `ios-app/App/CoupleLife/CoupleLife/Planning/Presentation/PlanningViewModel.swift`
  - `ios-app/App/CoupleLife/CoupleLife/UI/Tabs/HomeTab.swift`
  - 依赖方向：当前使用中文模板 dateFormat，国际化时必须优先治理，否则英文/其他语言显示会不自然或错误。

---

## 1) 字体显示优化（Typography）

### 可行性

- 已有统一入口 `AppTypography`（设计 Token），并被多处页面与 SharedUI 组件引用。
- `SharedListRow` 已对无障碍大字号做过布局策略（横排/竖排切换），说明当前架构适合继续推进可访问性与字体一致性治理。

### 可能存在的问题

- 动态字体 + 多语言文本长度变化会放大溢出风险：Tab 标题、Header、Tag、列表行的副标题更容易截断或挤压布局。
- 工程内仍有“绕过 token”的直接字体指定（例如 `.font(.title3...)` 等），会导致统一调整成本上升。
- 数字类信息（步数、计数、条目数）缺少统一格式化与视觉规范，易出现“数字跳动”“单位不一致”“长数字难读”。

### 实现路径（建议顺序）

1. 定义“语义化字体层级”规范：页面标题、区块标题、正文、辅助信息、数值展示分别对应的字号/字重策略（以系统字体为主，优先 Dynamic Type 友好）。
2. 收敛到 `AppTypography`：先从 SharedUI 组件收敛，再逐步收敛页面中的散落字体写法（减少全局搜索替换的维护成本）。
3. 明确大字号布局策略清单：哪些组件在 accessibility sizes 需要自动换行/改纵向布局/缩短文案/隐藏非核心信息。
4. 制定数字展示规范：本地化数字格式、单位与等宽数字策略（尤其 Home 的摘要指标与 Calendar/Planning 的计数徽标）。

### 重点相关文件

- `ios-app/App/CoupleLife/CoupleLife/SharedUI/Tokens/DesignTokens.swift`
- `ios-app/App/CoupleLife/CoupleLife/SharedUI/Components/SharedListRow.swift`
- `ios-app/App/CoupleLife/CoupleLife/SharedUI/Components/SharedSectionHeader.swift`
- `ios-app/App/CoupleLife/CoupleLife/UI/Tabs/HomeTab.swift`
- `ios-app/App/CoupleLife/CoupleLife/UI/Tabs/CalendarTab.swift`

---

## 2) 界面美化（层次、主题、Glass/Material）

### 可行性

- SharedUI 已有卡片、边框、阴影与基础排版语义；Home 已有玻璃材质 overlay 的雏形，可作为“试点”验证可读性与无障碍回退。
- 颜色 token 目前多基于系统语义色，天然支持深色模式，风险较低。

### 可能存在的问题

- Material/玻璃效果在深色模式、复杂背景、滚动内容上容易出现对比度不足；必须考虑“降低透明度/增加对比度”等系统设置回退。
- 若引入品牌色/图片资源（`Assets.xcassets`），需要先定义 token 映射与命名规范，否则会快速产生不可控的样式分叉。
- 阴影/边框在不同背景上容易“发灰/脏”，需要统一配方并限定适用范围（不要全局铺满）。

### 实现路径（建议顺序）

1. 先明确风格目标：更偏 iOS 原生（推荐）/轻玻璃/品牌化的倾向，避免中途大幅返工。
2. 把玻璃样式从页面私有实现收敛到 SharedUI（一个入口、少量参数），并配套可读性检查清单（亮/暗、滚动、Reduce Transparency）。
3. 优先治理“高频容器与控件”：SharedCard、Tag/Badge、主要按钮风格一致性；页面只做少量试点替换。
4. 如需品牌化：先只落地 1 个主色（accent）+ 少量语义色，逐步扩大覆盖面。

### 重点相关文件

- `ios-app/App/CoupleLife/CoupleLife/SharedUI/Components/SharedCard.swift`
- `ios-app/App/CoupleLife/CoupleLife/SharedUI/Tokens/DesignTokens.swift`
- `ios-app/App/CoupleLife/CoupleLife/UI/Tabs/HomeTab.swift`
- `ios-app/tasks/shared-ui/310-liquid-glass-style.md`

---

## 3) 动效（微交互 + 状态转场）

### 可行性

- SwiftUI 状态驱动结构清晰，适合做“加载 → 内容”“筛选/模式切换”“选中态反馈”等轻量动效；可按页面试点逐步扩散。

### 可能存在的问题

- 过度动效会放大列表与网格更新成本（Calendar/Planning 更敏感），引入卡顿风险。
- 必须尊重 Reduce Motion，否则影响可访问性与用户舒适度。
- 若动效散落到各页面，后续统一调参会很痛苦，建议集中到 SharedUI 或少量统一入口。

### 实现路径（建议顺序）

1. 先定动效范围：只覆盖 3 类高收益场景（加载转场、筛选/模式切换、操作反馈），其余保持稳定。
2. 提供少量统一动效入口（SharedUI 层承载），页面只“调用”而不“自定义配方”。
3. 先试点 1–2 个页面：Calendar（显示模式切换、选中日期反馈）+ Planning（任务状态操作反馈）。
4. 建立回归检查项：Reduce Motion 下的替代表现与关键路径手测。

### 重点相关文件

- `ios-app/App/CoupleLife/CoupleLife/UI/Tabs/CalendarTab.swift`
- `ios-app/App/CoupleLife/CoupleLife/UI/Tabs/PlanningTab.swift`
- `ios-app/App/CoupleLife/CoupleLife/SharedUI/Components/*`

---

## 4) 多语言（i18n / l10n）

### 可行性

- iOS 支持 Strings Catalog（`.xcstrings`）与 `*.lproj`；项目使用 xcodegen，只要把资源纳入 target sources 即可工作。
- 当前文案主要集中在：Root/Tab、SharedUI 文案与映射、页面与 ViewModel、Integrations 的错误信息与系统日历 notes，适合按“关键路径优先”渐进替换。

### 可能存在的问题（当前代码已暴露）

- 硬编码中文分散在多层：
  - Tab 标题：`ios-app/App/CoupleLife/CoupleLife/UI/Root/AppTab.swift`
  - 记录类型标题：`ios-app/App/CoupleLife/CoupleLife/SharedUI/Models/RecordTypeVisualStyle.swift`
  - 计划层级/状态标题：`ios-app/App/CoupleLife/CoupleLife/Planning/Presentation/PlanningDisplaySupport.swift`
  - 错误文案：`ios-app/App/CoupleLife/CoupleLife/Integrations/Calendar/EventKitCalendarSyncService.swift`、`ios-app/App/CoupleLife/CoupleLife/Integrations/HealthKit/HealthKitHealthDataService.swift`
- 日期格式硬编码为中文模板，非中文语言会显示不自然或错误：
  - `ios-app/App/CoupleLife/CoupleLife/UI/Tabs/HomeTab.swift`
  - `ios-app/App/CoupleLife/CoupleLife/Calendar/Presentation/CalendarViewModel.swift`
  - `ios-app/App/CoupleLife/CoupleLife/Planning/Presentation/PlanningViewModel.swift`
- 单元测试断言中文文案（例如 Tab 标题、RecordType 映射）：本地化后需要调整测试策略（避免与默认语言强绑定）。
- EventKit 同步写入系统日历的 notes：写入后不会随语言切换自动更新，需接受“历史不回写”或设计明确的再同步策略。
- `project.yml` 中的隐私权限描述目前为中文 build setting，若要多语言需迁移到 InfoPlist 本地化资源（需要在 xcodegen/工程资源上配合）。

### 实现路径（推荐顺序）

1. 语言范围：建议先支持 `zh-Hans` + `en`，默认语言保持 `zh-Hans`（减少未翻译回退的突兀感）。
2. 资源基建：引入 `Localizable.xcstrings`（可按模块拆分）并把资源纳入 `project.yml`；同时规划 `InfoPlist.strings`（按语言）用于权限文案多语言。
3. 文案替换策略（从外到内）：Root/Tab → SharedUI 通用文案 → Home/Calendar/Planning 页面 → Integrations 错误/notes。
4. 日期与数字国际化优先：先消除中文模板日期格式，使用 locale-aware 的日期/数字策略，再做文案全覆盖。
5. 测试策略调整：逻辑测试避免绑定默认语言；对“本地化结果”只在固定 locale 下做有限断言或改测 key/映射稳定性。
6. 验收与回归：英文环境下走通 Home/Calendar/Planning 核心路径，重点检查换行/溢出/按钮宽度；再在深色模式与无障碍大字号复验。

### 重点相关文件

- `ios-app/App/CoupleLife/CoupleLife/UI/Root/AppTab.swift`
- `ios-app/App/CoupleLife/CoupleLife/SharedUI/Models/RecordTypeVisualStyle.swift`
- `ios-app/App/CoupleLife/CoupleLife/Planning/Presentation/PlanningDisplaySupport.swift`
- `ios-app/App/CoupleLife/CoupleLife/Calendar/Presentation/CalendarViewModel.swift`
- `ios-app/App/CoupleLife/CoupleLife/Planning/Presentation/PlanningViewModel.swift`
- `ios-app/App/CoupleLife/CoupleLife/UI/Tabs/HomeTab.swift`
- `ios-app/App/CoupleLife/CoupleLife/Integrations/Calendar/EventKitCalendarSyncService.swift`
- `ios-app/App/CoupleLife/CoupleLife/Integrations/HealthKit/HealthKitHealthDataService.swift`
- `ios-app/App/CoupleLife/project.yml`
- 测试：`ios-app/App/CoupleLife/CoupleLifeTests/AppTabTests.swift`、`ios-app/App/CoupleLife/CoupleLifeTests/SharedUI/RecordTypeStyleTests.swift`

---

## 5) 建议落地顺序（最小返工）

1. i18n 基建 + 日期/数字国际化（先消除“中文模板日期”风险点）
2. Typography 收敛（tokens + SharedUI 覆盖）
3. 视觉美化（Card/Glass/品牌色）与动效试点（只选 1–2 个页面）
4. 固化回归 checklist：深色模式 + 英文环境 + 无障碍大字号 + Reduce Motion/Transparency 的关键路径点检


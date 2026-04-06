# 960 性能基线与排查流程

- 状态: Done
- 最后更新: 2026-04-06
- Phase: Phase 1 (持续)
- 模块: Quality
- 依赖: 无（可并行推进）
- 目标: 建立可重复、可对比、可复测的性能基线与排查流程，覆盖启动、列表、日历、健康仪表盘和设置页等高风险场景。
- 非目标: 不追求拍脑袋微优化；不在没有同一套基线复测前做结论。

补充说明：本任务产出的是“基线场景定义 + 复测流程”，不包含实测数值；数值基线应在后续具体采样与报告中持续维护。

## 交付物

- 基线场景清单：定义本 App 的 5 个必测场景、步骤、关注指标和通过口径。
- 排查 playbook：按 SwiftUI、数据层、系统集成三类给出检查路径。
- 复测模板：统一记录症状、复现、瓶颈、修复和复测命令。
- 工具约定：明确 Instruments 与 CLI 两条路线如何互相验证。

## 验收标准

- 每个基线场景都能用同一台设备、同一版本、同一步骤重复跑出结果。
- 每次性能问题都能写出“症状 → 复现 → 瓶颈 → 修复 → 复测”的完整记录。
- 优化前后可以用同一命令或同一 Instruments 录制方式做对比。

## 实施要点

### 基线场景

- **App cold launch to first frame（Home tab）**
  - 复现步骤：清理后台后冷启动 App，停在 Home tab 首帧出现为止。
  - 关注指标：首帧时间、启动期间 CPU 峰值、内存爬升、是否有明显白屏/卡住。
  - 成功标准：首帧稳定出现，无长时间空白、无明显主线程阻塞、无重复启动抖动。

- **Planning tab list scroll + filter switch**
  - 复现步骤：进入 Planning tab，连续滚动列表，再切换过滤条件 2-3 次。
  - 关注指标：滚动掉帧、卡顿段落、数据刷新时 CPU spikes、列表重建造成的内存增长。
  - 成功标准：滚动手感连续，过滤切换后列表能及时更新且不出现明显闪烁或跳回。

- **Calendar month/week navigation**
  - 复现步骤：在 Calendar 页面来回切换月视图/周视图，并横向或纵向快速翻页。
  - 关注指标：切换动画掉帧、布局重算成本、事件加载时的 I/O 和内存抖动。
  - 成功标准：切换稳定，视图状态不丢失，翻页过程中不出现明显停顿或重绘风暴。

- **Fitness dashboard open + day/week/month switch + refresh**
  - 复现步骤：打开 Fitness dashboard，切换 day/week/month，再触发 refresh。
  - 关注指标：图表渲染耗时、刷新期间 CPU 峰值、健康数据读取时长、内存是否持续增长。
  - 成功标准：切换后图表可用且响应顺畅，刷新不会阻塞 UI，也不会反复请求同一批数据。

- **Profile settings load（permission status）**
  - 复现步骤：打开 Profile/Settings 页面，观察权限状态加载与状态刷新。
  - 关注指标：首次加载耗时、权限查询是否阻塞主线程、状态更新是否触发额外重绘。
  - 成功标准：首次进入应先呈现明确加载态，再平滑补齐权限状态；权限检查不应造成明显卡顿。

### 排查 playbook

- **SwiftUI**
  - 检查 identity 是否稳定，尤其是 `ForEach`、`List`、`TabView`、条件分支切换时的 `id` 变化。
  - 检查 `@State` / `@Observable` 观察范围是否过宽，是否让无关子树跟着重绘。
  - 检查 `body` 是否包含重计算、同步格式化、日期/字符串转换、数组过滤或排序。
  - 检查 `.task` / `.onAppear` 是否重复触发，是否因为导航、刷新或 identity 变化而多次执行。

- **数据**
  - 检查 SwiftData fetch 是否过宽、是否一次拉太多字段、是否在视图刷新链路里频繁执行。
  - 检查 decoding、映射、排序、聚合是否跑在主线程。
  - 检查本地缓存是否足够，是否每次进入页面都重新算一遍同样的数据。
  - 检查文件/数据库 I/O 是否被 UI 线程直接触发。

- **系统集成**
  - HealthKit：确认读取是否批量化、是否只在需要时读取、是否避免频繁刷新同一范围的数据。
  - EventKit：确认日历同步是否拆分为小批次、是否避免在导航切换时重复同步。
  - Local Notifications：确认调度是否只在状态变化时执行，避免列表刷新导致重复排程。

### 工具与记录方式

- **Instruments 建议**
  - `Time Profiler`：定位 CPU 热点、主线程阻塞、重计算链路。
  - `SwiftUI`：观察 body 重新计算、视图失稳、过度 invalidation。
  - `Allocations`：观察页面切换、滚动、刷新后的内存增长与对象分配。
  - `Leaks`：确认刷新/离开页面后没有持续泄漏。

- **Before/after note**
  - 记录同一场景的“前”与“后”时，写清楚：设备、系统版本、App build、场景、录制工具、录制时长、最早看到的瓶颈点。
  - 同一问题至少保留一张截图或一段简短结论，方便回看“到底改善了什么”。

- **环境校验 / 日志采集命令**
  - UI 性能基线以 Instruments 录制为主；在缺少专门 perf/UI 测试时，CLI 更适合做“构建/测试环境一致性校验”和“收集可复现日志”。
  - 先生成工程，再跑测试，确保命令和 Xcode 工程状态一致：

```bash
cd ios-app/App/CoupleLife && xcodegen generate
```

```bash
cd ios-app/App/CoupleLife && set -o pipefail && xcodebuild test \
  -project CoupleLife.xcodeproj \
  -scheme CoupleLife \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.6' \
  2>&1 | tee /tmp/couplelife-performance-test.log
```

```bash
cd ios-app/App/CoupleLife && set -o pipefail && xcodebuild test \
  -project CoupleLife.xcodeproj \
  -scheme CoupleLife \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.6' \
  -only-testing:CoupleLifeTests/ProfileSettingsViewModelTests \
  2>&1 | tee /tmp/couplelife-performance-smoke.log
```

  - 需要更细粒度复现时，优先缩小到单个测试、单个页面或单个数据源，再记录同一条命令的前后差异。

### 报告模板

- 症状: 用户感知到什么卡顿、掉帧、等待或发热。
- 复现: 设备、系统版本、App 版本、页面、步骤、重复次数。
- 瓶颈: CPU / memory / I/O / SwiftUI invalidation / 主线程阻塞 / 系统集成调用。
- 修复: 改了什么，为什么能减少重绘、重算或重复读取。
- 复测命令: Instruments 录制方式或 CLI 命令，附保存路径与结果摘要。

## Skills 使用

- `$ios-performance-audit`: 用于制定定位路径、拆解热点、确认修复前后是否真正变快。
- `$xcode-simulator-debug`: 用于稳定模拟器/构建环境、统一复现条件并收集命令行日志。

## 实施记录

- 已将原始“性能基线与排查流程”补成可执行的 baseline 文档，覆盖 Home、Planning、Calendar、Fitness、Profile 五个核心场景。
- 已补齐 SwiftUI / 数据 / 系统集成三类排查维度，便于按症状快速归因，而不是直接尝试优化。
- 已补入 Instruments 建议与 CLI 日志采集模板，并加入报告模板，便于每次优化前后保持可对比的记录方式。

## 验证记录

- 已自检文档结构与 repo 的 Done-task 模式一致，包含 `状态`、`最后更新`、`Phase/模块/依赖/目标/非目标` 以及必需章节。
- 已确认命令示例采用 `set -o pipefail` 和 `2>&1 | tee` 形式，适合作为可复制复测模板。
- 已检查场景覆盖范围与需求一致，未引入额外功能或实现承诺。

## 已知风险/遗留

- 这是 baseline 与流程文档，不替代实际 Instruments 采样；真正的阈值仍应基于后续测量结果持续校准。
- App 的可用 simulator、OS 版本与 build 产物会随环境变化，命令中的 destination 需要按本机实际可用设备调整。
- 若后续某个场景引入新的数据源或系统能力，需要把它补进本 baseline，避免测试覆盖漂移。

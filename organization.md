# 项目组织说明（development organization）

本文档把 `project.md` 的产品与技术方案，落成可执行的开发任务结构，并约定后续代码与文档的组织方式。

执行规范与文档更新责任见 `workflow.md`（建议新 agent 先读该文件）。

## 0. 文件层级（当前与规划）

仓库根目录（文档优先）：

```text
.
├── project.md
├── organization.md
└── ios-app/
    └── tasks/
        ├── app-core/
        ├── data/
        ├── shared-ui/
        ├── home/
        ├── calendar/
        ├── planning/
        ├── fitness/
        ├── integrations/
        ├── couple/
        ├── profile/
        └── quality/
```

未来引入应用代码时（占位约定，不提前创建）：

```text
ios-app/
├── App/         # Swift/Xcode 项目与源码
├── Tests/       # XCTest
└── Assets/      # 图片/字体等资源
```

## 1. `project.md` 要点提炼

- 产品定位：情侣共同记录生活、安排计划、关注健康，并沉淀长期生活档案（记录/协作/洞察）。
- 首期三大板块：日历记录、待办计划、运动健康。
- 核心模型：`Record`（统一记录）、`Task/Goal`（计划与目标）、`HealthMetricSnapshot`（健康展示缓存）。
- 系统集成：EventKit（系统日历）、HealthKit（健康数据）、通知（本地通知），后续 CloudKit/Widget/Watch。
- 关键风险：权限体验、同步冲突、敏感数据边界、模型扩展失控。

## 2. 推荐代码架构约定（主流 iOS 分层）

目标：逻辑清晰、扩展性好、便于维护，并能按模块逐步演进。

建议采用“分层 + 模块文件夹”起步（先不强制拆 Swift Package）：

- Presentation：SwiftUI 页面、组件、交互状态、导航
- Domain：业务模型、用例（Use Cases）、规则（如可见性、同步策略）
- Data：SwiftData/Core Data、Repository、缓存与序列化
- Integration：EventKit/HealthKit/CloudKit/Notifications 等系统适配层

模块（对应 `ios-app/tasks/*` 的目录）：

- AppCore：应用骨架、路由、依赖注入、全局服务协议
- SharedUI：设计系统与通用组件
- Home：首页聚合视图
- Calendar：日历与记录
- Planning：待办与计划
- Fitness：运动与健康展示
- Integrations：与系统能力/云同步的适配与策略
- Couple：情侣空间、共享与权限边界
- Profile：设置、权限状态、隐私配置
- Quality：构建/调试/性能/无障碍等工程化清单

## 3. Skills 索引（任务文件按需引用）

这些 skills 位于 `~/.codex/skills/`，在任务执行时用于加速产出或排障：

- `$swiftui-feature-builder`：从需求/说明到可编译的 SwiftUI 页面与组件实现；适用于“新增页面/流程/组件”。
- `$swiftui-ui-refactor`：在不改变行为的前提下整理 SwiftUI 结构（拆分大 `body`、理清状态、提炼子视图）；适用于“优化与重构”。
- `$ios-liquid-glass`：给合适的 UI 表面加入玻璃材质/半透明分层风格，并保证可读性与无障碍回退；适用于“风格升级与一致性治理”。
- `$ios-performance-audit`：定位卡顿/掉帧/主线程阻塞/内存增长等运行时问题，并给出可验证的修复；适用于“列表、图表、健康读取、缓存策略”等性能敏感区。
- `$xcode-simulator-debug`：用 `xcodebuild` + Simulator 复现、定位并修复构建/运行/测试问题（scheme/destination/签名/崩溃等）；适用于“工程排障与稳定复现”。
- `$doc`：仅在需要创建/编辑 `.docx` 对外文档时使用；本项目日常开发文档默认 Markdown。

## 4. 任务文件模板（所有任务说明统一结构）

```md
# <编号> <任务标题>

- Phase: <Phase 1/2/3/4>
- 模块: <AppCore/Calendar/...>
- 状态: <Todo/In Progress/Blocked/Done>
- 最后更新: <YYYY-MM-DD>
- 依赖: <可选：相关任务编号>
- 目标: <一句话>
- 非目标: <明确不做什么，防止膨胀>

## 交付物
- <可运行的功能/页面/服务>

## 验收标准
- <可验证的行为与边界>

## 实施要点
- <关键设计决策：模型字段、同步策略、权限策略、UI 状态等>

## Skills 使用
- <$skill-name>: 目的...；场景...

## 实施记录
- 开工: <YYYY-MM-DD>
- 进展: <1-3 行>
- 下一步: <1 行>

## Definition of Done
- <最小 DoD 清单（可复现验证、边界覆盖、文档回填等）>

## 验证记录
- 命令: <如 xcodebuild ...>
- 手测: <关键路径 1-3 条>
- 遗留风险: <若有，1-3 条>

## 执行规范
- 见 `workflow.md`（任务状态流转、回填规则、最小增量原则）
```

## 5. 任务索引（按模块）

### AppCore

- [100 App 骨架与 Tab](ios-app/tasks/app-core/100-app-scaffold-and-tabs.md)
- [110 依赖注入、路由与核心服务协议](ios-app/tasks/app-core/110-di-routing-and-appcore-services.md)

### Data

- [200 核心领域模型 v1](ios-app/tasks/data/200-domain-models-v1.md)
- [210 SwiftData 存储与仓储层](ios-app/tasks/data/210-swiftdata-store-and-repositories.md)

### SharedUI

- [300 设计系统与通用组件 v1](ios-app/tasks/shared-ui/300-design-system-v1.md)
- [310 Liquid Glass 风格封装](ios-app/tasks/shared-ui/310-liquid-glass-style.md)

### Home

- [350 首页聚合仪表盘 v1](ios-app/tasks/home/350-home-dashboard-v1.md)

### Calendar

- [400 日历视图与日期导航 v1](ios-app/tasks/calendar/400-calendar-views-v1.md)
- [410 记录 CRUD 与快捷打卡 v1](ios-app/tasks/calendar/410-record-crud-v1.md)

### Planning

- [500 任务系统 v1](ios-app/tasks/planning/500-task-system-v1.md)
- [510 计划视图与筛选 v1](ios-app/tasks/planning/510-planning-views-and-filters.md)

### Fitness

- [600 HealthKit 服务与缓存 v1](ios-app/tasks/fitness/600-healthkit-service-and-cache-v1.md)
- [610 运动健康仪表盘 v1](ios-app/tasks/fitness/610-fitness-dashboard-v1.md)

### Integrations

- [700 EventKit 单向同步（任务 -> 系统日历）v1](ios-app/tasks/integrations/700-eventkit-sync-oneway-v1.md)
- [710 本地通知调度 v1](ios-app/tasks/integrations/710-local-notifications-v1.md)
- [720 CloudKit 同步与共享 v1](ios-app/tasks/integrations/720-cloudkit-sync-v1.md)
- [730 WidgetKit 小组件 v1](ios-app/tasks/integrations/730-widgetkit-v1.md)

### Couple

- [800 情侣空间与成员关系 v1](ios-app/tasks/couple/800-couple-space-and-membership-v1.md)
- [810 共享可见性与敏感数据边界 v1](ios-app/tasks/couple/810-sharing-visibility-and-permissions-v1.md)

### Profile

- [900 设置、隐私与权限状态 v1](ios-app/tasks/profile/900-settings-privacy-permissions-v1.md)

### Quality

- [950 xcodebuild + Simulator 排障手册](ios-app/tasks/quality/950-xcodebuild-simulator-playbook.md)
- [960 性能基线与排查流程](ios-app/tasks/quality/960-performance-audit-baseline.md)
- [970 无障碍 QA 清单](ios-app/tasks/quality/970-accessibility-qa-checklist.md)

## 6. Milestone 视图（按 Phase）

### Phase 1: MVP

- [100 App 骨架与 Tab](ios-app/tasks/app-core/100-app-scaffold-and-tabs.md)
- [110 依赖注入、路由与核心服务协议](ios-app/tasks/app-core/110-di-routing-and-appcore-services.md)
- [200 核心领域模型 v1](ios-app/tasks/data/200-domain-models-v1.md)
- [210 SwiftData 存储与仓储层](ios-app/tasks/data/210-swiftdata-store-and-repositories.md)
- [300 设计系统与通用组件 v1](ios-app/tasks/shared-ui/300-design-system-v1.md)
- [310 Liquid Glass 风格封装](ios-app/tasks/shared-ui/310-liquid-glass-style.md)（可插入：视觉升级不阻塞核心功能）
- [350 首页聚合仪表盘 v1](ios-app/tasks/home/350-home-dashboard-v1.md)
- [400 日历视图与日期导航 v1](ios-app/tasks/calendar/400-calendar-views-v1.md)
- [410 记录 CRUD 与快捷打卡 v1](ios-app/tasks/calendar/410-record-crud-v1.md)
- [500 任务系统 v1](ios-app/tasks/planning/500-task-system-v1.md)
- [510 计划视图与筛选 v1](ios-app/tasks/planning/510-planning-views-and-filters.md)
- [600 HealthKit 服务与缓存 v1](ios-app/tasks/fitness/600-healthkit-service-and-cache-v1.md)
- [610 运动健康仪表盘 v1](ios-app/tasks/fitness/610-fitness-dashboard-v1.md)
- [700 EventKit 单向同步（任务 -> 系统日历）v1](ios-app/tasks/integrations/700-eventkit-sync-oneway-v1.md)
- [710 本地通知调度 v1](ios-app/tasks/integrations/710-local-notifications-v1.md)
- [900 设置、隐私与权限状态 v1](ios-app/tasks/profile/900-settings-privacy-permissions-v1.md)
- [950 xcodebuild + Simulator 排障手册](ios-app/tasks/quality/950-xcodebuild-simulator-playbook.md)
- [960 性能基线与排查流程](ios-app/tasks/quality/960-performance-audit-baseline.md)
- [970 无障碍 QA 清单](ios-app/tasks/quality/970-accessibility-qa-checklist.md)

### Phase 2: 情侣共享

- [800 情侣空间与成员关系 v1](ios-app/tasks/couple/800-couple-space-and-membership-v1.md)
- [810 共享可见性与敏感数据边界 v1](ios-app/tasks/couple/810-sharing-visibility-and-permissions-v1.md)
- [720 CloudKit 同步与共享 v1](ios-app/tasks/integrations/720-cloudkit-sync-v1.md)

### Phase 3: 数据洞察

- 以 `Home/Calendar/Planning/Fitness` 为基础追加：周报/月报、趋势洞察、关联分析、个性化提醒（后续再拆任务文件）

### Phase 4: 生态增强

- [730 WidgetKit 小组件 v1](ios-app/tasks/integrations/730-widgetkit-v1.md)
- Apple Watch / Live Activities（后续再拆任务文件）

# CoupleLife (iOS)

一款面向情侣的日常记录与计划管理 App（SwiftUI + SwiftData），以 **Phase 1 (MVP)** 为当前迭代目标。

## 当前进度（截至 2026-03-28）

已完成（核心可用链路）：
- App 骨架与 Tab 信息架构
- SwiftData 数据层：领域模型与仓储
- SharedUI：设计 Token 与通用组件
- Home：首页聚合摘要 + 健康数据缓存展示
- Calendar：日历视图 + 记录 CRUD
- Planning：任务系统 v1 + 计划视图/筛选
- Integrations：
  - HealthKit：按需授权 + day/week/month 指标缓存（模拟器走降级路径；真机验收更可靠）
  - EventKit：任务 -> 系统日历 单向同步 v1（用户手动开启后写入）

进行中 / 下一步：
- `610` 运动健康仪表盘 v1
- `710` 本地通知调度 v1
- `900` 设置、隐私与权限状态 v1

## 开发与验证

工程使用 `xcodegen` 生成 Xcode Project：
```bash
cd ios-app/App/CoupleLife
xcodegen generate
```

运行单元测试：
```bash
cd ios-app/App/CoupleLife
xcodebuild test -project CoupleLife.xcodeproj -scheme CoupleLife -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.6'
```

说明：
- HealthKit / EventKit 的权限弹窗与数据可用性在模拟器和真机上可能不同；涉及系统能力的最终验收以真机为准。

## 仓库结构

- `ios-app/tasks/`：任务与实现记录（文档优先）
- `ios-app/App/`：iOS App 源码（Xcode 工程在 `ios-app/App/CoupleLife/`）

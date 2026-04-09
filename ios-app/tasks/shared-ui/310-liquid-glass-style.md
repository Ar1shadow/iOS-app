# 310 Liquid Glass 风格封装

- Phase: Phase 1.5 (可插入) / Phase 2
- 模块: SharedUI
- 状态: Done
- 最后更新: 2026-04-09
- 依赖: 300
- 目标: 在合适的 UI 表面引入玻璃材质与层次感（Liquid Glass 风格），并以可复用的方式封装，保证可读性与无障碍回退。
- 非目标: 不将玻璃效果铺满全应用；不使用复杂且不可控的自定义 blur 堆叠。

## 交付物

- 可复用的 glass 样式封装（modifier 或样式类型），用于卡片/工具条/浮层
- 可读性检查清单：亮/暗背景、滚动内容、对比度、点击区域
- 在 1-2 个典型页面落地试点（例如首页卡片或运动摘要卡片）

## 验收标准

- 开启“降低透明度/增加对比度”等设置时仍可读且不崩坏
- 样式调用点少且集中，后续统一改动不需要全局搜索替换

## 实施要点

- 只给“需要层次”的容器用 glass：导航 chrome、浮动控件、摘要卡片等
- 与品牌色/信息层级协同：玻璃只做承载，不抢内容视觉权重

## Skills 使用

- `$ios-liquid-glass`: 用于选择玻璃应用位置、具体样式配方与失败模式检查；适用于“风格落地与可读性治理”。
- `$swiftui-ui-refactor`: 用于把玻璃样式集中封装成少量可复用入口；适用于“避免效果散落与维护成本上升”。

## 实施记录

- 完成: 新增 `SharedGlassSurfaceStyle` 与 `sharedGlassSurface(_:)` modifier，集中封装 `.cardOverlay` 与 `.panel` 两种使用面。
- 完成: 首页摘要卡片改用 `.sharedGlassSurface(.cardOverlay)`，移除 `HomeTab` 本地 glass modifier。
- 完成: 运动页 bucket picker 与趋势卡改用 `.sharedGlassSurface(.panel)`，移除 `FitnessDashboardView` 本地 glass modifier。
- 可读性: modifier 内置 `accessibilityReduceTransparency` 回退；降低透明度时使用普通 surface 背景，card overlay 使用背景材质而不是覆盖文字，避免不可读材质叠加。

## 验证记录

- 命令: `xcodebuild test -quiet -project ios-app/App/CoupleLife/CoupleLife.xcodeproj -scheme CoupleLife -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.6' -derivedDataPath /tmp/CoupleLifeDerivedData-final`
- 结果: 通过，exit code 0；当时仍有既有 warning：widget extension `CFBundleVersion` 与宿主 app 不一致。
- 补充: 合入 main 后新增主 app 显式 `Info.plist` 修复版本号 warning，并以 `/tmp/CoupleLifeDerivedData-main-final4` 重跑全量测试通过。
- 手测: 未做 Simulator 截图/交互检查。
- 遗留风险: 未覆盖“增加对比度”系统设置的视觉验收；后续如果扩大到更多页面，应先复用当前 modifier，不再新增页面内私有 glass modifier。

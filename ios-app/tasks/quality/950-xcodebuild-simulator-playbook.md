# 950 xcodebuild + Simulator 排障手册

- Phase: Phase 1 (MVP)
- 模块: Quality
- 依赖: 无
- 目标: 沉淀一套可复用的构建/运行/测试排障流程，减少“只在某台机器/某次点击”才能复现的问题。
- 非目标: 不搭建 CI；不做复杂脚本化（可后续再补）。

## 交付物

- 常见问题分类：scheme/destination、Simulator 启动、编译错误、运行时崩溃、测试失败、签名/能力配置
- 最小复现原则：用最窄命令还原问题（build/test/run）
- 日志裁剪方法：抓住第一个 actionable error，而不是最后的级联错误

## 验收标准

- 新成员按文档能复现并定位常见构建问题
- 每次排障输出包含：命令、环境、首个错误、结论与复测方式

## 实施要点

- 优先 CLI 复现，减少对 Xcode GUI 状态的依赖
- 若环境支持 XcodeBuildMCP：优先用它检查 schemes/destinations/build settings，再决定命令

## Skills 使用

- `$xcode-simulator-debug`: 用于把排障流程落成可执行步骤并指导定位；适用于“构建/运行/测试的系统化排查”。


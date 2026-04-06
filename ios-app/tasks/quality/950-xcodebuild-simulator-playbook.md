# 950 xcodebuild + Simulator 排障手册

- 状态: Done
- 最后更新: 2026-04-06
- Phase: Phase 1 (MVP)
- 模块: Quality
- 依赖: 无
- 目标: 沉淀一套可复用的构建/运行/测试排障流程，减少“只在某台机器/某次点击”才能复现的问题。
- 非目标: 不搭建 CI；不做复杂脚本化（可后续再补）。

## 交付物

- 可直接复制的排障命令：`xcodegen`、`xcodebuild -list`、`xcrun simctl`、`build/test` 最小复现
- 常见问题分类：scheme/destination、Simulator 启动、编译错误、运行时崩溃、测试失败、签名/能力配置、SPM 缓存
- 诊断模板：环境快照 + 命令 + 第一个 actionable error + 结论 + 复测方式
- 日志裁剪方法：优先抓“第一个 actionable error”，不要只看最后的级联报错

## 验收标准

- 新成员按文档能复现并定位常见构建问题
- 每次排障输出都能写出：命令、环境快照、首个错误、结论与复测方式
- 文档中的命令可以直接粘贴执行，不依赖 Xcode GUI 的隐含状态

## 实施要点

- 优先 CLI 复现，减少对 Xcode GUI 状态的依赖
- 先确认 scheme、destination、runtime，再跑 build/test；不要先猜问题
- 先看最早的失败点：编译错误、签名错误、Simulator boot、测试断言，避免被后续错误干扰
- 若环境支持 XcodeBuildMCP：优先用它检查 schemes/destinations/build settings，再决定命令
- 当命中 device 构建、签名或能力报错时，先确认是不是误把 Simulator 任务跑到了真机目标上

### 命令速查

```bash
cd ios-app/App/CoupleLife && xcodegen generate
cd ios-app/App/CoupleLife && xcodebuild -list -project CoupleLife.xcodeproj
cd ios-app/App/CoupleLife && xcodebuild -showdestinations -project CoupleLife.xcodeproj -scheme CoupleLife
```

```bash
xcrun simctl list devices available
xcrun simctl list runtimes
xcrun simctl list devicetypes
```

先从 `xcodebuild -showdestinations` 或 `xcrun simctl list devices available` 复制一条真实可用的 destination/UDID，再替换下面示例（设备名与 OS 版本在不同机器上不一定存在）。

```bash
cd ios-app/App/CoupleLife && set -o pipefail && xcodebuild build \
  -project CoupleLife.xcodeproj \
  -scheme CoupleLife \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.6' \
  2>&1 | tee /tmp/couplelife-build.log
```

```bash
cd ios-app/App/CoupleLife && set -o pipefail && xcodebuild test \
  -project CoupleLife.xcodeproj \
  -scheme CoupleLife \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.6' \
  -only-testing:CoupleLifeTests/ProfileSettingsViewModelTests \
  -resultBundlePath /tmp/CoupleLife.xcresult \
  2>&1 | tee /tmp/couplelife-test.log
```

```bash
# 更稳：用 UDID boot，避免同名设备/多 runtime 时歧义
xcrun simctl boot 5EF18BBB-1C49-45C8-BBD4-A831BDDA53B6
xcrun simctl bootstatus 5EF18BBB-1C49-45C8-BBD4-A831BDDA53B6 -b
```

### 环境快照模板

- Host: macOS 版本、芯片型号、可用磁盘
- Xcode: `xcodebuild -version`
- Scheme: `xcodebuild -list -project ...` 的目标 scheme
- Destination: `xcrun simctl list devices available` 选中的 simulator
- Command: 复制的完整命令
- First actionable error: 最早的第一条真正错误
- Result bundle: `-resultBundlePath` 生成的位置
- Conclusion: 这次修的是 scheme、destination、cache、签名还是测试本身

### 常见故障分类

- scheme/destination mismatch：先看 `xcodebuild -list` 和 `xcrun simctl list devices available`，确认 scheme 存在且 destination 是 Simulator，不要把真机目标当成模拟器目标。
- Simulator boot 问题：先 `xcrun simctl boot`，再用 `bootstatus -b` 等待就绪；如果反复失败，优先换一个设备/OS 组合验证。
- CoreSimulatorService connection invalid / 无法发现 runtimes：如果 `simctl` 输出 “CoreSimulatorService connection became invalid / Unable to discover any Simulator runtimes”，先退出 Simulator，再重启 CoreSimulator 服务或重启机器，避免把问题误判为工程配置错误。
  ```bash
  killall com.apple.CoreSimulator.CoreSimulatorService || true
  # 若仍无效，再考虑 killall -9 ... 或直接重启机器
  ```

以下清理命令会中断当前 Simulator 会话，且部分命令会影响其他 Xcode 工程；仅在已保留首个错误日志后再执行。

- DerivedData 污染：删除当前工程对应的 DerivedData 后重试，避免旧产物掩盖真实错误。
  ```bash
  rm -rf ~/Library/Developer/Xcode/DerivedData/CoupleLife-*
  ```
- Test flakes：先缩小到单测或单类，必要时只跑 `-only-testing` 的最小集合，再看 `tee` 里的首个失败断言。
- Signing/capabilities：如果错误里出现签名、entitlements、profile，先确认是不是误用了 device destination；Simulator 构建通常不该走真机签名链路。
- SPM caches：依赖解析异常时，清理 Package 缓存与重新解析，再重跑 build/test。
  ```bash
  rm -rf ~/Library/Developer/Xcode/DerivedData/CoupleLife-*/SourcePackages
  # 最后手段：会清掉所有工程共享的 SwiftPM 全局缓存
  rm -rf ~/Library/Caches/org.swift.swiftpm
  ```

## Skills 使用

- `$xcode-simulator-debug`: 用于把排障流程落成可执行步骤并指导定位；适用于“构建/运行/测试的系统化排查”。

## 实施记录

- 已补齐一份可执行的 `xcodebuild + Simulator` 排障 playbook，覆盖 project 生成、scheme/destination 识别、最小复现、日志采集与常见故障分类。
- 已把“先找第一个 actionable error”和“环境快照”写成统一模板，便于跨机器/跨时间复现。
- 已补入常见清理项与误用场景说明，方便在 DerivedData、SPM 缓存、签名配置或 device/build 误路由时快速收敛。

## 验证记录

- 内容自检：确认包含 front-matter、指定章节、可复制命令、常见失败分类、环境快照模板与复测口径。
- 命令可执行性检查（本机）：`xcodebuild -version`、`xcodebuild -list -project CoupleLife.xcodeproj`、`xcrun simctl list devices available` 可正常运行。
- Markdown 自检：标题层级、列表与代码块结构保持单文件可读，适合直接作为任务文档引用。

## 已知风险/遗留

- 本文是通用排障手册，不绑定具体 Scheme/Simulator 名称；实际项目可用时需按当前 Xcode 版本调整 destination。
- 若后续引入 CI 或脚本化封装，应补充对应的命令入口与结果产物路径。
- Simulator/SDK 版本会随 Xcode 更新而变化，示例命令中的设备名和 OS 版本应按本机环境替换。

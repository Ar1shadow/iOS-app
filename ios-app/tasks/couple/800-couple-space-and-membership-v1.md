# 800 情侣空间与成员关系 v1

- Phase: Phase 2 (情侣共享)
- 模块: Couple
- 状态: Done
- 最后更新: 2026-04-06
- 依赖: 200、210、110
- 目标: 落地 `User/CoupleSpace/Membership` 的最小可用能力，为共享任务/共享记录与 CloudKit 同步建立地基。
- 非目标: 不做复杂账号体系（优先依赖 Apple 生态与 CloudKit）；不做复杂邀请体系（先 MVP）。

## 交付物

- 情侣空间创建与加入流程（产品可选：邀请码/链接/同设备演示等最小实现）
- 基础角色语义（如 owner/member）与加入时间
- 基础信息：纪念日、空间名称等（按 MVP）

## 验收标准

- 用户能够在应用内形成“共享空间”的明确状态（有/无）
- 后续共享数据能够关联到 `coupleSpaceId`
- UI 文案与隐私说明清晰，不误导用户“默认共享”

## 实施要点

- 共享空间的存在应影响 UI（例如显示“我/TA/我们”的切换入口），但首期可先做最小展示
- 为 CloudKit 的共享数据库做准备（720）

## Skills 使用

- `$swiftui-feature-builder`: 用于实现创建/加入流程与基础设置 UI；适用于“流程型页面与表单”。

## 实施记录

- 开工: 2026-04-06
- 进展: 新增 SwiftData `CoupleSpace` / `Membership` 模型、对应本地仓储、`CoupleSpaceService` 与 `UserDefaults` 活跃空间存储，并把 Schema 接入 `ModelContainerFactory`。
- 进展: 在 `ProfileTab` 增加最小情侣空间区块，支持创建空间、输入空间 ID 加入、显示活跃状态/角色/空间 ID，以及离开后清空本地 active 状态。
- 下一步: 后续任务把 `activeCoupleSpaceId` 继续接到共享任务/共享记录读写路径，并在 720 接入 CloudKit。

## 实施要点补充

- 数据路径: `ProfileTab/CoupleSpaceSection -> CoupleSpaceViewModel -> CoupleSpaceService -> CoupleSpaceRepository/MembershipRepository + ActiveCoupleSpaceStore`
- UI 状态: 覆盖无空间 / 有活跃空间 / 表单提交失败三类状态；当前不额外引入“自动共享已开启”的任何暗示性文案。
- 降级策略: 若 `activeCoupleSpaceId` 指向的本地空间或 membership 缺失，服务会自动清理这个 dangling 状态并回退到“无空间”。

## 验证记录

- 命令: `cd ios-app/App/CoupleLife && xcodegen generate`
- 结果: `Created project at .../ios-app/App/CoupleLife/CoupleLife.xcodeproj`
- 命令: `cd ios-app/App/CoupleLife && xcodebuild test -project CoupleLife.xcodeproj -scheme CoupleLife -destination 'platform=iOS Simulator,id=5EF18BBB-1C49-45C8-BBD4-A831BDDA53B6' -derivedDataPath /tmp/CoupleLifeDerivedData-800 -only-testing:CoupleLifeTests/CoupleSpaceServiceTests`
- 结果: `** TEST SUCCEEDED **`（4 个测试通过）
- 手工检查点: 新增 `CoupleSpaceServiceTests` 覆盖创建、加入、离开、悬空 active id 清理；`ProfileTab` 文案明确声明“当前版本不会自动共享任务/日历/健康数据”。

## 已知风险/遗留

- 当前加入流程是本地同设备演示版，只能加入当前设备里已存在的空间 ID，尚未接入邀请码/链接/CloudKit。
- `leaveActiveSpace()` 当前仅停用本地 active space（清空 `activeCoupleSpaceId`），不删除本地 membership 或 CoupleSpace 记录，便于同设备演示“停用后再加入”。
- WidgetKit 扩展在 Simulator 安装时对 `Info.plist` 键有更严格校验；本次已修复导致测试宿主安装失败的问题，但仍建议后续补桌面/锁屏手测 Widget 族大小与排版。

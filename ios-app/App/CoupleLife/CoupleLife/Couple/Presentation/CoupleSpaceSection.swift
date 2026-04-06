import SwiftUI
import UIKit

struct CoupleSpaceSection: View {
    @ObservedObject var viewModel: CoupleSpaceViewModel

    @State private var isPresentingCreateSheet = false
    @State private var isPresentingJoinSheet = false
    @State private var createName = ""
    @State private var createHasAnniversaryDate = false
    @State private var createAnniversaryDate = Date()
    @State private var joinSpaceID = ""

    var body: some View {
        SharedCard {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                SharedSectionHeader("情侣空间", subtitle: "先建立“有/无共享空间”的明确状态；当前版本不会自动共享数据")

                if let activeSpace = viewModel.status.activeSpace {
                    activeSpaceContent(activeSpace)
                } else {
                    inactiveContent
                }

                if let copiedSpaceID = viewModel.copiedSpaceID {
                    Text("已复制空间 ID：\(copiedSpaceID)")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColorToken.green.color)
                }
            }
        }
        .sheet(isPresented: $isPresentingCreateSheet) {
            NavigationStack {
                Form {
                    Section("基础信息") {
                        TextField("例如：我们的日常空间", text: $createName)

                        Toggle("添加纪念日", isOn: $createHasAnniversaryDate)

                        if createHasAnniversaryDate {
                            DatePicker(
                                "纪念日",
                                selection: $createAnniversaryDate,
                                displayedComponents: .date
                            )
                        }
                    }

                    Section("隐私说明") {
                        Text("创建空间只会在本机记录空间与成员状态，不会自动共享任务、日历内容、健康数据或通知设置。")
                    }
                }
                .navigationTitle("创建空间")
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("取消") {
                            resetCreateDraft()
                            isPresentingCreateSheet = false
                        }
                    }

                    ToolbarItem(placement: .topBarTrailing) {
                        Button("创建") {
                            Task {
                                await viewModel.createSpace(
                                    name: createName,
                                    anniversaryDate: createHasAnniversaryDate ? createAnniversaryDate : nil
                                )
                                if viewModel.status.hasActiveSpace {
                                    resetCreateDraft()
                                    isPresentingCreateSheet = false
                                }
                            }
                        }
                        .disabled(viewModel.isPerformingAction)
                    }
                }
            }
        }
        .sheet(isPresented: $isPresentingJoinSheet) {
            NavigationStack {
                Form {
                    Section("输入空间 ID") {
                        TextField("例如：SPACE123", text: $joinSpaceID)
                            .textInputAutocapitalization(.characters)
                            .autocorrectionDisabled()
                    }

                    Section("说明") {
                        Text("这是本地演示版加入流程。只有当前设备里已经存在的空间 ID 才能加入，不代表数据已经开始共享。")
                    }
                }
                .navigationTitle("加入空间")
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("取消") {
                            joinSpaceID = ""
                            isPresentingJoinSheet = false
                        }
                    }

                    ToolbarItem(placement: .topBarTrailing) {
                        Button("加入") {
                            Task {
                                await viewModel.joinSpace(id: joinSpaceID)
                                if viewModel.status.hasActiveSpace {
                                    joinSpaceID = ""
                                    isPresentingJoinSheet = false
                                }
                            }
                        }
                        .disabled(viewModel.isPerformingAction)
                    }
                }
            }
        }
        .alert(
            "操作未完成",
            isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { newValue in
                    if !newValue {
                        viewModel.clearError()
                    }
                }
            ),
            actions: {
                Button("知道了", role: .cancel) {
                    viewModel.clearError()
                }
            },
            message: {
                Text(viewModel.errorMessage ?? "")
            }
        )
    }

    @ViewBuilder
    private func activeSpaceContent(_ activeSpace: ActiveCoupleSpace) -> some View {
        SettingsStatusRow(
            title: "当前状态",
            subtitle: activeSummary(for: activeSpace),
            tagText: "Active space",
            tagColorToken: .green,
            tagSymbolName: "person.2.fill"
        )

        Divider()

        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("可分享空间 ID")
                .font(AppTypography.body.weight(.semibold))
                .foregroundStyle(AppColorToken.textPrimary.color)

            HStack(spacing: AppSpacing.md) {
                Text(activeSpace.id)
                    .font(.system(.body, design: .monospaced).weight(.semibold))
                    .foregroundStyle(AppColorToken.textPrimary.color)

                Spacer(minLength: AppSpacing.md)

                Button("复制") {
                    UIPasteboard.general.string = activeSpace.id
                    viewModel.markCopied(spaceID: activeSpace.id)
                }
                .buttonStyle(.bordered)
            }
        }

        if let anniversaryDate = activeSpace.anniversaryDate {
            Divider()

            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text("纪念日")
                    .font(AppTypography.body.weight(.semibold))
                    .foregroundStyle(AppColorToken.textPrimary.color)
                Text(anniversaryDate.formatted(date: .abbreviated, time: .omitted))
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColorToken.textSecondary.color)
            }
        }

        Divider()

        Text("注意：当前版本只记录情侣空间与成员状态，不会自动把任务、日历、健康数据或通知偏好共享给对方。")
            .font(AppTypography.caption)
            .foregroundStyle(AppColorToken.textSecondary.color)

        Button("停用当前空间") {
            Task { await viewModel.leaveActiveSpace() }
        }
        .buttonStyle(.bordered)
        .disabled(viewModel.isPerformingAction)
    }

    private var inactiveContent: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            SettingsStatusRow(
                title: "当前状态",
                subtitle: "还没有激活情侣空间。你可以先创建一个本地空间，或输入已存在的空间 ID 加入演示。没有激活空间时，应用会保持“未共享”状态。",
                tagText: "No space",
                tagColorToken: .slate,
                tagSymbolName: "person.crop.circle.badge.questionmark"
            )

            HStack(spacing: AppSpacing.md) {
                Button("创建空间") {
                    isPresentingCreateSheet = true
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.isPerformingAction)

                Button("加入空间") {
                    isPresentingJoinSheet = true
                }
                .buttonStyle(.bordered)
                .disabled(viewModel.isPerformingAction)
            }

            Text("隐私说明：即使创建或加入空间，当前版本也只是在本机保存一个“共享关系”状态，不会自动把任何记录同步给伴侣。")
                .font(AppTypography.caption)
                .foregroundStyle(AppColorToken.textSecondary.color)
        }
    }

    private func activeSummary(for activeSpace: ActiveCoupleSpace) -> String {
        let roleText = activeSpace.membershipRole == .owner ? "创建者" : "成员"
        return "已激活空间“\(activeSpace.name)”。你的角色是\(roleText)，加入时间为 \(activeSpace.joinedAt.formatted(date: .abbreviated, time: .omitted))。"
    }

    private func resetCreateDraft() {
        createName = ""
        createHasAnniversaryDate = false
        createAnniversaryDate = Date()
    }
}

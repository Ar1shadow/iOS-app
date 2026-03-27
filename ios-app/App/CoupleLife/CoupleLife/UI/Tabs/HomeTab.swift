import SwiftUI

struct HomeTab: View {
    private let sampleTypes: [RecordType] = [
        .water, .sleep, .activity
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.xl) {
                    SharedSectionHeader("今日记录", subtitle: "SharedUI 组件示例")

                    SharedCard {
                        VStack(spacing: AppSpacing.sm) {
                            ForEach(sampleTypes, id: \.self) { type in
                                let style = type.visualStyle
                                SharedListRow(
                                    title: style.title,
                                    subtitle: "来自 RecordType 映射",
                                    symbolName: style.symbolName,
                                    colorToken: style.colorToken,
                                    badgeText: "已配置"
                                )
                            }
                        }
                    }

                    SharedSectionHeader("状态")

                    SharedLoadingStateView(title: "正在同步今日摘要…")

                    SharedEmptyStateView(
                        title: "还没有更多数据",
                        message: "后续页面将优先复用 SharedUI 组件来构建空状态。",
                        symbolName: "tray"
                    )
                }
                .padding(.horizontal, AppSpacing.screenHorizontal)
                .padding(.vertical, AppSpacing.lg)
            }
            .background(AppColorToken.background.color.ignoresSafeArea())
                .navigationTitle("首页")
        }
    }
}

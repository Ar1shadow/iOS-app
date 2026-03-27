import SwiftUI

struct HomeTab: View {
    static let showcaseSectionTitle = "SharedUI 组件展示"
    static let showcaseSectionSubtitle = "静态占位展示，不代表真实记录数据"

    private let showcaseRows: [RecordType] = [.water, .sleep]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.xl) {
                    SharedSectionHeader(Self.showcaseSectionTitle, subtitle: Self.showcaseSectionSubtitle)

                    SharedCard {
                        VStack(spacing: AppSpacing.sm) {
                            ForEach(showcaseRows, id: \.self) { type in
                                let style = type.visualStyle
                                SharedListRow(
                                    title: "\(style.title)样式",
                                    subtitle: "用于设计系统组件演示",
                                    symbolName: style.symbolName,
                                    colorToken: style.colorToken,
                                    badgeText: "示例"
                                )
                            }
                        }
                    }

                    SharedSectionHeader("状态")

                    SharedTag(text: "标签组件示例", colorToken: .indigo, symbolName: "tag.fill")

                    SharedLoadingStateView(title: "加载态组件示例")

                    SharedEmptyStateView(
                        title: "首页功能将在后续任务实现",
                        message: "当前页面用于展示 SharedUI 基础组件组合方式。",
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

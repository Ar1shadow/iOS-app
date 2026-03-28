import SwiftUI

struct CalendarTab: View {
    @StateObject private var viewModel: CalendarViewModel

    init(
        recordRepository: any RecordRepository,
        calendar: Calendar = .current,
        ownerUserId: String = CurrentUser.id,
        nowProvider: @escaping () -> Date = Date.init
    ) {
        let service = DefaultCalendarRecordSummaryService(recordRepository: recordRepository, calendar: calendar)
        _viewModel = StateObject(
            wrappedValue: CalendarViewModel(
                service: service,
                calendar: calendar,
                ownerUserId: ownerUserId,
                nowProvider: nowProvider
            )
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.xl) {
                    SharedCard {
                        VStack(alignment: .leading, spacing: AppSpacing.lg) {
                            SharedSectionHeader("日期导航", subtitle: viewModel.selectedDateSubtitle)
                            headerControls
                            modePicker
                        }
                    }

                    if let loadErrorMessage = viewModel.loadErrorMessage {
                        SharedEmptyStateView(
                            title: "日历摘要暂不可用",
                            message: loadErrorMessage,
                            symbolName: "exclamationmark.triangle"
                        )
                    }

                    if viewModel.isLoading {
                        SharedLoadingStateView(title: "正在加载可见日期摘要…")
                    }

                    switch viewModel.displayMode {
                    case .month:
                        monthView
                    case .week:
                        weekView
                    case .day:
                        dayView
                    }

                    NavigationLink {
                        CalendarDayDetailView(
                            date: viewModel.selectedDate,
                            records: viewModel.selectedDayRecords,
                            subtitle: viewModel.selectedDateSubtitle
                        )
                    } label: {
                        SharedCard {
                            HStack(spacing: AppSpacing.md) {
                                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                                    Text("查看当天详情")
                                        .font(AppTypography.sectionTitle)
                                        .foregroundStyle(AppColorToken.textPrimary.color)
                                    Text(viewModel.summaryBadgeText(for: viewModel.selectedDate))
                                        .font(AppTypography.body)
                                        .foregroundStyle(AppColorToken.textSecondary.color)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.body.weight(.semibold))
                                    .foregroundStyle(AppColorToken.textSecondary.color)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("进入当天详情占位页")
                }
                .padding(.horizontal, AppSpacing.screenHorizontal)
                .padding(.vertical, AppSpacing.lg)
            }
            .background(AppColorToken.background.color.ignoresSafeArea())
            .navigationTitle("日历")
        }
        .task {
            await viewModel.loadIfNeeded()
        }
    }

    private var headerControls: some View {
        HStack(spacing: AppSpacing.md) {
            Button {
                viewModel.shiftVisiblePeriod(by: -1)
            } label: {
                Image(systemName: "chevron.left")
                    .font(.body.weight(.semibold))
                    .frame(width: 40, height: 40)
            }
            .buttonStyle(.bordered)
            .accessibilityLabel("上一周期")

            VStack(spacing: AppSpacing.xs) {
                Text(viewModel.headerTitle)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(AppColorToken.textPrimary.color)
                Text(viewModel.fullDateLabel(for: viewModel.selectedDate))
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColorToken.textSecondary.color)
            }
            .frame(maxWidth: .infinity)

            Button {
                viewModel.shiftVisiblePeriod(by: 1)
            } label: {
                Image(systemName: "chevron.right")
                    .font(.body.weight(.semibold))
                    .frame(width: 40, height: 40)
            }
            .buttonStyle(.bordered)
            .accessibilityLabel("下一周期")
        }
    }

    private var modePicker: some View {
        Picker("视图模式", selection: Binding(
            get: { viewModel.displayMode },
            set: { viewModel.setDisplayMode($0) }
        )) {
            ForEach(CalendarViewModel.DisplayMode.allCases) { mode in
                Text(mode.rawValue).tag(mode)
            }
        }
        .pickerStyle(.segmented)
    }

    private var monthView: some View {
        SharedCard {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                SharedSectionHeader("月视图", subtitle: "今日、选中日期与记录标记已区分")

                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: AppSpacing.sm), count: 7), spacing: AppSpacing.sm) {
                    ForEach(viewModel.weekdaySymbols, id: \.self) { symbol in
                        Text(symbol)
                            .font(AppTypography.caption.weight(.semibold))
                            .foregroundStyle(AppColorToken.textSecondary.color)
                            .frame(maxWidth: .infinity)
                    }

                    ForEach(viewModel.monthGrid.days) { day in
                        Button {
                            viewModel.selectDate(day.date)
                        } label: {
                            CalendarMonthDayCell(
                                title: viewModel.dayNumber(for: day.date),
                                isSelected: viewModel.isSelected(day.date),
                                isToday: viewModel.isToday(day.date),
                                isInDisplayedMonth: day.isInDisplayedMonth,
                                hasMarker: viewModel.hasMarker(on: day.date)
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(viewModel.accessibilityDateLabel(for: day.date))
                        .accessibilityValue(viewModel.accessibilityValue(for: day.date))
                        .accessibilityAddTraits(viewModel.isSelected(day.date) ? .isSelected : [])
                    }
                }
            }
        }
    }

    private var weekView: some View {
        SharedCard {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                SharedSectionHeader("周视图", subtitle: "按周浏览记录密度")

                HStack(spacing: AppSpacing.sm) {
                    ForEach(viewModel.weekDates, id: \.self) { date in
                        Button {
                            viewModel.selectDate(date)
                        } label: {
                            WeekDayPill(
                                title: viewModel.shortDayLabel(for: date),
                                hasMarker: viewModel.hasMarker(on: date),
                                isSelected: viewModel.isSelected(date),
                                isToday: viewModel.isToday(date)
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(viewModel.accessibilityDateLabel(for: date))
                        .accessibilityValue(viewModel.accessibilityValue(for: date))
                        .accessibilityAddTraits(viewModel.isSelected(date) ? .isSelected : [])
                    }
                }

                if viewModel.summary.markerDates.isEmpty {
                    SharedEmptyStateView(
                        title: "本周还没有记录",
                        message: "后续创建记录后，这里会展示每日密度摘要。",
                        symbolName: "calendar.badge.clock"
                    )
                } else {
                    VStack(alignment: .leading, spacing: AppSpacing.xs) {
                        ForEach(viewModel.weekDates, id: \.self) { date in
                            SharedListRow(
                                title: viewModel.fullDateLabel(for: date),
                                subtitle: viewModel.hasMarker(on: date) ? "可进入日视图或详情查看当天摘要。" : "当天暂无记录。",
                                symbolName: viewModel.hasMarker(on: date) ? "record.circle" : "circle.dotted",
                                colorToken: viewModel.hasMarker(on: date) ? .green : .slate,
                                badgeText: viewModel.summaryBadgeText(for: date)
                            )
                        }
                    }
                }
            }
        }
    }

    private var dayView: some View {
        SharedCard {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                SharedSectionHeader("日视图", subtitle: viewModel.fullDateLabel(for: viewModel.selectedDate))

                if viewModel.selectedDayRecords.isEmpty {
                    SharedEmptyStateView(
                        title: "当天还没有记录",
                        message: "Task 410 会在这里补齐更完整的记录内容与操作。",
                        symbolName: "calendar.day.timeline.left"
                    )
                } else {
                    VStack(alignment: .leading, spacing: AppSpacing.xs) {
                        ForEach(viewModel.selectedDayRecords, id: \.id) { record in
                            SharedListRow(
                                title: record.type.visualStyle.title,
                                subtitle: record.note ?? "开始于 \(record.startAt.formatted(date: .omitted, time: .shortened))",
                                symbolName: record.type.visualStyle.symbolName,
                                colorToken: record.type.visualStyle.colorToken,
                                badgeText: "记录"
                            )
                        }
                    }
                }
            }
        }
    }
}

private struct CalendarMonthDayCell: View {
    let title: String
    let isSelected: Bool
    let isToday: Bool
    let isInDisplayedMonth: Bool
    let hasMarker: Bool

    var body: some View {
        VStack(spacing: AppSpacing.xs) {
            Text(title)
                .font(AppTypography.body.weight(isSelected ? .semibold : .regular))
                .foregroundStyle(foregroundColor)

            Circle()
                .fill(hasMarker ? markerColor : .clear)
                .frame(width: 6, height: 6)
        }
        .frame(maxWidth: .infinity, minHeight: 52)
        .padding(.vertical, AppSpacing.sm)
        .background(backgroundShape.fill(backgroundColor))
        .overlay(backgroundShape.stroke(borderColor, lineWidth: isToday ? 1.5 : 0))
    }

    private var backgroundShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: AppCornerRadius.md, style: .continuous)
    }

    private var backgroundColor: Color {
        if isSelected {
            return AppColorToken.blue.color.opacity(0.16)
        }
        return AppColorToken.surface.color
    }

    private var borderColor: Color {
        isToday ? AppColorToken.blue.color : .clear
    }

    private var foregroundColor: Color {
        if isSelected || isInDisplayedMonth {
            return AppColorToken.textPrimary.color
        }
        return AppColorToken.textSecondary.color.opacity(0.65)
    }

    private var markerColor: Color {
        isSelected ? AppColorToken.blue.color : AppColorToken.green.color
    }
}

private struct WeekDayPill: View {
    let title: String
    let hasMarker: Bool
    let isSelected: Bool
    let isToday: Bool

    var body: some View {
        VStack(spacing: AppSpacing.xs) {
            Text(title)
                .font(AppTypography.caption.weight(.semibold))
                .foregroundStyle(isSelected ? AppColorToken.blue.color : AppColorToken.textPrimary.color)
            Circle()
                .fill(hasMarker ? AppColorToken.green.color : .clear)
                .frame(width: 6, height: 6)
        }
        .frame(maxWidth: .infinity, minHeight: 56)
        .padding(.vertical, AppSpacing.sm)
        .background(
            RoundedRectangle(cornerRadius: AppCornerRadius.md, style: .continuous)
                .fill(isSelected ? AppColorToken.blue.color.opacity(0.12) : AppColorToken.surface.color)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppCornerRadius.md, style: .continuous)
                .stroke(isToday ? AppColorToken.blue.color.opacity(0.8) : AppColorToken.surfaceBorder.color.opacity(0.18), lineWidth: isToday ? 1.5 : 1)
        )
    }
}

private struct CalendarDayDetailView: View {
    let date: Date
    let records: [Record]
    let subtitle: String

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.xl) {
                SharedCard {
                    VStack(alignment: .leading, spacing: AppSpacing.sm) {
                        SharedSectionHeader("某天详情", subtitle: subtitle)
                        Text("Task 410 将在这里补齐当天记录的完整内容与操作。")
                            .font(AppTypography.body)
                            .foregroundStyle(AppColorToken.textSecondary.color)
                    }
                }

                SharedCard {
                    VStack(alignment: .leading, spacing: AppSpacing.md) {
                        SharedSectionHeader("当天摘要", subtitle: records.isEmpty ? "暂无记录" : "已加载当天记录占位摘要")

                        if records.isEmpty {
                            SharedEmptyStateView(
                                title: "暂无当天记录",
                                message: "后续任务会在此提供新增、编辑和更完整的时间线。",
                                symbolName: "tray"
                            )
                        } else {
                            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                                ForEach(records, id: \.id) { record in
                                    SharedListRow(
                                        title: record.type.visualStyle.title,
                                        subtitle: record.note ?? record.startAt.formatted(date: .omitted, time: .shortened),
                                        symbolName: record.type.visualStyle.symbolName,
                                        colorToken: record.type.visualStyle.colorToken,
                                        badgeText: "记录"
                                    )
                                }
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, AppSpacing.screenHorizontal)
            .padding(.vertical, AppSpacing.lg)
        }
        .background(AppColorToken.background.color.ignoresSafeArea())
        .navigationTitle(date.formatted(.dateTime.month().day()))
    }
}

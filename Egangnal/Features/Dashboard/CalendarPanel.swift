//
//  CalendarPanel.swift
//  Egangnal
//

import SwiftUI

struct CalendarPanel: View {
    @Environment(\.appPalette) private var palette

    let studyTimeController: StudyTimeController
    let isCompact: Bool

    /// nil 表示跟随当前月份；用户浏览后保存完整年月，保证可以跨年切换。
    @State private var selectedMonth: CalendarMonth? = nil

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            currentMonthCalendar(for: context.date)
        }
        .environment(\.locale, Locale(identifier: "zh_Hans_CN"))
        .padding(.leading, metrics.leadingInset)
        .overlay {
            Rectangle()
                .fill(.clear)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("日历面板")
                .accessibilityIdentifier("dashboard.calendarPanel")
                .allowsHitTesting(false)
        }
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(palette.border.opacity(0.55))
                .frame(width: 1)
        }
    }

    private func currentMonthCalendar(for date: Date) -> some View {
        let todayMonth = CalendarMonth(
            year: Self.calendar.component(.year, from: date),
            month: Self.calendar.component(.month, from: date)
        )
        let displayedMonth = selectedMonth ?? todayMonth
        let days = displayedMonth.dayGrid(using: Self.calendar)
        let statuses = feedbackStatuses(for: days, in: displayedMonth, today: date)
        let completedDayCount = statuses.filter { $0 == .completed }.count

        return VStack(alignment: .leading, spacing: 0) {
            Text("本月学习")
                .font(.system(.title3, design: .serif).weight(.medium))
                .foregroundStyle(palette.secondaryText)
                .accessibilityAddTraits(.isHeader)

            HStack(alignment: .firstTextBaseline) {
                monthButton(
                    systemImage: "chevron.left",
                    help: "上一个月",
                    identifier: "dashboard.calendar.previousMonth"
                ) {
                    moveMonth(by: -1, from: displayedMonth)
                }

                Text(verbatim: "\(displayedMonth.year) 年 \(displayedMonth.month) 月")
                    .font(.system(size: metrics.monthTitleSize, weight: .semibold))
                    .accessibilityIdentifier("dashboard.calendar.monthTitle")

                monthButton(
                    systemImage: "chevron.right",
                    help: "下一个月",
                    identifier: "dashboard.calendar.nextMonth"
                ) {
                    moveMonth(by: 1, from: displayedMonth)
                }

                Spacer(minLength: 8)
                Text("\(completedDayCount) 天达标")
                    .font(.system(size: metrics.detailTextSize))
                    .foregroundStyle(palette.tertiaryText)
            }
            .padding(.top, metrics.monthTitleTopPadding)

            weekdayHeader
                .padding(.top, metrics.weekdayTopPadding)

            monthGrid(
                displayedMonth,
                days: days,
                statuses: statuses,
                today: date
            )
            .padding(.top, metrics.gridTopPadding)

            todaySummary(for: date)
                .padding(.top, metrics.summaryTopPadding)
        }
    }

    private var weekdayHeader: some View {
        LazyVGrid(columns: gridColumns, spacing: 2) {
            ForEach(["一", "二", "三", "四", "五", "六", "日"], id: \.self) { weekday in
                Text(weekday)
                    .font(.system(size: metrics.weekdayTextSize, weight: .medium))
                    .foregroundStyle(palette.secondaryText)
                    .frame(maxWidth: .infinity)
            }
        }
        .accessibilityHidden(true)
    }

    private func feedbackStatuses(
        for days: [Int?],
        in month: CalendarMonth,
        today: Date
    ) -> [DailyStudyFeedbackStatus] {
        days.map { day -> DailyStudyFeedbackStatus in
            guard let day else { return .none }
            let dayDate = Self.calendar.date(
                from: DateComponents(year: month.year, month: month.month, day: day)
            ) ?? today
            return studyTimeController.dailyFeedbackStatus(for: dayDate)
        }
    }

    private func monthGrid(
        _ month: CalendarMonth,
        days: [Int?],
        statuses: [DailyStudyFeedbackStatus],
        today: Date
    ) -> some View {
        let todayYear = Self.calendar.component(.year, from: today)
        let todayMonth = Self.calendar.component(.month, from: today)
        let todayDay = Self.calendar.component(.day, from: today)

        return VStack(spacing: metrics.rowSpacing) {
            ForEach(0..<6, id: \.self) { row in
                HStack(spacing: 0) {
                    ForEach(0..<7, id: \.self) { column in
                        let index = row * 7 + column
                        if let day = days[index] {
                            let status = statuses[index]
                            let todayMarker = isToday(
                                day,
                                in: month,
                                year: todayYear,
                                month: todayMonth,
                                day: todayDay
                            )
                            Text("\(day)")
                                .font(
                                    .system(size: metrics.dayTextSize)
                                        .monospacedDigit()
                                )
                                .foregroundStyle(textColor(for: status))
                                .frame(maxWidth: .infinity)
                                .frame(height: dayCellHeight)
                                .background {
                                    if status != .none {
                                        // 同一周内同色相邻日期连成一条，是"自律正反馈"的主视觉；
                                        // 无邻居时收拢为与"今天"描边等大的圆。
                                        CalendarActivityBand(
                                            roundsLeading: !CalendarActivityLayout.connectsLeading(
                                                at: index,
                                                statuses: statuses
                                            ),
                                            roundsTrailing: !CalendarActivityLayout.connectsTrailing(
                                                at: index,
                                                statuses: statuses
                                            )
                                        )
                                        .fill(activityColor(for: status))
                                        .frame(height: metrics.markerDiameter)
                                    }
                                }
                                .overlay {
                                    if todayMarker {
                                        Circle()
                                            .stroke(palette.calendarAccent, lineWidth: 1.5)
                                            .frame(
                                                width: metrics.markerDiameter,
                                                height: metrics.markerDiameter
                                            )
                                    }
                                }
                        } else {
                            Color.clear
                                .frame(maxWidth: .infinity)
                                .frame(height: dayCellHeight)
                        }
                    }
                }
            }
        }
        .accessibilityHidden(true)
    }

    private func todaySummary(for date: Date) -> some View {
        let seconds = studyTimeController.dailyStudiedSeconds(for: date)
        let minutes = Int(seconds / 60)
        let status = studyTimeController.dailyFeedbackStatus(for: date)

        return HStack(alignment: .top) {
            summaryValue(label: "今日", value: "\(minutes) 分钟")
                .accessibilityIdentifier("dashboard.today.minutes")
            Spacer(minLength: 12)
            summaryValue(
                label: "每日目标",
                value: statusTitle(status),
                valueColor: status == .completed ? palette.success : palette.primaryText
            )
            .accessibilityIdentifier("dashboard.today.status")
        }
        .padding(.top, metrics.summaryContentTopPadding)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(palette.border.opacity(0.38))
                .frame(height: 1)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("dashboard.today.summary")
    }

    private func summaryValue(
        label: String,
        value: String,
        valueColor: Color? = nil
    ) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.system(size: metrics.summaryLabelSize))
                .foregroundStyle(palette.tertiaryText)
            Text(value)
                .font(.system(size: metrics.summaryValueSize, weight: .semibold))
                .foregroundStyle(valueColor ?? palette.primaryText)
        }
    }

    private func statusTitle(_ status: DailyStudyFeedbackStatus) -> String {
        switch status {
        case .none:
            "尚未开始"
        case .visited:
            "未达标"
        case .completed:
            "已达标"
        }
    }

    private func activityColor(for status: DailyStudyFeedbackStatus) -> Color {
        switch status {
        case .none:
            .clear
        case .visited:
            palette.calendarVisited
        case .completed:
            palette.calendarCompleted
        }
    }

    private func textColor(for status: DailyStudyFeedbackStatus) -> Color {
        switch status {
        case .none, .visited:
            palette.primaryText
        case .completed:
            Color.black.opacity(0.82)
        }
    }

    private func monthButton(
        systemImage: String,
        help: String,
        identifier: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(help, systemImage: systemImage, action: action)
            .labelStyle(.iconOnly)
            .buttonStyle(.borderless)
            .frame(width: metrics.monthButtonSize, height: metrics.monthButtonSize)
            .contentShape(.rect)
            .help(help)
            .accessibilityIdentifier(identifier)
    }

    private func moveMonth(by offset: Int, from month: CalendarMonth) {
        guard let targetMonth = month.moving(by: offset) else { return }
        selectedMonth = targetMonth
    }

    private func isToday(
        _ candidateDay: Int,
        in candidateMonth: CalendarMonth,
        year: Int,
        month: Int,
        day: Int
    ) -> Bool {
        candidateMonth.year == year
            && candidateMonth.month == month
            && candidateDay == day
    }

    private var gridColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 2), count: 7)
    }

    /// 空白日期也必须使用确定高度，否则 `Color.clear` 会在高窗口中拉伸整个月历。
    private var dayCellHeight: CGFloat {
        metrics.dayCellHeight
    }

    private var metrics: CalendarPanelMetrics {
        CalendarPanelMetrics(isCompact: isCompact)
    }

    private static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "zh_Hans_CN")
        calendar.timeZone = .autoupdatingCurrent
        calendar.firstWeekday = 2
        return calendar
    }
}

/// 日历内部使用两套稳定规格；日期行始终固定高度，不能吸收窗口剩余空间。
private struct CalendarPanelMetrics {
    let isCompact: Bool

    var leadingInset: CGFloat { isCompact ? 18 : 22 }
    var monthTitleSize: CGFloat { isCompact ? 13 : 16 }
    var detailTextSize: CGFloat { isCompact ? 10 : 12 }
    var weekdayTextSize: CGFloat { isCompact ? 10 : 11 }
    var dayTextSize: CGFloat { isCompact ? 11 : 12 }
    var summaryLabelSize: CGFloat { isCompact ? 10 : 11 }
    var summaryValueSize: CGFloat { isCompact ? 12 : 14 }
    var dayCellHeight: CGFloat { isCompact ? 23 : 29 }
    /// 反馈底色的高度、独立圆的直径与"今天"描边的直径共用一个值，条带首尾才能与圆严丝合缝。
    var markerDiameter: CGFloat { isCompact ? 19 : 23 }
    var monthButtonSize: CGFloat { isCompact ? 20 : 24 }
    var rowSpacing: CGFloat { isCompact ? 3 : 5 }
    var monthTitleTopPadding: CGFloat { isCompact ? 20 : 30 }
    var weekdayTopPadding: CGFloat { isCompact ? 12 : 17 }
    var gridTopPadding: CGFloat { isCompact ? 6 : 8 }
    var summaryTopPadding: CGFloat { isCompact ? 12 : 18 }
    var summaryContentTopPadding: CGFloat { isCompact ? 10 : 14 }
}

#Preview("日期") {
    CalendarPanel(
        studyTimeController: .preview,
        isCompact: false
    )
        .frame(width: 274)
        .padding()
}

/// 一天的反馈底色。连接侧延伸到格子边缘与邻居相接，未连接侧收成半圆；
/// 两侧都不连接时就是一个直径等于高度的圆。
private struct CalendarActivityBand: Shape {
    let roundsLeading: Bool
    let roundsTrailing: Bool

    func path(in rect: CGRect) -> Path {
        let radius = min(rect.height, rect.width) / 2
        let left = roundsLeading ? rect.midX - radius : rect.minX
        let right = roundsTrailing ? rect.midX + radius : rect.maxX
        let top = rect.minY
        let bottom = rect.maxY

        var path = Path()
        path.move(to: CGPoint(x: left + (roundsLeading ? radius : 0), y: top))
        path.addLine(to: CGPoint(x: right - (roundsTrailing ? radius : 0), y: top))

        if roundsTrailing {
            path.addArc(
                center: CGPoint(x: right - radius, y: top + radius),
                radius: radius,
                startAngle: .degrees(-90),
                endAngle: .degrees(0),
                clockwise: false
            )
        }
        path.addLine(to: CGPoint(x: right, y: bottom - (roundsTrailing ? radius : 0)))

        if roundsTrailing {
            path.addArc(
                center: CGPoint(x: right - radius, y: bottom - radius),
                radius: radius,
                startAngle: .degrees(0),
                endAngle: .degrees(90),
                clockwise: false
            )
        }
        path.addLine(to: CGPoint(x: left + (roundsLeading ? radius : 0), y: bottom))

        if roundsLeading {
            path.addArc(
                center: CGPoint(x: left + radius, y: bottom - radius),
                radius: radius,
                startAngle: .degrees(90),
                endAngle: .degrees(180),
                clockwise: false
            )
            path.addLine(to: CGPoint(x: left, y: top + radius))
            path.addArc(
                center: CGPoint(x: left + radius, y: top + radius),
                radius: radius,
                startAngle: .degrees(180),
                endAngle: .degrees(270),
                clockwise: false
            )
        } else {
            path.addLine(to: CGPoint(x: left, y: top))
        }

        path.closeSubpath()
        return path
    }
}

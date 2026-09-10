//
//  CalendarPanel.swift
//  Egangnal
//

import SwiftUI

struct CalendarPanel: View {
    @Environment(\.appPalette) private var palette

    let studyTimeController: StudyTimeController

    @State private var isExpanded = false
    @State private var selectedMonth = Self.calendar.component(.month, from: .now)

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            Group {
                if isExpanded {
                    expandedCalendar(for: context.date)
                        .transition(.opacity)
                } else {
                    currentDateButton(for: context.date)
                        .transition(.opacity)
                }
            }
            .frame(
                maxWidth: .infinity,
                minHeight: isExpanded ? 202 : 92,
                maxHeight: isExpanded ? 202 : 92,
                alignment: .topLeading
            )
            .padding(14)
            .workspacePanel()
            .animation(.easeInOut(duration: 0.18), value: isExpanded)
        }
        .environment(\.locale, Locale(identifier: "zh_Hans_CN"))
        .overlay {
            Rectangle()
                .fill(.clear)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("日历面板")
                .accessibilityIdentifier("dashboard.calendarPanel")
                .allowsHitTesting(false)
        }
    }

    private func currentDateButton(for date: Date) -> some View {
        Button {
            selectedMonth = Self.calendar.component(.month, from: date)
            isExpanded = true
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .top) {
                    Text(date, format: .dateTime.month(.wide).day())
                        .font(.title2.weight(.semibold))
                    Spacer()
                    Image(systemName: "calendar")
                        .font(.headline)
                        .foregroundStyle(palette.calendarAccent)
                }

                Text(date, format: .dateTime.year().weekday(.wide))
                    .font(.subheadline)
                    .foregroundStyle(palette.secondaryText)

                Spacer(minLength: 0)
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .help("展开月份挂历")
        .accessibilityLabel("当前日期")
        .accessibilityValue(
            date.formatted(
                .dateTime
                    .locale(Locale(identifier: "zh_Hans_CN"))
                    .year()
                    .month()
                    .day()
                    .weekday(.wide)
            )
        )
        .accessibilityIdentifier("dashboard.date.toggle")
    }

    private func expandedCalendar(for date: Date) -> some View {
        let year = Self.calendar.component(.year, from: date)
        let currentMonth = CalendarMonth(year: year, month: selectedMonth)
        let numberOfDays = currentMonth.numberOfDays(using: Self.calendar)

        return VStack(spacing: 8) {
            HStack(spacing: 8) {
                monthButton(
                    systemImage: "chevron.left",
                    help: "上一个月",
                    identifier: "dashboard.calendar.previousMonth"
                ) {
                    moveMonth(by: -1, from: currentMonth)
                }
                .disabled(currentMonth.moving(by: -1) == nil)

                Spacer(minLength: 0)

                Button {
                    isExpanded = false
                } label: {
                    VStack(spacing: 1) {
                        Text(verbatim: "\(year)年 \(selectedMonth)月")
                            .font(.headline)
                            .accessibilityIdentifier("dashboard.calendar.monthTitle")
                        Text("共 \(numberOfDays) 天")
                            .font(.caption)
                            .foregroundStyle(palette.secondaryText)
                    }
                }
                .buttonStyle(.plain)
                .help("收起挂历")
                .accessibilityIdentifier("dashboard.calendar.header")

                Spacer(minLength: 0)

                monthButton(
                    systemImage: "chevron.right",
                    help: "下一个月",
                    identifier: "dashboard.calendar.nextMonth"
                ) {
                    moveMonth(by: 1, from: currentMonth)
                }
                .disabled(currentMonth.moving(by: 1) == nil)
            }

            weekdayHeader

            Button {
                isExpanded = false
            } label: {
                monthGrid(currentMonth, today: date)
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .help("收起挂历")
            .accessibilityLabel("\(year)年\(selectedMonth)月挂历，共\(numberOfDays)天")
            .accessibilityIdentifier("dashboard.calendar.collapse")
        }
    }

    private var weekdayHeader: some View {
        LazyVGrid(columns: gridColumns, spacing: 2) {
            ForEach(["一", "二", "三", "四", "五", "六", "日"], id: \.self) { weekday in
                Text(weekday)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(palette.secondaryText)
                    .frame(maxWidth: .infinity)
            }
        }
        .accessibilityHidden(true)
    }

    private func monthGrid(_ month: CalendarMonth, today: Date) -> some View {
        let todayYear = Self.calendar.component(.year, from: today)
        let todayMonth = Self.calendar.component(.month, from: today)
        let todayDay = Self.calendar.component(.day, from: today)
        let days = month.dayGrid(using: Self.calendar)
        let statuses = days.map { day -> DailyStudyFeedbackStatus in
            guard let day else { return .none }
            let dayDate = Self.calendar.date(
                from: DateComponents(year: month.year, month: month.month, day: day)
            ) ?? today
            return studyTimeController.dailyFeedbackStatus(for: dayDate)
        }

        return VStack(spacing: 2) {
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
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(textColor(for: status))
                                .frame(maxWidth: .infinity, minHeight: 20)
                                .background {
                                    if status != .none {
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
                                        .padding(.vertical, 1)
                                    }
                                }
                                .overlay {
                                    if todayMarker {
                                        Circle()
                                            .stroke(palette.calendarAccent, lineWidth: 1.5)
                                            .padding(1)
                                    }
                                }
                        } else {
                            Color.clear
                                .frame(maxWidth: .infinity, minHeight: 20)
                        }
                    }
                }
            }
        }
        .accessibilityHidden(true)
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
            .frame(width: 28, height: 28)
            .contentShape(.rect)
            .help(help)
            .accessibilityIdentifier(identifier)
    }

    private func moveMonth(by offset: Int, from month: CalendarMonth) {
        guard let targetMonth = month.moving(by: offset) else { return }
        selectedMonth = targetMonth.month
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

    private static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "zh_Hans_CN")
        calendar.timeZone = .autoupdatingCurrent
        calendar.firstWeekday = 2
        return calendar
    }
}

#Preview("日期") {
    CalendarPanel(studyTimeController: .preview)
        .frame(width: 274)
        .padding()
}

private struct CalendarActivityBand: Shape {
    let roundsLeading: Bool
    let roundsTrailing: Bool

    func path(in rect: CGRect) -> Path {
        // 未连接时底色收拢为与“今天”描边等大的圆；只有连接侧才延伸到网格边缘。
        let radius = min(rect.height / 2, rect.width / 2, 9)
        var path = Path()
        let left = roundsLeading ? rect.midX - radius : rect.minX
        let right = roundsTrailing ? rect.midX + radius : rect.maxX
        let top = rect.minY
        let bottom = rect.maxY

        path.move(
            to: CGPoint(
                x: left + (roundsLeading ? radius : 0),
                y: top
            )
        )
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
        path.addLine(
            to: CGPoint(
                x: right,
                y: bottom - (roundsTrailing ? radius : 0)
            )
        )

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

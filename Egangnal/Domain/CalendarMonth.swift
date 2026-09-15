//
//  CalendarMonth.swift
//  Egangnal
//

import Foundation

struct CalendarMonth: Equatable {
    let year: Int
    let month: Int

    init(year: Int, month: Int) {
        precondition((1...12).contains(month), "月份必须在 1 到 12 之间")
        self.year = year
        self.month = month
    }

    func numberOfDays(using calendar: Calendar) -> Int {
        guard let firstDay = firstDay(using: calendar),
              let dayRange = calendar.range(of: .day, in: .month, for: firstDay) else {
            return 0
        }
        return dayRange.count
    }

    func dayGrid(using calendar: Calendar) -> [Int?] {
        guard let firstDay = firstDay(using: calendar) else {
            return Array(repeating: nil, count: 42)
        }

        let weekday = calendar.component(.weekday, from: firstDay)
        let leadingEmptyDays = (weekday - calendar.firstWeekday + 7) % 7
        let days = Array(1...numberOfDays(using: calendar)).map(Optional.some)
        var grid = Array<Int?>(repeating: nil, count: leadingEmptyDays) + days

        // 固定为六行，避免切换月份时挂历高度发生跳动。
        grid += Array(repeating: nil, count: max(0, 42 - grid.count))
        return Array(grid.prefix(42))
    }

    func moving(by offset: Int) -> CalendarMonth? {
        let (yearBase, yearOverflow) = year.multipliedReportingOverflow(by: 12)
        guard !yearOverflow else { return nil }
        let (currentIndex, monthOverflow) = yearBase.addingReportingOverflow(month - 1)
        guard !monthOverflow else { return nil }
        let (targetIndex, offsetOverflow) = currentIndex.addingReportingOverflow(offset)
        guard !offsetOverflow else { return nil }

        var targetYear = targetIndex / 12
        var targetMonthIndex = targetIndex % 12
        if targetMonthIndex < 0 {
            targetYear -= 1
            targetMonthIndex += 12
        }
        guard targetYear > 0 else { return nil }
        return CalendarMonth(year: targetYear, month: targetMonthIndex + 1)
    }

    private func firstDay(using calendar: Calendar) -> Date? {
        calendar.date(from: DateComponents(year: year, month: month, day: 1))
    }
}

//
//  DailyStudyFeedback.swift
//  Egangnal
//

import Foundation

/// 与用户本地日历绑定的日期键，不携带时分秒和时区。
struct StudyDateKey: Hashable, Comparable, Sendable, CustomStringConvertible {
    let year: Int
    let month: Int
    let day: Int

    init(year: Int, month: Int, day: Int) {
        precondition(year > 0, "年份必须为正数")
        precondition((1...12).contains(month), "月份必须在 1 到 12 之间")
        precondition((1...31).contains(day), "日期必须在 1 到 31 之间")
        precondition(Self.isValidDate(year: year, month: month, day: day), "日期不存在")
        self.year = year
        self.month = month
        self.day = day
    }

    init(date: Date, calendar: Calendar) {
        self.init(
            year: calendar.component(.year, from: date),
            month: calendar.component(.month, from: date),
            day: calendar.component(.day, from: date)
        )
    }

    init?(rawValue: String) {
        let components = rawValue.split(separator: "-")
        guard components.count == 3,
              let year = Int(components[0]),
              let month = Int(components[1]),
              let day = Int(components[2]),
              year > 0,
              (1...12).contains(month),
              (1...31).contains(day),
              Self.isValidDate(year: year, month: month, day: day) else {
            return nil
        }
        self.year = year
        self.month = month
        self.day = day
    }

    var rawValue: String {
        "\(year.fourDigits)-\(month.twoDigits)-\(day.twoDigits)"
    }

    var description: String { rawValue }

    static func < (lhs: StudyDateKey, rhs: StudyDateKey) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    func startDate(using calendar: Calendar) -> Date? {
        calendar.date(from: DateComponents(year: year, month: month, day: day))
    }

    private static func isValidDate(year: Int, month: Int, day: Int) -> Bool {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        let components = DateComponents(year: year, month: month, day: day)
        guard let date = calendar.date(from: components) else { return false }
        return calendar.component(.year, from: date) == year
            && calendar.component(.month, from: date) == month
            && calendar.component(.day, from: date) == day
    }

}

enum DailyStudyFeedbackStatus: Equatable, Sendable {
    case none
    case visited
    case completed

    static let completionThresholdSeconds: Double = 15 * 60

    static func make(
        from activities: some Sequence<DailyStudyActivitySnapshot>
    ) -> Self {
        var hasEntered = false
        var studiedSeconds = 0.0

        for activity in activities {
            hasEntered = hasEntered || activity.hasEntered
            guard activity.studiedSeconds.isFinite else { continue }
            studiedSeconds += max(0, activity.studiedSeconds)
        }

        guard hasEntered else { return .none }
        return studiedSeconds >= completionThresholdSeconds ? .completed : .visited
    }

    /// 合并首页当日投入时拒绝非有限值，并把异常负数收敛到零。
    static func totalStudiedSeconds(
        from activities: some Sequence<DailyStudyActivitySnapshot>
    ) -> Double {
        activities.reduce(0) { total, activity in
            guard activity.studiedSeconds.isFinite else { return total }
            return total + max(0, activity.studiedSeconds)
        }
    }
}

extension Int {
    fileprivate var twoDigits: String {
        String(format: "%02d", self)
    }

    fileprivate var fourDigits: String {
        String(format: "%04d", self)
    }
}

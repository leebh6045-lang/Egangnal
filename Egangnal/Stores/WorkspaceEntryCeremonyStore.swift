//
//  WorkspaceEntryCeremonyStore.swift
//  Egangnal
//

import Foundation
import Observation

/// 记录每种语言上一次从首页进入的时间，决定这一次要不要播启动页。
///
/// 记录只活在内存里：重新启动 App 后第一次进入总会播，这正是"开始今天的学习"想要的效果；
/// 不为它增加持久化键。时间用 `Date` 而不是单调时钟：冷却判定的是墙上时间意义上的"离开了多久"。
@MainActor
@Observable
final class WorkspaceEntryCeremonyStore {
    private var previousEntries: [LanguageSpace: WorkspaceEntryCeremonyPolicy.PreviousEntry] = [:]
    private let calendar: Calendar
    private let now: () -> Date

    init(calendar: Calendar = .autoupdatingCurrent, now: @escaping () -> Date = { .now }) {
        self.calendar = calendar
        self.now = now
    }

    /// 登记一次进入并返回是否播放。登记与判定必须是同一步：先判定再登记会让"每次进入"以外的策略读到本次记录。
    func registerEntry(
        to space: LanguageSpace,
        frequency: WorkspaceEntryCeremonyFrequency,
        reduceMotion: Bool
    ) -> Bool {
        let date = now()
        let todayKey = StudyDateKey(date: date, calendar: calendar)
        let plays = WorkspaceEntryCeremonyPolicy.shouldPlay(
            frequency: frequency,
            previousEntry: previousEntries[space],
            now: date.timeIntervalSinceReferenceDate,
            todayKey: todayKey,
            reduceMotion: reduceMotion
        )
        previousEntries[space] = .init(dateKey: todayKey, time: date.timeIntervalSinceReferenceDate)
        return plays
    }
}

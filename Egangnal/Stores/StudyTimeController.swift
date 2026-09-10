//
//  StudyTimeController.swift
//  Egangnal
//

import Foundation
import Observation

@MainActor
protocol StudyTimeClock {
    func now() -> TimeInterval
}

/// 以系统休眠会暂停的单调时钟作为计时来源。
@MainActor
final class SuspendingStudyTimeClock: StudyTimeClock {
    private let clock: SuspendingClock
    private let origin: SuspendingClock.Instant

    init() {
        clock = SuspendingClock()
        origin = clock.now
    }

    func now() -> TimeInterval {
        let duration = origin.duration(to: clock.now)
        let components = duration.components
        return Double(components.seconds)
            + Double(components.attoseconds) / 1_000_000_000_000_000_000
    }
}

@MainActor
protocol StudyTimeDateProvider {
    func now() -> Date
}

@MainActor
final class SystemStudyTimeDateProvider: StudyTimeDateProvider {
    func now() -> Date { .now }
}

@MainActor
@Observable
final class StudyTimeController {
    private let repository: any StudyTimeRepository
    private let clock: any StudyTimeClock
    private let dateProvider: any StudyTimeDateProvider
    private let calendar: Calendar
    private let persistenceAvailable: Bool

    private(set) var visibleSpace: LanguageSpace?
    private(set) var activeSpace: LanguageSpace?
    private(set) var totalSecondsBySpace: [LanguageSpace: Double]
    private(set) var dailyActivities: [DailyStudyActivitySnapshot]
    private(set) var hasUnsavedChanges = false
    private(set) var persistenceWarning: String?
    private(set) var displayRevision = 0

    private var startInstant: TimeInterval?
    private var pendingCommit: PendingCommit?
    private var startWallDate: Date?
    private var isApplicationActive = true
    private var isSystemSuspended = false
    private var checkpointTask: Task<Void, Never>?

    init(
        repository: any StudyTimeRepository,
        clock: any StudyTimeClock = SuspendingStudyTimeClock(),
        dateProvider: any StudyTimeDateProvider = SystemStudyTimeDateProvider(),
        calendar: Calendar = StudyTimeController.makeCalendar(),
        initialMessage: String? = nil
    ) {
        self.repository = repository
        self.clock = clock
        self.dateProvider = dateProvider
        self.calendar = calendar

        do {
            let snapshots = try repository.loadAll()
            let dailyActivities = try repository.loadDailyActivities()
            var totals = Dictionary(
                uniqueKeysWithValues: LanguageSpace.allCases.map { ($0, 0.0) }
            )
            for space in LanguageSpace.allCases {
                guard let snapshot = snapshots[space],
                      snapshot.totalSeconds.isFinite,
                      snapshot.totalSeconds >= 0 else {
                    throw StudyTimeStorageError.missingLanguageRecord(space.rawValue)
                }
                totals[space] = snapshot.totalSeconds
            }
            totalSecondsBySpace = totals
            self.dailyActivities = dailyActivities
            persistenceAvailable = true
            persistenceWarning = initialMessage
        } catch {
            totalSecondsBySpace = Dictionary(
                uniqueKeysWithValues: LanguageSpace.allCases.map { ($0, 0.0) }
            )
            dailyActivities = []
            persistenceAvailable = false
            persistenceWarning = initialMessage ?? "学习时长读取失败，本次不会累计未保存的时长。"
        }
    }

    @discardableResult
    func show(_ space: LanguageSpace) -> Bool {
        if visibleSpace == space {
            guard persistenceAvailable else { return true }
            _ = resumeVisibleSpaceIfPossible()
            return activeSpace == space || !isApplicationActive || isSystemSuspended
        }

        if !isApplicationActive || isSystemSuspended {
            visibleSpace = space
            return true
        }

        guard persistenceAvailable else {
            visibleSpace = space
            return true
        }

        if !retryPendingCommit() {
            return false
        }

        let now = clock.now()
        let wallDate = dateProvider.now()
        if let activeSpace {
            guard activeSpace != space else {
                visibleSpace = space
                return true
            }
            guard commitActiveSpace(at: now, wallDate: wallDate, pausing: false) else {
                return false
            }
        }

        guard markEntered(space, at: wallDate) else { return false }
        visibleSpace = space
        activeSpace = space
        startInstant = now
        startWallDate = wallDate
        return true
    }

    /// 返回总览时立即停止计时；保存失败也不能继续后台计时。
    @discardableResult
    func leaveSpace() -> Bool {
        let now = clock.now()
        let wallDate = dateProvider.now()
        var didPersist = true
        if activeSpace != nil {
            didPersist = commitActiveSpace(
                at: now,
                wallDate: wallDate,
                pausing: true
            )
        }
        activeSpace = nil
        startInstant = nil
        startWallDate = nil
        visibleSpace = nil
        return didPersist && pendingCommit == nil
    }

    func applicationDidBecomeActive() {
        isApplicationActive = true
        _ = resumeVisibleSpaceIfPossible()
    }

    func applicationWillResignActive() {
        guard isApplicationActive else { return }
        isApplicationActive = false
        pauseForLifecycleBoundary()
    }

    func systemWillSleep() {
        guard !isSystemSuspended else { return }
        isSystemSuspended = true
        pauseForLifecycleBoundary()
    }

    func systemDidWake() {
        isSystemSuspended = false
        guard isApplicationActive else { return }
        resumeVisibleSpaceIfPossible()
    }

    func applicationWillTerminate() {
        pauseForLifecycleBoundary()
        _ = retryPendingCommit()
        stopCheckpointing()
    }

    func checkpoint() {
        guard persistenceAvailable,
              isApplicationActive,
              !isSystemSuspended,
              activeSpace != nil else {
            return
        }
        _ = commitActiveSpace(
            at: clock.now(),
            wallDate: dateProvider.now(),
            pausing: false
        )
    }

    private func refreshDisplay() {
        displayRevision &+= 1

        guard let startInstant,
              activeSpace != nil,
              isApplicationActive,
              !isSystemSuspended else {
            return
        }

        if clock.now() - startInstant >= 30 {
            checkpoint()
        }
    }

    func startCheckpointing() {
        guard checkpointTask == nil else { return }

        checkpointTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                do {
                    try await Task.sleep(for: .seconds(1))
                } catch {
                    return
                }
                guard let self else { return }
                self.refreshDisplay()
            }
        }
    }

    func stopCheckpointing() {
        checkpointTask?.cancel()
        checkpointTask = nil
    }

    func totalSeconds(for space: LanguageSpace) -> Double {
        totalSecondsBySpace[space] ?? 0
    }

    func displayedHours(for space: LanguageSpace) -> Double {
        // 让 SwiftUI 观察到每秒刷新，同时不把未到检查点的增量写入数据库。
        _ = displayRevision
        var displaySeconds = totalSeconds(for: space)
        if activeSpace == space, let startInstant {
            displaySeconds += max(0, clock.now() - startInstant)
        }
        if let pendingCommit, pendingCommit.space == space {
            displaySeconds = max(displaySeconds, pendingCommit.totalSeconds)
        }

        let hours = displaySeconds / 3_600
        return (hours * 10).rounded(.toNearestOrAwayFromZero) / 10
    }

    func displayTier(for space: LanguageSpace) -> StudyTimeDisplayTier {
        StudyTimeDisplayTier(hours: displayedHours(for: space))
    }

    private func pauseForLifecycleBoundary() {
        guard activeSpace != nil else { return }
        _ = commitActiveSpace(
            at: clock.now(),
            wallDate: dateProvider.now(),
            pausing: true
        )
        activeSpace = nil
        startInstant = nil
        startWallDate = nil
    }

    @discardableResult
    private func resumeVisibleSpaceIfPossible() -> Bool {
        guard isApplicationActive,
              !isSystemSuspended,
              persistenceAvailable,
              activeSpace == nil,
              let visibleSpace else {
            return true
        }

        guard retryPendingCommit() else { return false }
        let wallDate = dateProvider.now()
        guard markEntered(visibleSpace, at: wallDate) else { return false }
        activeSpace = visibleSpace
        startInstant = clock.now()
        startWallDate = wallDate
        return true
    }

    private func commitActiveSpace(
        at now: TimeInterval,
        wallDate: Date,
        pausing: Bool
    ) -> Bool {
        guard let activeSpace,
              let startInstant,
              let startWallDate else {
            return true
        }

        let delta = max(0, now - startInstant)
        guard delta > 0 else {
            if pausing {
                self.activeSpace = nil
                self.startInstant = nil
            }
            return true
        }

        let currentTotal = totalSeconds(for: activeSpace)
        let targetTotal = currentTotal + delta
        let dailyIncrements = Self.makeDailyIncrements(
            from: startWallDate,
            to: wallDate,
            duration: delta,
            space: activeSpace,
            calendar: calendar
        )

        do {
            try repository.saveStudyTime(
                targetTotal,
                for: activeSpace,
                dailyIncrements: dailyIncrements,
                at: wallDate
            )
            totalSecondsBySpace[activeSpace] = targetTotal
            mergeDailyIncrements(dailyIncrements)
            self.startInstant = pausing ? nil : now
            self.startWallDate = pausing ? nil : wallDate
            if pausing {
                self.activeSpace = nil
            }
            if pendingCommit == nil {
                hasUnsavedChanges = false
                persistenceWarning = nil
            }
            return true
        } catch {
            hasUnsavedChanges = true
            persistenceWarning = "学习时长保存失败，未保存的时长将在下次重试。"
            if pausing {
                pendingCommit = PendingCommit(
                    space: activeSpace,
                    start: startInstant,
                    end: now,
                    totalSeconds: targetTotal,
                    dailyIncrements: dailyIncrements,
                    wallDate: wallDate
                )
                self.activeSpace = nil
                self.startInstant = nil
                self.startWallDate = nil
            }
            return false
        }
    }

    private func retryPendingCommit() -> Bool {
        guard let pendingCommit else { return true }

        do {
            try repository.saveStudyTime(
                pendingCommit.totalSeconds,
                for: pendingCommit.space,
                dailyIncrements: pendingCommit.dailyIncrements,
                at: pendingCommit.wallDate
            )
            totalSecondsBySpace[pendingCommit.space] = pendingCommit.totalSeconds
            mergeDailyIncrements(pendingCommit.dailyIncrements)
            self.pendingCommit = nil
            hasUnsavedChanges = false
            persistenceWarning = nil
            return true
        } catch {
            hasUnsavedChanges = true
            persistenceWarning = "学习时长保存失败，未保存的时长将在下次重试。"
            return false
        }
    }

    private func markEntered(_ space: LanguageSpace, at date: Date) -> Bool {
        let dateKey = StudyDateKey(date: date, calendar: calendar)
        if dailyActivities.contains(where: {
            $0.dateKey == dateKey && $0.space == space && $0.hasEntered
        }) {
            return true
        }

        do {
            try repository.markEntered(on: dateKey, for: space, at: date)
            mergeEnteredActivity(dateKey: dateKey, space: space)
            if pendingCommit == nil {
                hasUnsavedChanges = false
                persistenceWarning = nil
            }
            return true
        } catch {
            hasUnsavedChanges = true
            persistenceWarning = "每日学习反馈保存失败，未保存的反馈将在下次重试。"
            return false
        }
    }

    private func mergeEnteredActivity(
        dateKey: StudyDateKey,
        space: LanguageSpace
    ) {
        if let index = dailyActivities.firstIndex(where: {
            $0.dateKey == dateKey && $0.space == space
        }) {
            let current = dailyActivities[index]
            dailyActivities[index] = DailyStudyActivitySnapshot(
                dateKey: dateKey,
                space: space,
                studiedSeconds: current.studiedSeconds,
                hasEntered: true
            )
        } else {
            dailyActivities.append(
                DailyStudyActivitySnapshot(
                    dateKey: dateKey,
                    space: space,
                    studiedSeconds: 0,
                    hasEntered: true
                )
            )
        }
    }

    private func mergeDailyIncrements(
        _ increments: [DailyStudyActivityIncrement]
    ) {
        for increment in increments where increment.seconds > 0 {
            if let index = dailyActivities.firstIndex(where: {
                $0.dateKey == increment.dateKey && $0.space == increment.space
            }) {
                let current = dailyActivities[index]
                dailyActivities[index] = DailyStudyActivitySnapshot(
                    dateKey: increment.dateKey,
                    space: increment.space,
                    studiedSeconds: current.studiedSeconds + increment.seconds,
                    hasEntered: true
                )
            } else {
                dailyActivities.append(
                    DailyStudyActivitySnapshot(
                        dateKey: increment.dateKey,
                        space: increment.space,
                        studiedSeconds: increment.seconds,
                        hasEntered: true
                    )
                )
            }
        }
    }

    func dailyFeedbackStatus(for date: Date) -> DailyStudyFeedbackStatus {
        let dateKey = StudyDateKey(date: date, calendar: calendar)
        return dailyFeedbackStatus(for: dateKey)
    }

    func dailyFeedbackStatus(for dateKey: StudyDateKey) -> DailyStudyFeedbackStatus {
        DailyStudyFeedbackStatus.make(
            from: dailyActivities.filter { $0.dateKey == dateKey }
        )
    }

    private static func makeDailyIncrements(
        from startDate: Date,
        to endDate: Date,
        duration: TimeInterval,
        space: LanguageSpace,
        calendar: Calendar
    ) -> [DailyStudyActivityIncrement] {
        guard duration > 0 else { return [] }

        let startKey = StudyDateKey(date: startDate, calendar: calendar)
        let endKey = StudyDateKey(date: endDate, calendar: calendar)
        guard startKey != endKey,
              endDate > startDate,
              let wallDuration = Optional(endDate.timeIntervalSince(startDate)),
              wallDuration > 0 else {
            return [
                DailyStudyActivityIncrement(
                    dateKey: endKey,
                    space: space,
                    seconds: duration
                )
            ]
        }

        var increments: [DailyStudyActivityIncrement] = []
        var cursor = startDate
        while cursor < endDate {
            let cursorKey = StudyDateKey(date: cursor, calendar: calendar)
            let dayStart = calendar.startOfDay(for: cursor)
            guard let nextDay = calendar.date(
                byAdding: .day,
                value: 1,
                to: dayStart
            ) else {
                break
            }
            let segmentEnd = min(endDate, nextDay)
            let wallSegment = segmentEnd.timeIntervalSince(cursor)
            if wallSegment > 0 {
                increments.append(
                    DailyStudyActivityIncrement(
                        dateKey: cursorKey,
                        space: space,
                        seconds: duration * wallSegment / wallDuration
                    )
                )
            }
            cursor = segmentEnd
        }

        guard !increments.isEmpty else {
            return [
                DailyStudyActivityIncrement(
                    dateKey: endKey,
                    space: space,
                    seconds: duration
                )
            ]
        }

        // 将浮点数舍入误差归入最后一天，确保每日增量之和等于实际计时增量。
        let allocated = increments.dropLast().reduce(0) { $0 + $1.seconds }
        let last = increments[increments.index(before: increments.endIndex)]
        increments[increments.index(before: increments.endIndex)] =
            DailyStudyActivityIncrement(
                dateKey: last.dateKey,
                space: last.space,
                seconds: max(0, duration - allocated)
            )
        return increments
    }

    private static func makeCalendar() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "zh_Hans_CN")
        calendar.timeZone = .autoupdatingCurrent
        calendar.firstWeekday = 2
        return calendar
    }
}

private struct PendingCommit {
    let space: LanguageSpace
    let start: TimeInterval
    let end: TimeInterval
    let totalSeconds: Double
    let dailyIncrements: [DailyStudyActivityIncrement]
    let wallDate: Date
}

enum StudyTimeDisplayTier: Equatable, Sendable {
    case `default`
    case blue
    case purple
    case orange

    init(hours: Double) {
        switch hours {
        case ...50:
            self = .default
        case ...100:
            self = .blue
        case ...300:
            self = .purple
        default:
            self = .orange
        }
    }
}

extension StudyTimeController {
    static var preview: StudyTimeController {
        StudyTimeController(
            repository: PreviewStudyTimeRepository(),
            clock: PreviewStudyTimeClock()
        )
    }
}

@MainActor
private final class PreviewStudyTimeClock: StudyTimeClock {
    func now() -> TimeInterval { 0 }
}

@MainActor
private final class PreviewStudyTimeRepository: StudyTimeRepository {
    func loadAll() throws -> [LanguageSpace: StudyTimeSnapshot] {
        Dictionary(uniqueKeysWithValues: LanguageSpace.allCases.map { ($0, StudyTimeSnapshot(totalSeconds: 0)) })
    }

    func saveTotalSeconds(
        _ totalSeconds: Double,
        for space: LanguageSpace,
        at date: Date
    ) throws {}

    func loadDailyActivities() throws -> [DailyStudyActivitySnapshot] { [] }

    func markEntered(
        on dateKey: StudyDateKey,
        for space: LanguageSpace,
        at date: Date
    ) throws {}

    func saveStudyTime(
        _ totalSeconds: Double,
        for space: LanguageSpace,
        dailyIncrements: [DailyStudyActivityIncrement],
        at date: Date
    ) throws {}
}

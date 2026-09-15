//
//  WorkspaceEntryCeremonyTests.swift
//  EgangnalTests
//

import Foundation
import Testing
@testable import Egangnal

/// 启动页的播放判定与设置持久化。
struct WorkspaceEntryCeremonyTests {
    private let today = StudyDateKey(year: 2026, month: 9, day: 15)
    private let yesterday = StudyDateKey(year: 2026, month: 9, day: 14)

    private func entry(dateKey: StudyDateKey, time: TimeInterval) -> WorkspaceEntryCeremonyPolicy.PreviousEntry {
        .init(dateKey: dateKey, time: time)
    }

    @Test func firstEntryAlwaysPlaysUnlessMotionIsReduced() {
        for frequency in WorkspaceEntryCeremonyFrequency.allCases {
            #expect(WorkspaceEntryCeremonyPolicy.shouldPlay(
                frequency: frequency, previousEntry: nil, now: 0, todayKey: today, reduceMotion: false
            ))
            #expect(!WorkspaceEntryCeremonyPolicy.shouldPlay(
                frequency: frequency, previousEntry: nil, now: 0, todayKey: today, reduceMotion: true
            ), "减少动态效果时一律不播")
        }
    }

    @Test func alwaysFrequencyIgnoresPreviousEntry() {
        #expect(WorkspaceEntryCeremonyPolicy.shouldPlay(
            frequency: .always, previousEntry: entry(dateKey: today, time: 999), now: 1_000, todayKey: today, reduceMotion: false
        ))
    }

    @Test func cooldownFrequencyPlaysOnlyAfterThirtyMinutes() {
        let previous = entry(dateKey: today, time: 1_000)
        let cooldown = WorkspaceEntryCeremonyPolicy.cooldown
        #expect(cooldown == 30 * 60)
        #expect(!WorkspaceEntryCeremonyPolicy.shouldPlay(
            frequency: .cooldown, previousEntry: previous, now: 1_000 + cooldown - 1, todayKey: today, reduceMotion: false
        ))
        #expect(WorkspaceEntryCeremonyPolicy.shouldPlay(
            frequency: .cooldown, previousEntry: previous, now: 1_000 + cooldown, todayKey: today, reduceMotion: false
        ))
    }

    @Test func dailyFrequencyPlaysOncePerLocalDay() {
        #expect(!WorkspaceEntryCeremonyPolicy.shouldPlay(
            frequency: .daily, previousEntry: entry(dateKey: today, time: 0), now: 10_000, todayKey: today, reduceMotion: false
        ), "同一天再进不播，与间隔多久无关")
        #expect(WorkspaceEntryCeremonyPolicy.shouldPlay(
            frequency: .daily, previousEntry: entry(dateKey: yesterday, time: 0), now: 60, todayKey: today, reduceMotion: false
        ), "跨过本地午夜后再进要播")
    }

    @Test func durationAndUnlockMatchTheDecision() {
        #expect(WorkspaceEntryCeremonyPolicy.duration == 1.0)
        #expect(WorkspaceEntryCeremonyPolicy.inputUnlockFraction == 0.6)
    }

    /// 记录按语言分开，且"改频率"在下一次进入立即生效，不需要先重置记录。
    ///
    /// 关于冷却起点：设计文档第 3 节与预览稿都把「每隔 30 分钟」定义为
    /// **距上一次进入**（"离开超过 30 分钟"），而 `registerEntry` 每次进入都会刷新这条记录
    /// ——被跳过的那一次也会刷新。因此"跳过之后再进"要从**这一次**重新计时，
    /// 而不是从更早的那次播放计时。本用例按这个语义分组，冷却本身的边界由
    /// `cooldownFrequencyPlaysOnlyAfterThirtyMinutes` 在纯函数层覆盖。
    @Test @MainActor func storeTracksLanguagesIndependentlyAndAppliesFrequencyImmediately() {
        var now = Date(timeIntervalSinceReferenceDate: 0)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        let store = WorkspaceEntryCeremonyStore(calendar: calendar, now: { now })

        // 两种语言各自计数：英语当天进过第二次不播，日语仍是当天第一次。
        #expect(store.registerEntry(to: .english, frequency: .daily, reduceMotion: false))
        #expect(!store.registerEntry(to: .english, frequency: .daily, reduceMotion: false))
        #expect(store.registerEntry(to: .japanese, frequency: .daily, reduceMotion: false), "两种语言各自计数")

        // 改成"每次进入"立刻生效，不需要重置记录。
        #expect(store.registerEntry(to: .english, frequency: .always, reduceMotion: false))
    }

    /// 冷却起点是"上一次进入"，被跳过的那次同样刷新记录。
    @Test @MainActor func storeCooldownCountsFromTheMostRecentEntry() {
        var now = Date(timeIntervalSinceReferenceDate: 0)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        let store = WorkspaceEntryCeremonyStore(calendar: calendar, now: { now })

        // 本次运行第一次进入没有记录，必播。
        #expect(store.registerEntry(to: .english, frequency: .cooldown, reduceMotion: false))

        now = now.addingTimeInterval(29 * 60)
        #expect(!store.registerEntry(to: .english, frequency: .cooldown, reduceMotion: false), "29 分钟不播")

        // 上一步被跳过，但记录已刷新到那一刻（t=1800），因此这一步只过了 60 秒，仍不播。
        now = now.addingTimeInterval(60)
        #expect(!store.registerEntry(to: .english, frequency: .cooldown, reduceMotion: false), "距上一次进入仅 60 秒，不播")

        // 从最后一次进入（t=1860）再推满 30 分钟才播；若冷却错误地从更早的某次起算，这里会提前播。
        now = now.addingTimeInterval(30 * 60)
        #expect(store.registerEntry(to: .english, frequency: .cooldown, reduceMotion: false), "距上一次进入满 30 分钟，播")

        // 另一种语言没有被英语的记录影响。
        #expect(store.registerEntry(to: .japanese, frequency: .cooldown, reduceMotion: false), "日语首次进入必播")
    }

    @Test @MainActor func ceremonyPreferencesDefaultAndPersist() {
        let preferences = TestAppSettingsPreferences()
        let store = AppSettingsStore(preferences: preferences)
        #expect(store.workspaceEntry.ceremonyStyle == .lamp)
        #expect(store.workspaceEntry.ceremonyFrequency == .daily)

        store.setEntryCeremonyStyle(.title)
        store.setEntryCeremonyFrequency(.cooldown)

        let restored = AppSettingsStore(preferences: preferences)
        #expect(restored.workspaceEntry == WorkspaceEntryPersonalization(ceremonyStyle: .title, ceremonyFrequency: .cooldown))
        #expect(restored.personalization.workspaceEntry.ceremonyFrequency == .cooldown)
    }

    @Test @MainActor func featureTransitionDefaultsToSlideAndPersists() {
        let preferences = TestAppSettingsPreferences()
        let store = AppSettingsStore(preferences: preferences)
        #expect(store.featureTransition == .slide)

        store.setFeatureTransition(.float)
        #expect(AppSettingsStore(preferences: preferences).personalization.featureTransition == .float)

        preferences.set("cube", forKey: AppSettingsStore.StorageKey.featureTransition)
        #expect(AppSettingsStore(preferences: preferences).featureTransition == .slide, "未知值回到默认")
    }

    @Test @MainActor func unknownCeremonyPreferencesFallBackToDefaults() {
        let preferences = TestAppSettingsPreferences()
        preferences.set("confetti", forKey: AppSettingsStore.StorageKey.entryCeremonyStyle)
        preferences.set("hourly", forKey: AppSettingsStore.StorageKey.entryCeremonyFrequency)
        let store = AppSettingsStore(preferences: preferences)
        #expect(store.workspaceEntry.ceremonyStyle == .lamp)
        #expect(store.workspaceEntry.ceremonyFrequency == .daily)
    }
}

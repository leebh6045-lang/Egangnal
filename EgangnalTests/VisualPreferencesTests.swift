//
//  VisualPreferencesTests.swift
//  EgangnalTests
//

import Foundation
import SwiftUI
import Testing
@testable import Egangnal

/// 主题、词条排版偏好与横格本几何规则。
struct VisualPreferencesTests {
    // MARK: - 主题

    @Test func appearanceCycleVisitsEveryThemeExactlyOnce() {
        var visited: [AppAppearance] = []
        var current = AppAppearance.light
        for _ in AppAppearance.allCases {
            visited.append(current)
            current = current.next
        }

        #expect(Set(visited).count == AppAppearance.allCases.count, "循环必须经过每一套主题")
        #expect(current == .light, "走完一圈应回到起点")
        #expect(AppAppearance.dark.next == .light, "首页按钮从深色切一次应回到浅色")
    }

    @Test func warmThemeRendersSystemControlsAsLight() {
        #expect(AppAppearance.warm.colorScheme == .light)
        #expect(AppAppearance.light.colorScheme == .light)
        #expect(AppAppearance.dark.colorScheme == .dark)
    }

    /// 深色主题改为石墨风格后，红蓝环境光必须彻底消失；保留任何一侧都会与横格线争夺注意力。
    @Test func graphiteThemeHasNoAmbientLight() {
        let palette = AppAppearance.dark.palette
        #expect(palette.ambientLeading == .clear)
        #expect(palette.ambientTrailing == .clear)
    }

    @Test func storedDarkPreferenceStillResolvesAfterGraphiteRestyle() {
        #expect(AppAppearance(rawValue: "dark") == .dark, "旧偏好值 dark 不需要迁移")
        #expect(AppAppearance(rawValue: "light") == .light)
        #expect(AppAppearance(rawValue: "warm") == .warm)
    }

    // MARK: - 排版偏好

    @Test @MainActor func layoutPreferencesDefaultToStandardAndPersistPerPage() {
        let preferences = TestAppSettingsPreferences()
        let store = AppSettingsStore(preferences: preferences)

        #expect(store.wordBook.layout == .standard)
        #expect(store.lexicon.layout == .standard)
        #expect(store.wordBook.ruledLineStyle == .alignedSolid)
        #expect(store.lexicon.ruledLineStyle == .alignedSolid)

        store.setWordBookLayout(.ruled)
        store.setWordBookRuledLineStyle(.dashed)

        let restored = AppSettingsStore(preferences: preferences)
        #expect(restored.wordBook.layout == .ruled)
        #expect(restored.lexicon.layout == .standard, "两页的排版互不影响")
        #expect(restored.wordBook.ruledLineStyle == .dashed)
        #expect(restored.lexicon.ruledLineStyle == .alignedSolid, "横格线样式同样按页保存")
        #expect(restored.personalization == AppPersonalization(
            wordBook: WordBookPersonalization(layout: .ruled, ruledLineStyle: .dashed)
        ))
    }

    @Test @MainActor func lexiconLayoutAndRuledLineStylePersistIndependently() {
        let preferences = TestAppSettingsPreferences()
        let store = AppSettingsStore(preferences: preferences)

        store.setLexiconLayout(.ruled)
        store.setLexiconRuledLineStyle(.gridCutout)

        let restored = AppSettingsStore(preferences: preferences)
        #expect(restored.lexicon.layout == .ruled)
        #expect(restored.lexicon.ruledLineStyle == .gridCutout)
        #expect(restored.wordBook.layout == .standard)
        #expect(restored.wordBook.ruledLineStyle == .alignedSolid, "集词阁隐格不能让单词本也隐格")
    }

    /// 中间版本两页共用一个横格线样式；升级后两页都沿用它，直到用户分别改动。
    @Test @MainActor func sharedRuledLineStyleMigratesToBothPagesUntilOverridden() {
        let preferences = TestAppSettingsPreferences()
        preferences.set(
            RuledLineStyle.dashed.rawValue,
            forKey: AppSettingsStore.StorageKey.legacyRuledLineStyle
        )

        let store = AppSettingsStore(preferences: preferences)
        #expect(store.wordBook.ruledLineStyle == .dashed)
        #expect(store.lexicon.ruledLineStyle == .dashed)

        store.setLexiconRuledLineStyle(.gridCutout)

        let restored = AppSettingsStore(preferences: preferences)
        #expect(restored.lexicon.ruledLineStyle == .gridCutout)
        #expect(restored.wordBook.ruledLineStyle == .dashed, "另一页继续沿用旧的共用值")
        #expect(
            preferences.string(forKey: AppSettingsStore.StorageKey.legacyRuledLineStyle) == "dashed",
            "旧键只读不写"
        )
    }

    /// 旧版本或手工改坏的偏好值不能把页面卡在未知样式上。
    @Test @MainActor func unknownLayoutPreferencesFallBackToDefaults() {
        let preferences = TestAppSettingsPreferences()
        preferences.set("cards", forKey: AppSettingsStore.StorageKey.wordBookLayout)
        preferences.set("sidebar", forKey: AppSettingsStore.StorageKey.lexiconLayout)
        preferences.set("dotted", forKey: AppSettingsStore.StorageKey.wordBookRuledLineStyle)
        preferences.set("wavy", forKey: AppSettingsStore.StorageKey.lexiconRuledLineStyle)

        let store = AppSettingsStore(preferences: preferences)

        #expect(store.wordBook.layout == .standard)
        #expect(store.lexicon.layout == .standard)
        #expect(store.wordBook.ruledLineStyle == .alignedSolid)
        #expect(store.lexicon.ruledLineStyle == .alignedSolid)
    }

    @Test func layoutStylesMapToFieldArrangements() {
        #expect(WordBookLayoutStyle.standard.fieldArrangement == .centered)
        #expect(WordBookLayoutStyle.ruled.fieldArrangement == .ruled)
        #expect(WordBookLayoutStyle.journal.fieldArrangement == .journal)
        #expect(LexiconLayoutStyle.standard.fieldArrangement == .centered)
        #expect(LexiconLayoutStyle.ruled.fieldArrangement == .ruled)
    }

    @Test func journalArrangementUsesRoundedFontAndMarker() {
        #expect(EntryFieldArrangement.journal.fontDesign == .rounded)
        #expect(EntryFieldArrangement.journal.emphasizesFrequencyWithMarker)
        #expect(EntryFieldArrangement.journal.lineLimit == 1)
        #expect(EntryFieldArrangement.journal.alignsBaselines)
        #expect(!EntryFieldArrangement.ruled.emphasizesFrequencyWithMarker)
        #expect(EntryFieldArrangement.centered.fontDesign == .default)
    }

    // MARK: - 页面氛围与背景

    @Test @MainActor func atmospherePreferencesDefaultOffAndPersist() {
        let preferences = TestAppSettingsPreferences()
        let store = AppSettingsStore(preferences: preferences)

        #expect(!store.wordBook.showsLamp)
        #expect(!store.lexicon.showsGuideWords)
        #expect(!store.lexicon.showsStamp)

        store.setWordBookLamp(true)
        store.setLexiconGuideWords(true)
        store.setLexiconStamp(true)

        let restored = AppSettingsStore(preferences: preferences)
        #expect(restored.wordBook.showsLamp)
        #expect(restored.lexicon.showsGuideWords)
        #expect(restored.lexicon.showsStamp)
        #expect(restored.personalization.lexicon.showsStamp)
    }

    /// 四个页面各存一份背景；改任何一页都不能牵动其它页，这正是用户报告的"负反馈"根因。
    @Test @MainActor func pageBackgroundPatternsPersistIndependently() {
        let preferences = TestAppSettingsPreferences()
        let store = AppSettingsStore(preferences: preferences)

        store.setBackgroundPattern(.none, for: .dashboard)
        store.setBackgroundPattern(.dots, for: .wordBook)
        store.setBackgroundPattern(.grid, for: .lexicon)
        store.setBackgroundPattern(.none, for: .wordQuiz)

        let restored = AppSettingsStore(preferences: preferences)
        let personalization = restored.personalization
        #expect(personalization.backgroundPattern(for: .dashboard) == .none)
        #expect(personalization.backgroundPattern(for: .wordBook) == .dots)
        #expect(personalization.backgroundPattern(for: .lexicon) == .grid)
        #expect(personalization.backgroundPattern(for: .wordQuiz) == .none)

        restored.setBackgroundPattern(.none, for: .dashboard)
        #expect(restored.lexicon.backgroundPattern == .grid, "关掉首页网格不能关掉集词阁的网格")
        #expect(restored.wordBook.backgroundPattern == .dots)
    }

    @Test @MainActor func legacyBackgroundPreferencesMigrateWithoutChangingAppearance() {
        let preferences = TestAppSettingsPreferences()
        preferences.set(false, forKey: AppSettingsStore.StorageKey.legacyGridBackground)
        preferences.set(
            PageBackgroundPattern.dots.rawValue,
            forKey: AppSettingsStore.StorageKey.legacyWordBookBackgroundPattern
        )

        var restored = AppSettingsStore(preferences: preferences)
        for page in PageBackgroundScope.allCases {
            #expect(restored.personalization.backgroundPattern(for: page) == .none, "旧开关关闭时所有页面都无图案")
        }

        preferences.set(true, forKey: AppSettingsStore.StorageKey.legacyGridBackground)
        restored = AppSettingsStore(preferences: preferences)
        #expect(restored.dashboardBackgroundPattern == .grid)
        #expect(restored.wordBook.backgroundPattern == .dots, "旧单词本图案只迁移给单词本")
        #expect(restored.lexicon.backgroundPattern == .grid)
        #expect(restored.wordQuiz.backgroundPattern == .grid)
    }

    /// 中间版本把三个功能页绑在一个"功能页背景"上；升级后先按它铺开，再各自独立。
    @Test @MainActor func interimSharedFeatureBackgroundSeedsEachFeaturePage() {
        let preferences = TestAppSettingsPreferences()
        preferences.set(
            PageBackgroundPattern.dots.rawValue,
            forKey: AppSettingsStore.StorageKey.legacyFeatureBackgroundPattern
        )

        let store = AppSettingsStore(preferences: preferences)
        #expect(store.dashboardBackgroundPattern == .grid, "首页不受功能页共用键影响")
        #expect(store.wordBook.backgroundPattern == .dots)
        #expect(store.lexicon.backgroundPattern == .dots)
        #expect(store.wordQuiz.backgroundPattern == .dots)

        store.setBackgroundPattern(.none, for: .lexicon)

        let restored = AppSettingsStore(preferences: preferences)
        #expect(restored.lexicon.backgroundPattern == .none)
        #expect(restored.wordBook.backgroundPattern == .dots)
        #expect(restored.wordQuiz.backgroundPattern == .dots)
    }

    @Test @MainActor func unknownPageBackgroundPatternsFallBackToGrid() {
        let preferences = TestAppSettingsPreferences()
        preferences.set(
            "stripes",
            forKey: AppSettingsStore.StorageKey.dashboardBackgroundPattern
        )
        preferences.set(
            "paper",
            forKey: AppSettingsStore.StorageKey.wordBookBackgroundPattern
        )

        let store = AppSettingsStore(preferences: preferences)
        #expect(store.dashboardBackgroundPattern == .grid)
        #expect(store.wordBook.backgroundPattern == .grid)
    }

    // MARK: - 手帐分组

    @Test func journalGroupsEntriesByLatestDateNewestFirstThenUnarchived() throws {
        let d1 = try #require(VocabularyDocumentDate(year: 2026, month: 9, day: 9))
        let d2 = try #require(VocabularyDocumentDate(year: 2026, month: 9, day: 11))
        let d3 = try #require(VocabularyDocumentDate(year: 2026, month: 9, day: 13))
        let entries = [
            makeEntry("a", dates: [d1]),
            makeEntry("b", dates: [d1, d3]),
            makeEntry("c", dates: []),
            makeEntry("d", dates: [d2]),
            makeEntry("e", dates: [d3]),
        ]

        let sections = WordBookJournal.sections(for: entries, today: d3)

        #expect(sections.map(\.id) == [d3.storageKey, d2.storageKey, d1.storageKey, WordBookJournal.unarchivedSectionID])
        #expect(sections[0].items.map(\.term) == ["b", "e"], "多日期词条归入最近的一天，组内保持传入顺序")
        #expect(sections[0].subtitle == "今天 · 2 词")
        #expect(sections[1].items.map(\.term) == ["d"])
        #expect(sections[2].items.map(\.term) == ["a"])
        #expect(sections[3].title == "未归档")
        #expect(sections[3].items.map(\.term) == ["c"])
        #expect(sections.flatMap(\.items).count == entries.count, "分组不丢词")
    }

    @Test func journalSingleSectionHasNoTitleAndIsEmptyForNoEntries() throws {
        let date = try #require(VocabularyDocumentDate(year: 2026, month: 9, day: 9))
        let single = WordBookJournal.singleSection([makeEntry("a", dates: [date])], id: "page")
        #expect(single.count == 1)
        #expect(single[0].title == nil)
        #expect(WordBookJournal.singleSection([], id: "page").isEmpty)
    }

    private func makeEntry(_ term: String, dates: [VocabularyDocumentDate]) -> WordBookEntrySnapshot {
        WordBookEntrySnapshot(
            id: UUID(),
            term: term,
            meaning: "释义",
            source: dates.isEmpty ? .manual : .markdownImport,
            occurrenceDates: dates
        )
    }

    @Test func ruledArrangementIsSingleLineAndBaselineAligned() {
        #expect(EntryFieldArrangement.ruled.lineLimit == 1)
        #expect(EntryFieldArrangement.ruled.alignsBaselines)
        #expect(EntryFieldArrangement.ruled.minHeight == nil, "横格行高由纸面决定")
        #expect(EntryFieldArrangement.centered.lineLimit == nil)
        #expect(!EntryFieldArrangement.centered.alignsBaselines)
        #expect(EntryFieldArrangement.centered.minHeight == AppTheme.entryMinHeight)
    }

    // MARK: - 字号

    /// 单词本与词库共用一组字号常量；设计定稿 26 / 20（2026-09-13）。
    @Test func entryFontSizesAreSharedAndMatchTheDesign() {
        #expect(AppTheme.entryTermFontSize == 26)
        #expect(AppTheme.entryGlossFontSize == 20)
        #expect(AppTheme.entryTermFontSize > AppTheme.entryGlossFontSize, "单词必须比词义大一档")
    }

    // MARK: - 横格本几何

    @Test func ruledRowHeightIsAWholeNumberOfGridCells() {
        let cells = AppTheme.ruledRowHeight / AppTheme.backgroundGridSpacing
        #expect(cells == cells.rounded(), "行高不是网格整数倍时，「对齐实线」就对不齐")
        let columns = AppTheme.ruledNumberColumnWidth / AppTheme.backgroundGridSpacing
        #expect(columns == columns.rounded(), "行号列宽不是网格整数倍时，页边线会落在格子中间")
        #expect(AppTheme.ruledWordBookBottomInset.truncatingRemainder(dividingBy: AppTheme.backgroundGridSpacing) == 0)
        #expect(AppTheme.ruledLexiconBottomInset.truncatingRemainder(dividingBy: AppTheme.backgroundGridSpacing) == 0)
    }

    /// 隐格向内延伸 42 pt（2026-09-14 定稿），且延伸必须长于淡出，否则淡出会越过滚动区边缘。
    @Test func gridCutoutInsetMatchesDecisionAndExceedsFeather() {
        #expect(AppTheme.ruledGridCutoutInset == 42)
        #expect(AppTheme.ruledGridCutoutInset > AppTheme.ruledGridFeather)
    }

    @Test func ruledSheetPairsItemsTwoPerRow() {
        let rows = RuledSheetGeometry.rows(of: [1, 2, 3, 4, 5])

        #expect(rows.count == 3)
        #expect(rows[0].leading == 1 && rows[0].trailing == 2)
        #expect(rows[2].leading == 5 && rows[2].trailing == nil, "奇数个词条时最后一行右侧留空")
        #expect(RuledSheetGeometry.rows(of: [Int]()).isEmpty)
    }

    @Test func ruledSheetGridPhaseAlignsWithGlobalGrid() {
        let spacing = AppTheme.backgroundGridSpacing
        #expect(RuledSheetGeometry.gridPhase(globalMinX: 0) == 0)
        #expect(RuledSheetGeometry.gridPhase(globalMinX: spacing * 3) == 0)
        #expect(RuledSheetGeometry.gridPhase(globalMinX: 10) == spacing - 10)
        #expect(RuledSheetGeometry.gridPhase(globalMinX: -10) == 10)
    }

    @Test func ruledSheetDividerSnapsToGridAndKeepsFirstCellUsable() {
        let spacing = AppTheme.backgroundGridSpacing
        let inset = AppTheme.contentPadding
        let marginX = RuledSheetGeometry.marginX(horizontalInset: inset)

        let wide = RuledSheetGeometry.dividerX(paperWidth: 1080, horizontalInset: inset, gridPhase: 0)
        #expect(wide.truncatingRemainder(dividingBy: spacing) == 0, "竖线必须落在网格线上")
        let midpoint = marginX + (1080 - inset - marginX) / 2
        #expect(abs(wide - midpoint) <= spacing / 2, "吸附不应偏离中点超过半格")

        let narrow = RuledSheetGeometry.dividerX(paperWidth: 120, horizontalInset: inset, gridPhase: 0)
        #expect(narrow >= marginX + spacing, "极窄时第一个格子至少保留一格")
    }

    // MARK: - 字段排布

    @Test func entryFieldsLayoutSplitsWidthByProportion() {
        let widths = EntryFieldsLayout.fieldWidths(
            totalWidth: 245,
            count: 2,
            spacing: 20,
            proportions: [1, 1.25]
        )
        #expect(widths.count == 2)
        #expect(abs(widths[0] - 100) < 0.001)
        #expect(abs(widths[1] - 125) < 0.001)
    }

    @Test func entryFieldsLayoutDefaultsToEqualWidths() {
        let widths = EntryFieldsLayout.fieldWidths(
            totalWidth: 218,
            count: 2,
            spacing: 18,
            proportions: []
        )
        #expect(widths == [100, 100])

        let padded = EntryFieldsLayout.fieldWidths(
            totalWidth: 300,
            count: 3,
            spacing: 0,
            proportions: [2]
        )
        #expect(padded == [150, 75, 75], "比例数量不足时，缺省字段按 1 计")
    }

    @Test func entryFieldsLayoutNeverProducesNegativeWidths() {
        let widths = EntryFieldsLayout.fieldWidths(
            totalWidth: 10,
            count: 2,
            spacing: 18,
            proportions: []
        )
        #expect(widths.allSatisfy { $0 >= 0 })
        #expect(EntryFieldsLayout.fieldWidths(totalWidth: 100, count: 0, spacing: 0, proportions: []).isEmpty)
    }
}

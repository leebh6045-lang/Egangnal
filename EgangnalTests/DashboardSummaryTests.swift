//
//  DashboardSummaryTests.swift
//  EgangnalTests
//

import Foundation
import Testing
@testable import Egangnal

/// 首页最近页面只做确定性聚合，不依赖界面层或数据库实现。
struct DashboardSummaryTests {
    @Test @MainActor
    func storeExposesRepositoryFailureInsteadOfPretendingTheBookIsEmpty() {
        let store = DashboardStore(repository: UnavailableWordBookRepository())

        store.reload()

        #expect(
            store.state == .unavailable(
                WordBookRepositoryError.storageUnavailable.localizedDescription
            )
        )
    }

    @Test
    func recentPagesMergeLanguagesAndSortNewestFirst() {
        let latest = date(2026, 9, 13)
        let middle = date(2026, 9, 11)
        let earliest = date(2026, 9, 9)
        let older = date(2026, 9, 2)
        let entries: [LanguageSpace: [WordBookEntrySnapshot]] = [
            .english: [
                entry("english-a", dates: [latest, middle]),
                entry("english-b", dates: [latest]),
                entry("english-old", dates: [older]),
                entry("english-loose", dates: [])
            ],
            .japanese: [
                entry("japanese-a", dates: [middle]),
                entry("japanese-b", dates: [earliest]),
                entry("japanese-loose", dates: [])
            ]
        ]

        let pages = DashboardSummaryBuilder.recentPages(from: entries)

        #expect(pages == [
            DashboardRecentPage(kind: .dated(latest), wordCount: 2),
            DashboardRecentPage(kind: .dated(middle), wordCount: 2),
            DashboardRecentPage(kind: .dated(earliest), wordCount: 1),
            DashboardRecentPage(kind: .unarchived, wordCount: 2)
        ])
    }

    @Test
    func recentPagesDeduplicateRepeatedDatesInsideOneEntry() {
        let pageDate = date(2026, 9, 13)
        let pages = DashboardSummaryBuilder.recentPages(
            from: [.english: [entry("word", dates: [pageDate, pageDate])]]
        )

        #expect(pages == [
            DashboardRecentPage(kind: .dated(pageDate), wordCount: 1)
        ])
    }

    @Test
    func recentPagesHandleEmptyDataAndNonPositiveLimit() {
        #expect(DashboardSummaryBuilder.recentPages(from: [:]).isEmpty)
        #expect(
            DashboardSummaryBuilder.recentPages(
                from: [.english: [entry("word", dates: [date(2026, 9, 13)])]],
                limit: 0
            ).isEmpty
        )
    }

    private func entry(
        _ term: String,
        dates: [VocabularyDocumentDate]
    ) -> WordBookEntrySnapshot {
        WordBookEntrySnapshot(
            id: UUID(),
            term: term,
            meaning: "释义",
            source: dates.isEmpty ? .manual : .markdownImport,
            occurrenceDates: dates
        )
    }

    private func date(_ year: Int, _ month: Int, _ day: Int) -> VocabularyDocumentDate {
        VocabularyDocumentDate(year: year, month: month, day: day)!
    }
}

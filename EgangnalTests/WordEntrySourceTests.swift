//
//  WordEntrySourceTests.swift
//  EgangnalTests
//

import Foundation
import SwiftData
import Testing
@testable import Egangnal

/// 词条来源枚举的迁移与收录行为。
///
/// 这些不变量一旦破坏，用户既有的单词本会出现“手动新增的词凭空消失”
/// 或“高频词统计被收藏污染”这类不可逆后果，因此必须逐条锁定。
@MainActor
struct WordEntrySourceTests {
    @Test @MainActor
    func legacyRowsWithoutSourceFallBackToTheOldFlag() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        let legacyManual = makeLegacyEntry(term: "manual", source: .manual)
        let legacyImported = makeLegacyEntry(term: "imported", source: .markdownImport)
        context.insert(legacyManual)
        context.insert(legacyImported)
        try context.save()

        // 尚未回填时必须退回旧字段推断，否则手动词条会被误判成导入词条。
        #expect(legacyManual.needsSourceBackfill)
        #expect(legacyManual.source == .manual)
        #expect(legacyImported.source == .markdownImport)
    }

    @Test @MainActor
    func migrationBackfillsLegacySourcesAndPersists() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        context.insert(makeLegacyEntry(term: "manual", source: .manual))
        context.insert(makeLegacyEntry(term: "imported", source: .markdownImport))
        try context.save()

        let repository = SwiftDataWordBookRepository(modelContainer: container)
        let migrated = try repository.migrateLegacyEntrySourcesIfNeeded()

        #expect(migrated == 2)
        let entries = try repository.entries(in: .english)
        #expect(entries.count == 2)
        #expect(entries.first { $0.term == "manual" }?.source == .manual)
        #expect(entries.first { $0.term == "imported" }?.source == .markdownImport)

        // 回填结果必须落盘：新开一个上下文重新读取。
        let reloaded = ModelContext(container)
        let stored = try reloaded.fetch(FetchDescriptor<WordEntry>())
        #expect(stored.allSatisfy { !$0.needsSourceBackfill })
    }

    @Test @MainActor
    func migrationIsIdempotentAndSkipsMigratedRows() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        context.insert(makeLegacyEntry(term: "manual", source: .manual))
        try context.save()

        let repository = SwiftDataWordBookRepository(modelContainer: container)
        #expect(try repository.migrateLegacyEntrySourcesIfNeeded() == 1)
        // 第二次没有待回填的行。
        #expect(try repository.migrateLegacyEntrySourcesIfNeeded() == 0)
    }

    // MARK: - 收录

    @Test @MainActor
    func collectIsIdempotentAndKeepsTheFirstMeaning() throws {
        let container = try makeContainer()
        let repository = SwiftDataWordBookRepository(modelContainer: container)

        let first = try repository.collectFromLexicon(
            term: "abandon",
            meaning: "vt. 放弃, 抛弃",
            collectedAt: .now,
            in: .english
        )
        // 大小写不同但规范化后是同一个词。
        let second = try repository.collectFromLexicon(
            term: "Abandon",
            meaning: "vt. 遗弃",
            collectedAt: .now,
            in: .english
        )

        #expect(first == .inserted)
        #expect(second == .alreadyExists)
        let entries = try repository.entries(in: .english)
        #expect(entries.count == 1)
        #expect(entries.first?.meaning == "vt. 放弃, 抛弃")
        #expect(entries.first?.source == .lexiconCollection)
    }

    /// 收藏计入**当日**出现记录：用户当天在词库遇到的生词会出现在今天的日期分组里。
    @Test @MainActor
    func collectRecordsTodayAsAnOccurrence() throws {
        let container = try makeContainer()
        let repository = SwiftDataWordBookRepository(modelContainer: container)
        let collectedAt = Date(timeIntervalSince1970: 1_788_000_000)
        let today = VocabularyDocumentDate(date: collectedAt)

        _ = try repository.collectFromLexicon(
            term: "abandon",
            meaning: "vt. 放弃",
            collectedAt: collectedAt,
            in: .english
        )

        let entry = try #require(try repository.entries(in: .english).first)
        #expect(entry.occurrenceDates == [today])
        #expect(entry.isUnarchived == false, "收藏后不应再归入未归档单词")

        let todayEntries = try repository.entries(on: today, in: .english)
        #expect(todayEntries.map(\.term) == ["abandon"])
    }

    /// 同一天重复收藏不产生第二条当天记录。
    @Test @MainActor
    func collectingTwiceOnTheSameDayStaysIdempotent() throws {
        let container = try makeContainer()
        let repository = SwiftDataWordBookRepository(modelContainer: container)
        let collectedAt = Date(timeIntervalSince1970: 1_788_000_000)

        let first = try repository.collectFromLexicon(
            term: "abandon", meaning: "vt. 放弃", collectedAt: collectedAt, in: .english
        )
        let second = try repository.collectFromLexicon(
            term: "abandon", meaning: "vt. 放弃", collectedAt: collectedAt, in: .english
        )

        #expect(first == .inserted)
        #expect(second == .alreadyExists)
        let entry = try #require(try repository.entries(in: .english).first)
        #expect(entry.occurrenceDates.count == 1)
    }

    /// 仓储层面允许不同日期分别收藏并成为高频词。
    ///
    /// 注意：**界面不会产生这种数据**——收藏按钮是二元开关，已收藏时再次点击是取消。
    /// 这条测试锁定的是仓储契约（异常路径下也要自洽），不是日常行为。
    @Test @MainActor
    func collectingOnTwoDaysMakesTheWordHighFrequency() throws {
        let container = try makeContainer()
        let repository = SwiftDataWordBookRepository(modelContainer: container)

        _ = try repository.collectFromLexicon(
            term: "abandon",
            meaning: "vt. 放弃",
            collectedAt: Date(timeIntervalSince1970: 1_788_000_000),
            in: .english
        )
        _ = try repository.collectFromLexicon(
            term: "abandon",
            meaning: "vt. 放弃",
            collectedAt: Date(timeIntervalSince1970: 1_788_000_000 + 86_400),
            in: .english
        )

        let entry = try #require(try repository.entries(in: .english).first)
        #expect(entry.occurrenceDates.count == 2)
        #expect(entry.isHighFrequency)
    }

    // MARK: - 取消收藏

    /// 只来自词库收藏的词条，取消后整体删除。
    @Test @MainActor
    func uncollectingRemovesEntriesThatCameOnlyFromTheLexicon() throws {
        let container = try makeContainer()
        let repository = SwiftDataWordBookRepository(modelContainer: container)
        let collectedAt = Date(timeIntervalSince1970: 1_788_000_000)

        _ = try repository.collectFromLexicon(
            term: "abandon", meaning: "vt. 放弃", collectedAt: collectedAt, in: .english
        )

        let outcome = try repository.uncollectFromLexicon(term: "abandon", in: .english)

        #expect(outcome == .removed)
        #expect(try repository.entries(in: .english).isEmpty)
        #expect(try repository.entries(on: VocabularyDocumentDate(date: collectedAt), in: .english).isEmpty)
        #expect(try repository.lexiconCollectionInfo(in: .english).isEmpty)
    }

    /// 同时有文档导入记录时，只移除收藏记录，词条与文档日期原样保留。
    @Test @MainActor
    func uncollectingKeepsDocumentsAndRemovesOnlyTheCollection() throws {
        let container = try makeContainer()
        let repository = SwiftDataWordBookRepository(modelContainer: container)
        let documentDate = try #require(VocabularyDocumentDate(year: 2026, month: 8, day: 16))
        let collectedAt = Date(timeIntervalSince1970: 1_788_000_000)

        _ = try repository.importDocument(
            ParsedWordDocument(
                sourceDate: documentDate,
                words: [ParsedWord(term: "abandon", meaning: "导入的释义", lineNumber: 1)]
            ),
            into: .english,
            sourceFilename: "2026年08月16日.md",
            importedAt: .now
        )
        _ = try repository.collectFromLexicon(
            term: "abandon", meaning: "词库的释义", collectedAt: collectedAt, in: .english
        )

        let outcome = try repository.uncollectFromLexicon(term: "abandon", in: .english)

        #expect(outcome == .removedCollectionOnly)
        let entry = try #require(try repository.entries(in: .english).first)
        // 文档导入的日期与释义都不能被取消收藏牵连。
        #expect(entry.occurrenceDates == [documentDate])
        #expect(entry.meaning == "导入的释义")
        #expect(entry.source == .markdownImport)
    }

    /// 从未收藏过的词，取消收藏不做任何事。
    @Test @MainActor
    func uncollectingAnImportedEntryIsRefused() throws {
        let container = try makeContainer()
        let repository = SwiftDataWordBookRepository(modelContainer: container)
        let documentDate = try #require(VocabularyDocumentDate(year: 2026, month: 8, day: 16))

        _ = try repository.importDocument(
            ParsedWordDocument(
                sourceDate: documentDate,
                words: [ParsedWord(term: "abandon", meaning: "导入的释义", lineNumber: 1)]
            ),
            into: .english,
            sourceFilename: "2026年08月16日.md",
            importedAt: .now
        )

        #expect(try repository.uncollectFromLexicon(term: "abandon", in: .english) == .managedInWordBook)
        #expect(try repository.uncollectFromLexicon(term: "missing", in: .english) == .notCollected)
        #expect(try repository.entries(in: .english).count == 1)
    }

    /// 浮层要显示收藏日期，因此状态必须带上日期。
    @Test @MainActor
    func collectionInfoCarriesTheCollectedDates() throws {
        let container = try makeContainer()
        let repository = SwiftDataWordBookRepository(modelContainer: container)
        let collectedAt = Date(timeIntervalSince1970: 1_788_000_000)
        let today = VocabularyDocumentDate(date: collectedAt)

        _ = try repository.collectFromLexicon(
            term: "abandon", meaning: "vt. 放弃", collectedAt: collectedAt, in: .english
        )

        let info = try repository.lexiconCollectionInfo(in: .english)
        #expect(info["abandon"]?.state == .collected)
        #expect(info["abandon"]?.collectedDates == [today])

        // 撤销后日期一并消失。
        _ = try repository.uncollectFromLexicon(term: "abandon", in: .english)
        #expect(try repository.lexiconCollectionInfo(in: .english).isEmpty)
    }

    /// 文档导入的词没有收藏日期，但状态是“已在单词本”。
    @Test @MainActor
    func importedEntriesCarryNoCollectedDates() throws {
        let container = try makeContainer()
        let repository = SwiftDataWordBookRepository(modelContainer: container)
        let documentDate = try #require(VocabularyDocumentDate(year: 2026, month: 8, day: 16))

        _ = try repository.importDocument(
            ParsedWordDocument(
                sourceDate: documentDate,
                words: [ParsedWord(term: "imported", meaning: "导入", lineNumber: 1)]
            ),
            into: .english,
            sourceFilename: "2026年08月16日.md",
            importedAt: .now
        )

        let info = try repository.lexiconCollectionInfo(in: .english)
        #expect(info["imported"]?.state == .managedInWordBook)
        #expect(info["imported"]?.collectedDates.isEmpty == true)
    }

    /// 收藏状态要能区分“词库收藏”与“文档导入”。
    @Test @MainActor
    func collectionStatesDistinguishLexiconFromDocuments() throws {
        let container = try makeContainer()
        let repository = SwiftDataWordBookRepository(modelContainer: container)
        let documentDate = try #require(VocabularyDocumentDate(year: 2026, month: 8, day: 16))

        _ = try repository.importDocument(
            ParsedWordDocument(
                sourceDate: documentDate,
                words: [ParsedWord(term: "imported", meaning: "导入", lineNumber: 1)]
            ),
            into: .english,
            sourceFilename: "2026年08月16日.md",
            importedAt: .now
        )
        _ = try repository.collectFromLexicon(
            term: "collected", meaning: "收藏", collectedAt: .now, in: .english
        )

        let info = try repository.lexiconCollectionInfo(in: .english)

        #expect(info["collected"]?.state == .collected)
        #expect(info["imported"]?.state == .managedInWordBook)
        #expect(info["absent"] == nil)
    }

    @Test @MainActor
    func collectNeverOverwritesAnImportedEntry() throws {
        let container = try makeContainer()
        let repository = SwiftDataWordBookRepository(modelContainer: container)
        let date = try #require(VocabularyDocumentDate(year: 2026, month: 8, day: 16))

        _ = try repository.importDocument(
            ParsedWordDocument(
                sourceDate: date,
                words: [ParsedWord(term: "abandon", meaning: "导入的释义", lineNumber: 1)]
            ),
            into: .english,
            sourceFilename: "2026年08月16日.md",
            importedAt: .now
        )

        let outcome = try repository.collectFromLexicon(
            term: "abandon",
            meaning: "词库的释义",
            collectedAt: .now,
            in: .english
        )

        // 词条已存在：补上今天的收录记录，但**不覆盖**文档导入的释义。
        #expect(outcome == .inserted)
        let entry = try #require(try repository.entries(in: .english).first)
        #expect(entry.meaning == "导入的释义")
        #expect(entry.source == .markdownImport)
        // 既有的文档日期保持不变，今天再记一次。
        #expect(entry.occurrenceDates.contains(date))
        #expect(entry.occurrenceDates.count == 2)
    }

    @Test @MainActor
    func collectKeepsLanguageSpacesIndependent() throws {
        let container = try makeContainer()
        let repository = SwiftDataWordBookRepository(modelContainer: container)

        _ = try repository.collectFromLexicon(
            term: "language",
            meaning: "语言",
            collectedAt: .now,
            in: .english
        )

        #expect(try repository.entries(in: .japanese).isEmpty)
        #expect(try repository.entries(in: .english).count == 1)
    }

    @Test @MainActor
    func collectRejectsEmptyFields() throws {
        let container = try makeContainer()
        let repository = SwiftDataWordBookRepository(modelContainer: container)

        #expect(throws: WordBookRepositoryError.emptyTerm) {
            _ = try repository.collectFromLexicon(term: "   ", meaning: "释义", collectedAt: .now, in: .english)
        }
        #expect(throws: WordBookRepositoryError.emptyMeaning) {
            _ = try repository.collectFromLexicon(term: "abandon", meaning: "  ", collectedAt: .now, in: .english)
        }
    }

    // MARK: - 与单词刷的联动（阶段 5.5）

    /// 收藏词条必须能进单词刷的默认抽题范围，取消收藏后退回未收藏状态。
    ///
    /// 这条链路跨了三个对象（词库页写单词本 → 仓储 → 抽题候选源），任何一环改成
    /// "收藏不写出现记录"都会让收藏的词永远抽不到，因此必须端到端锁定，而不是伪造快照。
    @Test @MainActor
    func collectedLexiconWordsEnterAndLeaveTheDefaultQuizPool() throws {
        let container = try makeContainer()
        let repository = SwiftDataWordBookRepository(modelContainer: container)
        let candidateSource = WordQuizCandidateSource(repository: repository)

        #expect(try candidateSource.allImportedCandidates(in: .english).isEmpty)

        _ = try repository.collectFromLexicon(
            term: "abandon",
            meaning: "vt. 放弃, 抛弃…",
            collectedAt: .now,
            in: .english
        )

        let candidates = try candidateSource.allImportedCandidates(in: .english)
        let collected = try #require(candidates.first { $0.term == "abandon" })
        // 释义必须与写入时逐字一致：单词刷的选项直接渲染这个字段。
        #expect(collected.meaning == "vt. 放弃, 抛弃…")
        // 收藏计入当日，因此它也应当出现在当天这个日期范围里。
        let today = VocabularyDocumentDate(date: .now)
        #expect(try candidateSource.availableDates(in: .english) == [today])
        #expect(try candidateSource.candidates(on: today, in: .english).map(\.term) == ["abandon"])

        _ = try repository.uncollectFromLexicon(term: "abandon", in: .english)

        #expect(try candidateSource.allImportedCandidates(in: .english).isEmpty)
        #expect(try candidateSource.availableDates(in: .english).isEmpty)
    }

    /// 反向锁定 ADR-003 决策 2：浏览词库是只读行为，没有收藏过的词条绝不能进抽题池。
    @Test @MainActor
    func uncollectedLexiconEntriesNeverReachTheQuizPool() throws {
        let container = try makeContainer()
        let repository = SwiftDataWordBookRepository(modelContainer: container)
        let candidateSource = WordQuizCandidateSource(repository: repository)
        let lexicon = try LexiconTestSupport.makeRepository()

        let page = try lexicon.page(matching: LexiconQuery(level: .cet4))
        #expect(!page.entries.isEmpty)

        _ = try repository.collectFromLexicon(
            term: "abandon",
            meaning: "vt. 放弃",
            collectedAt: .now,
            in: .english
        )
        let candidateIDs = Set(
            try candidateSource.allImportedCandidates(in: .english).map(\.id)
        )

        #expect(candidateIDs.count == 1)
        // 词库的确定性 UUID 与个人词条 UUID 是两套标识，未收藏的词条一个都不该出现。
        #expect(page.entries.allSatisfy { !candidateIDs.contains($0.id) })
    }

    // MARK: - 辅助

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema([
            WordEntry.self,
            WordImportBatch.self,
            WordOccurrence.self
        ])
        let configuration = ModelConfiguration(
            "WordEntrySourceTests",
            schema: schema,
            isStoredInMemoryOnly: true
        )
        return try ModelContainer(for: schema, configurations: [configuration])
    }

    /// 构造一条“旧库升级后尚未回填”的词条：来源为空，只有旧布尔字段有值。
    private func makeLegacyEntry(term: String, source: WordEntrySource) -> WordEntry {
        let normalizedTerm = WordNormalizer.normalizedTerm(term, in: .english)
        let entry = WordEntry(
            identityKey: WordNormalizer.identityKey(for: normalizedTerm, in: .english),
            languageSpaceID: LanguageSpace.english.rawValue,
            term: term,
            normalizedTerm: normalizedTerm,
            meaning: "释义",
            source: source
        )
        entry.sourceRawValue = ""
        return entry
    }
}

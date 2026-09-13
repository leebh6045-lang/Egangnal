//
//  LexiconCatalogStoreTests.swift
//  EgangnalTests
//

import Foundation
import Testing
@testable import Egangnal

@MainActor
struct LexiconCatalogStoreTests {
    @Test @MainActor
    func loadForwardsKeywordLevelAndPageIndex() throws {
        let repository = StubLexiconRepository()
        let store = makeStore(lexicon: repository)

        store.selectLevel(.cet4)
        store.updateKeyword("aban")

        let last = try #require(repository.requests.last)
        #expect(last.keyword == "aban")
        #expect(last.level == .cet4)
        #expect(last.pageIndex == 0)
    }

    @Test @MainActor
    func changingLevelOrKeywordReturnsToFirstPage() throws {
        let repository = StubLexiconRepository()
        repository.totalCount = 200
        let store = makeStore(lexicon: repository)
        store.load()

        store.goToNextPage()
        #expect(store.requestedPageIndex == 1)

        store.selectLevel(.cet6)
        #expect(store.requestedPageIndex == 0)

        store.goToNextPage()
        #expect(store.requestedPageIndex == 1)

        store.updateKeyword("apple")
        #expect(store.requestedPageIndex == 0)
    }

    @Test @MainActor
    func redundantSelectionDoesNotReload() {
        let repository = StubLexiconRepository()
        let store = makeStore(lexicon: repository)

        store.selectLevel(.cet4)
        let countAfterFirst = repository.requests.count
        store.selectLevel(.cet4)
        #expect(repository.requests.count == countAfterFirst)

        store.updateKeyword("apple")
        let countAfterKeyword = repository.requests.count
        store.updateKeyword("apple")
        #expect(repository.requests.count == countAfterKeyword)
    }

    @Test @MainActor
    func paginationRespectsPageBounds() {
        let repository = StubLexiconRepository()
        // 100 条、每页 50 条，共 2 页。
        repository.totalCount = 100
        let store = makeStore(lexicon: repository)
        store.load()

        store.goToPreviousPage()
        #expect(store.requestedPageIndex == 0)

        store.goToNextPage()
        #expect(store.requestedPageIndex == 1)

        // 已在最后一页，不能再往后。
        store.goToNextPage()
        #expect(store.requestedPageIndex == 1)
    }

    @Test @MainActor
    func maskingIsIndependentPerEntryAndPerField() throws {
        let repository = StubLexiconRepository()
        let entry = Self.entry(term: "abandon")
        let other = Self.entry(term: "abide")
        repository.entries = [entry, other]
        repository.totalCount = 2

        let store = makeStore(lexicon: repository)
        store.load()

        #expect(store.hasAnyMask == false)

        store.toggleTermMask(entry)
        #expect(store.isTermMasked(entry))
        #expect(store.isGlossMasked(entry) == false)
        #expect(store.isTermMasked(other) == false)
        #expect(store.hasAnyMask)

        store.toggleGlossMask(other)
        #expect(store.isGlossMasked(other))
        #expect(store.isTermMasked(other) == false)

        // 再次点击同一个字段恢复显示。
        store.toggleTermMask(entry)
        #expect(store.isTermMasked(entry) == false)

        store.clearMasks()
        #expect(store.hasAnyMask == false)
        #expect(store.isGlossMasked(other) == false)
    }

    @Test @MainActor
    func pageChangeAndQueryChangeClearMasks() {
        let repository = StubLexiconRepository()
        let entry = Self.entry(term: "abandon")
        repository.entries = [entry]
        repository.totalCount = 200

        let store = makeStore(lexicon: repository)
        store.load()

        store.toggleGlossMask(entry)
        #expect(store.hasAnyMask)

        // 翻页后上一页的遮盖状态必须失效。
        store.goToNextPage()
        #expect(store.hasAnyMask == false)

        store.toggleGlossMask(entry)
        store.selectLevel(.cet6)
        #expect(store.hasAnyMask == false)

        store.toggleGlossMask(entry)
        store.updateKeyword("apple")
        #expect(store.hasAnyMask == false)
    }

    @Test @MainActor
    func repositoryFailureIsReportedWithoutFakeData() {
        let repository = StubLexiconRepository()
        repository.failure = LexiconRepositoryError.resourceMissing
        let store = makeStore(lexicon: repository)

        store.load()

        #expect(store.page.isEmpty)
        #expect(store.errorMessage == LexiconRepositoryError.resourceMissing.errorDescription)
        // 失败不能被伪装成“没有匹配结果”。
        #expect(store.isEmpty == false)
    }

    @Test @MainActor
    func emptyResultIsDistinctFromFailure() {
        let repository = StubLexiconRepository()
        let store = makeStore(lexicon: repository)

        store.load()

        #expect(store.isEmpty)
        #expect(store.errorMessage == nil)
    }

    @Test @MainActor
    func searchModeFollowsKeyword() {
        let store = makeStore(lexicon: StubLexiconRepository())

        store.updateKeyword("aban")
        #expect(store.searchMode == .englishPrefix)
        #expect(store.isSearching)

        store.updateKeyword("放弃")
        #expect(store.searchMode == .chineseMeaning)

        store.clearKeyword()
        #expect(store.isSearching == false)
        #expect(store.searchMode == .englishPrefix)
    }

    @Test @MainActor
    func selectedLevelTitleFallsBackToAll() {
        let store = makeStore(lexicon: StubLexiconRepository())

        #expect(store.selectedLevelTitle == "全部")
        store.selectLevel(.seniorHigh)
        #expect(store.selectedLevelTitle == "高中")
    }

    // MARK: - 收录

    @Test @MainActor
    func collectingSendsTermAndGlossOnly() throws {
        let wordBook = StubWordBookRepository()
        let store = makeStore(wordBook: wordBook)
        let entry = Self.entry(term: "abandon", gloss: "vt. 放弃, 抛弃")

        store.toggleCollection(entry)

        let request = try #require(wordBook.collectRequests.first)
        #expect(request.term == "abandon")
        // 收录字段只有单词与词性词义；音标、等级、词频都不写入。
        #expect(request.meaning == "vt. 放弃, 抛弃")
        #expect(request.space == .english)
    }

    /// 完整释义放进单词本会占七八行，因此只写入与列表一致的短释义。
    @Test @MainActor
    func collectingStoresTheShortGlossInsteadOfTheFullTranslation() throws {
        let wordBook = StubWordBookRepository()
        let store = makeStore(wordBook: wordBook)
        let entry = Self.entry(
            term: "program",
            gloss: "n. 节目, 节目单, 程序, 纲要, 大纲, 计划\n"
                + "vt. 规划, 拟...计划\nvi. 安排节目, 编程序\n[计] 程序"
        )

        store.toggleCollection(entry)

        let request = try #require(wordBook.collectRequests.first)
        #expect(request.meaning == "n. 节目, 节目单…")
        #expect(request.meaning.contains("\n") == false, "单词本里不应出现多行释义")
    }

    @Test @MainActor
    func browsingPassesShuffleSeedAndSearchingDoesNot() throws {
        let repository = StubLexiconRepository()
        let store = makeStore(lexicon: repository)

        store.load()
        #expect(try #require(repository.requests.last).shuffleSeed != nil)

        store.updateKeyword("aban")
        #expect(try #require(repository.requests.last).shuffleSeed == nil)
    }

    @Test @MainActor
    func reshuffleReturnsToFirstPageAndClearsMasks() throws {
        let repository = StubLexiconRepository()
        let entry = Self.entry(term: "abandon")
        repository.entries = [entry]
        repository.totalCount = 200
        let shuffle = ShuffleSeedController()
        let store = makeStore(lexicon: repository, shuffle: shuffle)
        store.loadInitial()

        store.goToNextPage()
        store.toggleGlossMask(entry)
        let seedBefore = try #require(repository.requests.last).shuffleSeed

        store.reshuffle()

        #expect(store.requestedPageIndex == 0)
        #expect(store.hasAnyMask == false)
        let seedAfter = try #require(repository.requests.last).shuffleSeed
        #expect(seedBefore != seedAfter, "换一批必须换种子，否则顺序不变")
    }

    @Test @MainActor
    func togglingACollectedWordUncollectsIt() {
        let wordBook = StubWordBookRepository()
        wordBook.statesResult = .success(["abandon": LexiconCollectionInfo(state: .collected, collectedDates: [])])
        wordBook.uncollectOutcome = .success(.removed)
        let store = makeStore(wordBook: wordBook)
        store.loadInitial()
        let entry = Self.entry(term: "abandon")

        store.toggleCollection(entry)

        #expect(wordBook.uncollectRequests == ["abandon"])
        #expect(store.collectionState(for: entry) == .notInWordBook)
        #expect(store.notice?.contains("已取消收藏") == true)
    }

    /// 词条另有文档导入来源时只移除收藏记录，词条仍在单词本中。
    @Test @MainActor
    func uncollectingKeepsEntriesThatAlsoCameFromDocuments() {
        let wordBook = StubWordBookRepository()
        wordBook.statesResult = .success(["abandon": LexiconCollectionInfo(state: .collected, collectedDates: [])])
        wordBook.uncollectOutcome = .success(.removedCollectionOnly)
        let store = makeStore(wordBook: wordBook)
        store.loadInitial()
        let entry = Self.entry(term: "abandon")

        store.toggleCollection(entry)

        #expect(store.collectionState(for: entry) == .managedInWordBook)
        #expect(store.notice?.contains("文档导入") == true)
    }

    /// 文档导入或手动新增的词，词库没有权限删除。
    @Test @MainActor
    func importedEntriesCannotBeUncollectedFromTheLexicon() {
        let wordBook = StubWordBookRepository()
        wordBook.statesResult = .success(["abandon": LexiconCollectionInfo(state: .managedInWordBook, collectedDates: [])])
        let store = makeStore(wordBook: wordBook)
        store.loadInitial()
        let entry = Self.entry(term: "abandon")

        store.toggleCollection(entry)

        #expect(wordBook.uncollectRequests.isEmpty)
        #expect(wordBook.collectRequests.isEmpty)
        #expect(store.collectionState(for: entry) == .managedInWordBook)
        #expect(store.notice?.contains("单词本中管理") == true)
    }

    @Test @MainActor
    func collectingMarksTheWordAndReportsSuccess() {
        let wordBook = StubWordBookRepository()
        wordBook.collectOutcome = .success(.inserted)
        let store = makeStore(wordBook: wordBook)
        let entry = Self.entry(term: "abandon")

        #expect(store.collectionState(for: entry) == .notInWordBook)

        store.toggleCollection(entry)

        #expect(store.collectionState(for: entry) == .collected)
        // 与“已在单词本中”区分开：新收录的提示必须包含“加入单词本”。
        #expect(store.notice?.contains("加入单词本") == true)
        #expect(store.notice?.contains("abandon") == true)
    }

    @Test @MainActor
    func collectingAnExistingWordStillReportsAndKeepsMark() {
        let wordBook = StubWordBookRepository()
        wordBook.collectOutcome = .success(.alreadyExists)
        let store = makeStore(wordBook: wordBook)
        let entry = Self.entry(term: "abandon")

        store.toggleCollection(entry)

        #expect(store.collectionState(for: entry) == .collected)
        // 同一天重复收藏：提示说明今天已收藏过，而不是再建一条记录。
        #expect(store.notice?.contains("今天已收藏过") == true)
    }

    @Test @MainActor
    func collectFailureIsReportedAndDoesNotMarkCollected() {
        let wordBook = StubWordBookRepository()
        wordBook.collectOutcome = .failure(WordBookRepositoryError.storageUnavailable)
        let store = makeStore(wordBook: wordBook)
        let entry = Self.entry(term: "abandon")

        store.toggleCollection(entry)

        #expect(store.collectionState(for: entry) == .notInWordBook)
        #expect(store.notice == WordBookRepositoryError.storageUnavailable.errorDescription)
    }

    @Test @MainActor
    func initialLoadReadsCollectedTermsFromWordBook() {
        let wordBook = StubWordBookRepository()
        // 仓储返回的键是规范化词形。
        wordBook.statesResult = .success([
            "abandon": LexiconCollectionInfo(state: .collected, collectedDates: []),
            "apple": LexiconCollectionInfo(state: .managedInWordBook, collectedDates: [])
        ])
        let store = makeStore(wordBook: wordBook)

        store.loadInitial()

        #expect(store.collectionState(for: Self.entry(term: "abandon")) == .collected)
        #expect(store.collectionState(for: Self.entry(term: "APPLE")) == .managedInWordBook)
        #expect(store.collectionState(for: Self.entry(term: "abide")) == .notInWordBook)
    }

    /// 打字与翻页不应反复查询个人单词本。
    @Test @MainActor
    func onlyInitialLoadReadsCollectedTerms() {
        let wordBook = StubWordBookRepository()
        let store = makeStore(wordBook: wordBook)

        store.loadInitial()
        let afterInitial = wordBook.statesRequestCount
        #expect(afterInitial == 1)

        store.updateKeyword("aban")
        store.goToNextPage()
        store.selectLevel(.cet4)
        #expect(wordBook.statesRequestCount == afterInitial)
    }

    @Test @MainActor
    func unreadableWordBookDoesNotBlockBrowsing() {
        let wordBook = StubWordBookRepository()
        wordBook.statesResult = .failure(WordBookRepositoryError.storageUnavailable)
        let store = makeStore(wordBook: wordBook)

        store.loadInitial()

        // 词库本身照常可用，只是没有“已收录”标记。
        #expect(store.errorMessage == nil)
        #expect(store.collectionInfo.isEmpty)
    }

    // MARK: - 辅助

    private func makeStore(
        lexicon: StubLexiconRepository = StubLexiconRepository(),
        wordBook: StubWordBookRepository = StubWordBookRepository(),
        shuffle: ShuffleSeedController = ShuffleSeedController()
    ) -> LexiconCatalogStore {
        LexiconCatalogStore(
            repository: lexicon,
            wordBookRepository: wordBook,
            shuffle: shuffle,
            space: .english
        )
    }

    private static func entry(
        term: String,
        gloss: String = "vt. 放弃, 抛弃"
    ) -> LexiconEntry {
        LexiconEntry(
            id: UUID(),
            term: term,
            phonetic: "ә'bændәn",
            gloss: gloss,
            levels: [.cet4, .cet6]
        )
    }

}

/// 回显请求页码的桩仓储：分页断言依赖这一点，否则连翻两次仍是第一页。
@MainActor
private final class StubLexiconRepository: LexiconRepository {
    var requests: [LexiconQuery] = []
    var entries: [LexiconEntry] = []
    var totalCount = 0
    var failure: Error?

    func page(matching query: LexiconQuery) throws -> LexiconPage {
        requests.append(query)
        if let failure {
            throw failure
        }
        return LexiconPage(
            entries: entries,
            totalCount: totalCount,
            pageIndex: query.pageIndex,
            pageSize: LexiconQuery.pageSize
        )
    }

    func entries(matching query: LexiconQuery) throws -> [LexiconEntry] {
        requests.append(query)
        if let failure {
            throw failure
        }
        return entries
    }
}

@MainActor
private final class StubWordBookRepository: WordBookRepository {
    var statesResult: Result<[String: LexiconCollectionInfo], Error> = .success([:])
    var collectOutcome: Result<WordBookCollectionOutcome, Error> = .success(.inserted)
    var uncollectOutcome: Result<WordBookCollectionOutcome, Error> = .success(.removed)
    var collectRequests: [(term: String, meaning: String, space: LanguageSpace)] = []
    var uncollectRequests: [String] = []
    var statesRequestCount = 0

    func importDocument(
        _ document: ParsedWordDocument,
        into space: LanguageSpace,
        sourceFilename: String,
        importedAt: Date
    ) throws -> WordBookImportResult {
        throw TestFailure.unexpectedCall
    }

    func entries(in space: LanguageSpace) throws -> [WordBookEntrySnapshot] {
        []
    }

    func entries(
        on date: VocabularyDocumentDate,
        in space: LanguageSpace
    ) throws -> [WordBookEntrySnapshot] {
        []
    }

    func addManualEntry(term: String, meaning: String, in space: LanguageSpace) throws -> UUID {
        throw TestFailure.unexpectedCall
    }

    func collectFromLexicon(
        term: String,
        meaning: String,
        collectedAt: Date,
        in space: LanguageSpace
    ) throws -> WordBookCollectionOutcome {
        collectRequests.append((term, meaning, space))
        return try collectOutcome.get()
    }

    func uncollectFromLexicon(
        term: String,
        in space: LanguageSpace
    ) throws -> WordBookCollectionOutcome {
        uncollectRequests.append(term)
        return try uncollectOutcome.get()
    }

    func lexiconCollectionInfo(
        in space: LanguageSpace
    ) throws -> [String: LexiconCollectionInfo] {
        statesRequestCount += 1
        return try statesResult.get()
    }

    func updateEntry(id: UUID, term: String, meaning: String, in space: LanguageSpace) throws {
        throw TestFailure.unexpectedCall
    }

    func deleteEntry(id: UUID, in space: LanguageSpace) throws {
        throw TestFailure.unexpectedCall
    }

    private enum TestFailure: Error { case unexpectedCall }
}

//
//  LexiconCatalogStore.swift
//  Egangnal
//

import Foundation
import Observation

/// 词库页面的可观察状态。
///
/// 只回答“用户刚刚做了什么、现在该显示什么”，不解析 SQL，也不直接操作 SwiftData。
/// 公共词库整体只读，因此这里没有任何写入路径。
@MainActor
@Observable
final class LexiconCatalogStore {
    private let repository: any LexiconRepository
    private let wordBookRepository: any WordBookRepository
    private let shuffle: ShuffleSeedController
    private let space: LanguageSpace

    private(set) var page: LexiconPage = .empty
    private(set) var errorMessage: String?
    /// 一次操作的简短反馈（收录成功、已在单词本、失败原因）。
    private(set) var notice: String?
    /// 每个词条相对“词库收藏”的状态与收藏日期，键为规范化词形。
    private(set) var collectionInfo: [String: LexiconCollectionInfo] = [:]
    /// 搜索关键词。界面通过 `@Bindable` 直接绑定写入，写入后由视图调用
    /// `keywordDidChange()` 重新加载；程序化修改请用 `updateKeyword(_:)`。
    var keyword: String = ""
    private(set) var level: VocabularyLevel?

    /// 当前请求的页码。与 `page.pageIndex` 分开保存，便于在失败时保留用户意图。
    private(set) var requestedPageIndex = 0

    /// 被遮盖的字段。遮盖是视图状态：不写数据库，也不改变词条本身。
    private(set) var maskedTermIDs: Set<UUID> = []
    private(set) var maskedGlossIDs: Set<UUID> = []

    private var noticeTask: Task<Void, Never>?

    init(
        repository: any LexiconRepository,
        wordBookRepository: any WordBookRepository,
        shuffle: ShuffleSeedController,
        space: LanguageSpace
    ) {
        self.repository = repository
        self.wordBookRepository = wordBookRepository
        self.shuffle = shuffle
        self.space = space
    }

    // MARK: - 派生状态

    /// 高亮方式必须与检索方式来自同一判定，否则界面会与实际结果不符。
    var searchMode: LexiconSearchMode {
        LexiconQuery(keyword: keyword).searchMode
    }

    var isSearching: Bool {
        !keyword.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var selectedLevelTitle: String {
        level?.title ?? "全部"
    }

    var hasAnyMask: Bool {
        !maskedTermIDs.isEmpty || !maskedGlossIDs.isEmpty
    }

    var isEmpty: Bool {
        page.isEmpty && errorMessage == nil
    }

    func isTermMasked(_ entry: LexiconEntry) -> Bool {
        maskedTermIDs.contains(entry.id)
    }

    func isGlossMasked(_ entry: LexiconEntry) -> Bool {
        maskedGlossIDs.contains(entry.id)
    }

    // MARK: - 加载

    /// 首次进入页面时调用：同时加载词条与“已收录”标记。
    ///
    /// 标记只在进入页面时读一次，打字与翻页都不会重复查询个人单词本。
    func loadInitial() {
        // 距上次洗牌超过冷却期时在这里换一批，否则沿用上次的顺序。
        _ = shuffle.seedForEntry()
        loadCollectionInfo()
        load()
    }

    /// 手动换一批：回到第一页并清除遮盖。
    func reshuffle() {
        shuffle.reshuffle()
        startNewQuery()
    }

    func load() {
        do {
            page = try repository.page(
                matching: LexiconQuery(
                    keyword: keyword,
                    level: level,
                    pageIndex: requestedPageIndex,
                    // 搜索是定向的，保持词频顺序；浏览才洗牌。
                    shuffleSeed: isSearching ? nil : shuffle.seed
                )
            )
            errorMessage = nil
        } catch {
            page = .empty
            errorMessage = (error as? LocalizedError)?.errorDescription
                ?? error.localizedDescription
        }
    }

    // MARK: - 收录

    func collectionInfo(for entry: LexiconEntry) -> LexiconCollectionInfo {
        collectionInfo[normalizedTerm(entry.term)] ?? .notInWordBook
    }

    func collectionState(for entry: LexiconEntry) -> LexiconCollectionState {
        collectionInfo(for: entry).state
    }

    /// 词条是否已在个人单词本中（含文档导入与手动新增）。
    func isInWordBook(_ entry: LexiconEntry) -> Bool {
        collectionState(for: entry) != .notInWordBook
    }

    /// 收录 / 取消收录的开关。
    ///
    /// 只收录单词与词性词义；音标、英文释义、等级、词频都不写入。
    /// 幂等、“不覆盖既有释义”与“不破坏文档导入”由仓储保证，这里只负责反馈与刷新标记。
    func toggleCollection(_ entry: LexiconEntry) {
        switch collectionState(for: entry) {
        case .notInWordBook:
            collect(entry)
        case .collected:
            uncollect(entry)
        case .managedInWordBook:
            showNotice("「\(entry.term)」来自文档导入或手动新增，请在单词本中管理。")
        }
    }

    private func collect(_ entry: LexiconEntry) {
        do {
            let outcome = try wordBookRepository.collectFromLexicon(
                term: entry.term,
                // 写入与词库列表一致的短释义：完整释义放进单词本会占七八行，
                // 而且词库随时可以查到全文，单词本只需要起提醒作用。
                meaning: LexiconGlossFormatter.browsingDisplay(from: entry.gloss).text,
                collectedAt: .now,
                in: space
            )
            markCollection(entry, state: .collected)
            switch outcome {
            case .inserted:
                showNotice("已将「\(entry.term)」加入单词本")
            case .alreadyExists:
                showNotice("「\(entry.term)」今天已收藏过")
            default:
                showNotice("已将「\(entry.term)」加入单词本")
            }
        } catch {
            showNotice(
                (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            )
        }
    }

    private func uncollect(_ entry: LexiconEntry) {
        let key = normalizedTerm(entry.term)
        do {
            let outcome = try wordBookRepository.uncollectFromLexicon(
                term: entry.term,
                in: space
            )
            switch outcome {
            case .removed:
                collectionInfo[key] = .notInWordBook
                showNotice("已取消收藏「\(entry.term)」")
            case .removedCollectionOnly:
                // 词条另有文档导入来源，仍然留在单词本中，状态不能清空。
                collectionInfo[key] = LexiconCollectionInfo(
                    state: .managedInWordBook,
                    collectedDates: []
                )
                showNotice("已移除词库收藏；「\(entry.term)」另有文档导入记录，仍在单词本中。")
            case .notCollected:
                collectionInfo[key] = .notInWordBook
                showNotice("「\(entry.term)」没有词库收藏记录。")
            case .managedInWordBook:
                collectionInfo[key] = LexiconCollectionInfo(
                    state: .managedInWordBook,
                    collectedDates: []
                )
                showNotice("「\(entry.term)」来自文档导入或手动新增，请在单词本中管理。")
            default:
                collectionInfo[key] = .notInWordBook
            }
        } catch {
            showNotice(
                (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            )
        }
    }

    private func loadCollectionInfo() {
        do {
            collectionInfo = try wordBookRepository.lexiconCollectionInfo(in: space)
        } catch {
            // 读不到个人单词本不应阻塞词库浏览：标记退化为“未收录”。
            // 真正写入时仍会给出准确结果——已存在的词会返回 alreadyExists。
            collectionInfo = [:]
        }
    }

    /// 收藏成功后立即更新本地标记，无需重新查询单词本。
    private func markCollection(_ entry: LexiconEntry, state: LexiconCollectionState) {
        let key = normalizedTerm(entry.term)
        var dates = collectionInfo[key]?.collectedDates ?? []
        if state == .collected {
            let today = VocabularyDocumentDate(date: .now)
            if !dates.contains(today) {
                dates.insert(today, at: 0)
            }
        } else {
            dates = []
        }
        collectionInfo[key] = LexiconCollectionInfo(state: state, collectedDates: dates)
    }

    private func normalizedTerm(_ term: String) -> String {
        WordNormalizer.normalizedTerm(term, in: space)
    }

    private func showNotice(_ text: String) {
        notice = text
        noticeTask?.cancel()
        noticeTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(2.5))
            guard !Task.isCancelled else { return }
            self?.notice = nil
        }
    }

    // MARK: - 查询意图

    func selectLevel(_ level: VocabularyLevel?) {
        guard self.level != level else { return }
        self.level = level
        startNewQuery()
    }

    func updateKeyword(_ keyword: String) {
        guard self.keyword != keyword else { return }
        self.keyword = keyword
        startNewQuery()
    }

    /// 绑定写入关键词之后调用：回到第一页、清除遮盖并重新查询。
    func keywordDidChange() {
        startNewQuery()
    }

    func clearKeyword() {
        updateKeyword("")
    }

    func goToPreviousPage() {
        guard page.hasPreviousPage else { return }
        requestedPageIndex = max(0, requestedPageIndex - 1)
        // 翻页后旧的遮盖状态属于上一页内容，必须清除。
        clearMasks()
        load()
    }

    func goToNextPage() {
        guard page.hasNextPage else { return }
        requestedPageIndex += 1
        clearMasks()
        load()
    }

    private func startNewQuery() {
        requestedPageIndex = 0
        clearMasks()
        load()
    }

    // MARK: - 遮盖

    func toggleTermMask(_ entry: LexiconEntry) {
        if maskedTermIDs.contains(entry.id) {
            maskedTermIDs.remove(entry.id)
        } else {
            maskedTermIDs.insert(entry.id)
        }
    }

    func toggleGlossMask(_ entry: LexiconEntry) {
        if maskedGlossIDs.contains(entry.id) {
            maskedGlossIDs.remove(entry.id)
        } else {
            maskedGlossIDs.insert(entry.id)
        }
    }

    func clearMasks() {
        maskedTermIDs.removeAll()
        maskedGlossIDs.removeAll()
    }
}

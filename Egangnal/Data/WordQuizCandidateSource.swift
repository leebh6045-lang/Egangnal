//
//  WordQuizCandidateSource.swift
//  Egangnal
//

import Foundation

@MainActor
protocol WordQuizCandidateProviding: AnyObject {
    func allImportedCandidates(in space: LanguageSpace) throws -> [WordQuizCandidate]
    func availableDates(in space: LanguageSpace) throws -> [VocabularyDocumentDate]
    func candidates(
        on date: VocabularyDocumentDate,
        in space: LanguageSpace
    ) throws -> [WordQuizCandidate]
}

@MainActor
final class WordQuizCandidateSource: WordQuizCandidateProviding {
    private let repository: any WordBookRepository

    init(repository: any WordBookRepository) {
        self.repository = repository
    }

    func allImportedCandidates(in space: LanguageSpace) throws -> [WordQuizCandidate] {
        try repository.entries(in: space)
            .filter(Self.isImported)
            .map(Self.makeCandidate)
    }

    func availableDates(in space: LanguageSpace) throws -> [VocabularyDocumentDate] {
        let importedEntries = try repository.entries(in: space).filter(Self.isImported)
        return Set(importedEntries.flatMap(\.occurrenceDates)).sorted(by: >)
    }

    func candidates(
        on date: VocabularyDocumentDate,
        in space: LanguageSpace
    ) throws -> [WordQuizCandidate] {
        // 仓储负责语言隔离；这里复核日期，避免异常快照进入测试。
        try repository.entries(on: date, in: space)
            .filter { $0.occurrenceDates.contains(date) }
            .map(Self.makeCandidate)
    }

    private static func isImported(_ entry: WordBookEntrySnapshot) -> Bool {
        !entry.occurrenceDates.isEmpty
    }

    private static func makeCandidate(_ entry: WordBookEntrySnapshot) -> WordQuizCandidate {
        WordQuizCandidate(id: entry.id, term: entry.term, meaning: entry.meaning)
    }
}

/// 等级速测的候选集。
///
/// 与单词本候选的区别：目标集是**词库当前筛选结果**，干扰项池是**整个词库**。
/// 两者都不经过 SwiftData，因此没有收藏过的词条也能被考到（ADR-003 决策 2）。
@MainActor
protocol LexiconQuizCandidateProviding: AnyObject {
    func lexiconQuizCandidates(
        in scope: LexiconQuizScope
    ) throws -> (targets: [WordQuizCandidate], distractors: [WordQuizCandidate])
}

@MainActor
final class LexiconQuizCandidateSource: LexiconQuizCandidateProviding {
    private let lexiconRepository: any LexiconRepository

    init(lexiconRepository: any LexiconRepository) {
        self.lexiconRepository = lexiconRepository
    }

    func lexiconQuizCandidates(
        in scope: LexiconQuizScope
    ) throws -> (targets: [WordQuizCandidate], distractors: [WordQuizCandidate]) {
        let targets = try lexiconRepository.entries(matching: scope.query)
        // 干扰项池用整个词库，而不是当前筛选：`四级` 范围下若干扰项也只来自四级，
        // 选项之间会过于接近；用全库才能出现"初中词混在六级题里"的自然难度。
        // 二者都读一次全库量级的数据，实测毫秒级，不需要为省一次查询引入分支。
        let pool = try lexiconRepository.entries(matching: LexiconQuery())
        return (targets.map(Self.makeCandidate), pool.map(Self.makeCandidate))
    }

    /// 词库释义是完整形态（中位 27 字、最长 196），必须先派生成短释义才能进选项按钮。
    ///
    /// 用 `browsingDisplay`（**保留词性前缀**）而不是 `shortGloss`：词性本身是词库与个人单词本
    /// 最明显的差别，考词库时选项要能看出 `vt.` / `n.` 这类信息；个人单词本里收藏的词写进去的
    /// 也是这个形态，两个池子因此文本一致。截断造成的显示冲突由引擎的显示文本闸门兜住。
    private static func makeCandidate(_ entry: LexiconEntry) -> WordQuizCandidate {
        WordQuizCandidate(
            id: entry.id,
            term: entry.term,
            meaning: LexiconGlossFormatter.browsingDisplay(from: entry.gloss).text
        )
    }
}

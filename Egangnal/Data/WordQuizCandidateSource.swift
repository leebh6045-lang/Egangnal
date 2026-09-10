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

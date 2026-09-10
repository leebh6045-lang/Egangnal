//
//  WordQuizCandidateSourceTests.swift
//  EgangnalTests
//

import Foundation
import Testing
@testable import Egangnal

struct WordQuizCandidateSourceTests {
    @Test @MainActor
    func allCandidatesExcludePureManualEntriesAndIncludeImportedManualEntries() throws {
        let firstDate = try #require(VocabularyDocumentDate(year: 2026, month: 8, day: 16))
        let secondDate = try #require(VocabularyDocumentDate(year: 2026, month: 8, day: 17))
        let pureManual = makeEntry(
            term: "manual",
            meaning: "手动",
            isManuallyCreated: true,
            dates: []
        )
        let importedManual = makeEntry(
            term: "later imported",
            meaning: "后来导入",
            isManuallyCreated: true,
            dates: [firstDate]
        )
        let imported = makeEntry(
            term: "language",
            meaning: "语言",
            dates: [firstDate, secondDate]
        )
        let japanese = makeEntry(term: "言葉", meaning: "词语", dates: [secondDate])
        let repository = WordQuizCandidateSourceRepository(
            entriesBySpace: [
                .english: [pureManual, importedManual, imported],
                .japanese: [japanese]
            ]
        )
        let source = WordQuizCandidateSource(repository: repository)

        let englishCandidates = try source.allImportedCandidates(in: .english)
        let japaneseCandidates = try source.allImportedCandidates(in: .japanese)

        #expect(englishCandidates.map(\.id) == [importedManual.id, imported.id])
        #expect(englishCandidates.map(\.term) == ["later imported", "language"])
        #expect(japaneseCandidates.map(\.id) == [japanese.id])
        #expect(repository.requestedAllSpaces == [.english, .japanese])
    }

    @Test @MainActor
    func datesAreUniqueDescendingAndIgnorePureManualEntries() throws {
        let earliest = try #require(VocabularyDocumentDate(year: 2026, month: 7, day: 1))
        let middle = try #require(VocabularyDocumentDate(year: 2026, month: 8, day: 16))
        let latest = try #require(VocabularyDocumentDate(year: 2026, month: 8, day: 17))
        let repository = WordQuizCandidateSourceRepository(
            entriesBySpace: [
                .japanese: [
                    makeEntry(term: "一", meaning: "一", dates: [middle, latest]),
                    makeEntry(term: "二", meaning: "二", dates: [earliest, middle]),
                    makeEntry(term: "三", meaning: "三", isManuallyCreated: true, dates: [])
                ]
            ]
        )
        let source = WordQuizCandidateSource(repository: repository)

        let dates = try source.availableDates(in: .japanese)

        #expect(dates == [latest, middle, earliest])
        #expect(repository.requestedAllSpaces == [.japanese])
    }

    @Test @MainActor
    func datedCandidatesForwardDateAndLanguageAndFilterDefensively() throws {
        let date = try #require(VocabularyDocumentDate(year: 2026, month: 8, day: 17))
        let matching = makeEntry(term: "study", meaning: "学习", dates: [date])
        let unexpectedManual = makeEntry(
            term: "manual",
            meaning: "手动",
            isManuallyCreated: true,
            dates: []
        )
        let otherDate = try #require(VocabularyDocumentDate(year: 2026, month: 8, day: 16))
        let unexpectedOtherDate = makeEntry(
            term: "yesterday",
            meaning: "昨天",
            dates: [otherDate]
        )
        let repository = WordQuizCandidateSourceRepository(
            datedEntries: [
                .init(space: .english, date: date): [
                    matching,
                    unexpectedManual,
                    unexpectedOtherDate
                ]
            ]
        )
        let source = WordQuizCandidateSource(repository: repository)

        let candidates = try source.candidates(on: date, in: .english)

        #expect(candidates == [
            WordQuizCandidate(id: matching.id, term: matching.term, meaning: matching.meaning)
        ])
        #expect(repository.requestedDatedEntries == [.init(space: .english, date: date)])
    }

    @Test @MainActor
    func repositoryErrorsArePropagatedWithoutTranslation() throws {
        let date = try #require(VocabularyDocumentDate(year: 2026, month: 8, day: 17))
        let repository = WordQuizCandidateSourceRepository(error: .expectedFailure)
        let source = WordQuizCandidateSource(repository: repository)

        #expect(throws: WordQuizCandidateSourceTestError.expectedFailure) {
            _ = try source.allImportedCandidates(in: .english)
        }
        #expect(throws: WordQuizCandidateSourceTestError.expectedFailure) {
            _ = try source.availableDates(in: .english)
        }
        #expect(throws: WordQuizCandidateSourceTestError.expectedFailure) {
            _ = try source.candidates(on: date, in: .english)
        }
    }

    private func makeEntry(
        id: UUID = UUID(),
        term: String,
        meaning: String,
        isManuallyCreated: Bool = false,
        dates: [VocabularyDocumentDate]
    ) -> WordBookEntrySnapshot {
        WordBookEntrySnapshot(
            id: id,
            term: term,
            meaning: meaning,
            isManuallyCreated: isManuallyCreated,
            occurrenceDates: dates
        )
    }
}

private enum WordQuizCandidateSourceTestError: Error, Equatable {
    case expectedFailure
}

private struct WordQuizCandidateSourceRequest: Hashable {
    let space: LanguageSpace
    let date: VocabularyDocumentDate
}

@MainActor
private final class WordQuizCandidateSourceRepository: WordBookRepository {
    var entriesBySpace: [LanguageSpace: [WordBookEntrySnapshot]]
    var datedEntries: [WordQuizCandidateSourceRequest: [WordBookEntrySnapshot]]
    var requestedAllSpaces: [LanguageSpace] = []
    var requestedDatedEntries: [WordQuizCandidateSourceRequest] = []
    let error: WordQuizCandidateSourceTestError?

    init(
        entriesBySpace: [LanguageSpace: [WordBookEntrySnapshot]] = [:],
        datedEntries: [WordQuizCandidateSourceRequest: [WordBookEntrySnapshot]] = [:],
        error: WordQuizCandidateSourceTestError? = nil
    ) {
        self.entriesBySpace = entriesBySpace
        self.datedEntries = datedEntries
        self.error = error
    }

    func importDocument(
        _ document: ParsedWordDocument,
        into space: LanguageSpace,
        sourceFilename: String,
        importedAt: Date
    ) throws -> WordBookImportResult {
        throw WordQuizCandidateSourceTestError.expectedFailure
    }

    func entries(in space: LanguageSpace) throws -> [WordBookEntrySnapshot] {
        if let error { throw error }
        requestedAllSpaces.append(space)
        return entriesBySpace[space] ?? []
    }

    func entries(
        on date: VocabularyDocumentDate,
        in space: LanguageSpace
    ) throws -> [WordBookEntrySnapshot] {
        if let error { throw error }
        let request = WordQuizCandidateSourceRequest(space: space, date: date)
        requestedDatedEntries.append(request)
        return datedEntries[request] ?? []
    }

    func addManualEntry(term: String, meaning: String, in space: LanguageSpace) throws -> UUID {
        throw WordQuizCandidateSourceTestError.expectedFailure
    }

    func updateEntry(id: UUID, term: String, meaning: String, in space: LanguageSpace) throws {
        throw WordQuizCandidateSourceTestError.expectedFailure
    }

    func deleteEntry(id: UUID, in space: LanguageSpace) throws {
        throw WordQuizCandidateSourceTestError.expectedFailure
    }
}

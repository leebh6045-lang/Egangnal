//
//  WordQuizStoreTests.swift
//  EgangnalTests
//

import Foundation
import Testing
@testable import Egangnal

struct WordQuizStoreTests {
    @Test
    func feedbackTimingUsesConfirmedCorrectAndIncorrectDelays() {
        #expect(
            WordQuizFeedbackTiming.delay(isCorrect: true)
                == .milliseconds(1_500)
        )
        #expect(
            WordQuizFeedbackTiming.delay(isCorrect: false)
                == .seconds(3)
        )
        #expect(
            WordQuizFeedbackTiming.successRingDuration
                == .milliseconds(400)
        )
    }

    @Test @MainActor
    func storeUsesLatestDateAndFreezesSelectedDateTargets() throws {
        let older = try #require(VocabularyDocumentDate(year: 2026, month: 8, day: 16))
        let newer = try #require(VocabularyDocumentDate(year: 2026, month: 8, day: 17))
        let all = makeCandidates(count: 5)
        let source = TestWordQuizCandidateSource(
            all: all,
            dates: [newer, older],
            candidatesByDate: [newer: Array(all.prefix(2)), older: Array(all.suffix(3))]
        )
        let store = WordQuizStore(space: .english, candidateSource: source)

        store.load()
        #expect(store.availableDates == [newer, older])
        #expect(store.selectedDate == newer)

        store.selectRangeMode(.date)
        store.start()

        #expect(store.session?.configuration.scope == .date(newer))
        #expect(Set(store.session?.selectedCandidates.map(\.id) ?? []) == Set(all.prefix(2).map(\.id)))
        #expect(store.settingsAreLocked)
    }

    @Test @MainActor
    func storeBlocksStrictFourChoiceWhenMeaningsAreInsufficient() {
        let candidates = [
            candidate(index: 0, meaning: "一"),
            candidate(index: 1, meaning: "一"),
            candidate(index: 2, meaning: "二"),
            candidate(index: 3, meaning: "三")
        ]
        let store = WordQuizStore(
            space: .english,
            candidateSource: TestWordQuizCandidateSource(all: candidates)
        )

        store.load()

        #expect(!store.canStart)
        #expect(store.startValidationMessage == "至少需要 4 个具有不同词义的已导入单词。")
    }

    @Test @MainActor
    func storeLocksSettingsAndCompletesAnAllCorrectRound() throws {
        let candidates = makeCandidates(count: 4)
        let store = WordQuizStore(
            space: .english,
            candidateSource: TestWordQuizCandidateSource(all: candidates)
        )
        store.load()
        store.start()

        #expect(store.settingsAreLocked)
        #expect(!store.needsExitConfirmation)

        while let question = store.currentQuestion {
            let correctOption = try #require(
                question.choiceOptions.first { $0.id == question.candidateID }
            )
            store.submitChoice(optionID: correctOption.id)
            #expect(store.currentResponse?.isCorrect == true)
            #expect(store.needsExitConfirmation)
            store.advance()
        }

        #expect(store.isShowingResult)
        #expect(store.currentScore == 4)
        #expect(!store.hasIncorrectQuestions)

        store.returnToIdle()
        #expect(store.round == nil)
        #expect(!store.needsExitConfirmation)
        #expect(store.canStart)
    }

    @Test @MainActor
    func storeReportsOnlyAcceptedChoiceSubmissions() throws {
        let store = WordQuizStore(
            space: .english,
            candidateSource: TestWordQuizCandidateSource(all: makeCandidates(count: 4))
        )
        store.load()
        store.start()

        let question = try #require(store.currentQuestion)
        let correctOption = try #require(
            question.choiceOptions.first { $0.id == question.candidateID }
        )

        #expect(!store.submitChoice(optionID: UUID()))
        #expect(store.currentResponse == nil)
        #expect(store.submitChoice(optionID: correctOption.id))
        #expect(!store.submitChoice(optionID: correctOption.id))
    }

    @Test @MainActor
    func storeRetriesOnlyTheConcreteIncorrectQuestion() throws {
        let store = WordQuizStore(
            space: .english,
            candidateSource: TestWordQuizCandidateSource(all: makeCandidates(count: 4))
        )
        store.load()
        store.start()

        var shouldMiss = true
        while let question = store.currentQuestion {
            let option = try #require(
                question.choiceOptions.first {
                    ($0.id == question.candidateID) != shouldMiss
                }
            )
            store.submitChoice(optionID: option.id)
            shouldMiss = false
            store.advance()
        }

        #expect(store.hasIncorrectQuestions)
        store.retryIncorrect()
        #expect(store.currentRoundQuestionCount == 1)

        let retryQuestion = try #require(store.currentQuestion)
        let correctOption = try #require(
            retryQuestion.choiceOptions.first { $0.id == retryQuestion.candidateID }
        )
        store.submitChoice(optionID: correctOption.id)
        store.advance()

        #expect(store.isShowingResult)
        #expect(store.currentScore == 1)
        #expect(!store.hasIncorrectQuestions)
    }

    private func makeCandidates(count: Int) -> [WordQuizCandidate] {
        (0..<count).map { candidate(index: $0, meaning: "词义-\($0)") }
    }

    private func candidate(index: Int, meaning: String) -> WordQuizCandidate {
        WordQuizCandidate(
            id: UUID(uuidString: String(
                format: "00000000-0000-0000-0001-%012d",
                index + 1
            ))!,
            term: "word-\(index)",
            meaning: meaning
        )
    }
}

@MainActor
private final class TestWordQuizCandidateSource: WordQuizCandidateProviding {
    let all: [WordQuizCandidate]
    let dates: [VocabularyDocumentDate]
    let candidatesByDate: [VocabularyDocumentDate: [WordQuizCandidate]]

    init(
        all: [WordQuizCandidate],
        dates: [VocabularyDocumentDate] = [],
        candidatesByDate: [VocabularyDocumentDate: [WordQuizCandidate]] = [:]
    ) {
        self.all = all
        self.dates = dates
        self.candidatesByDate = candidatesByDate
    }

    func allImportedCandidates(in space: LanguageSpace) throws -> [WordQuizCandidate] {
        all
    }

    func availableDates(in space: LanguageSpace) throws -> [VocabularyDocumentDate] {
        dates
    }

    func candidates(
        on date: VocabularyDocumentDate,
        in space: LanguageSpace
    ) throws -> [WordQuizCandidate] {
        candidatesByDate[date] ?? []
    }
}

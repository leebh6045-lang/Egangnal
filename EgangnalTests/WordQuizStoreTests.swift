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
        #expect(store.startValidationMessage == "至少需要 4 个具有不同词义的单词。")
    }

    // MARK: - 词库范围（等级速测）

    @Test @MainActor
    func lexiconRangeStartsAQuizFromTheSelectedLevel() throws {
        let all = makeCandidates(count: 6)
        let store = WordQuizStore(
            space: .english,
            candidateSource: TestWordQuizCandidateSource(all: []),
            lexiconCandidateSource: TestLexiconQuizCandidateSource(
                targets: Array(all.prefix(3)),
                distractors: all
            )
        )

        // 个人单词本为空，词库范围必须仍然可考。
        store.load()
        store.loadLexiconCandidatesIfNeeded()
        store.selectRangeMode(.lexicon)
        store.selectLexiconLevel(.cet4)

        #expect(store.isLexiconScoped)
        #expect(store.scopeTitle == "词库 · 四级")
        #expect(store.canStart)

        store.start()

        #expect(store.session?.configuration.scope == .lexicon(.level(.cet4)))
        #expect(Set(store.session?.selectedCandidates.map(\.id) ?? []) == Set(all.prefix(3).map(\.id)))
    }

    /// 默认考词库全部等级；等级选择只影响目标集，不影响可用性判据。
    @Test @MainActor
    func lexiconRangeDefaultsToAllLevels() {
        let candidates = makeCandidates(count: 4)
        let source = TestLexiconQuizCandidateSource(
            targets: candidates,
            distractors: candidates
        )
        let store = WordQuizStore(
            space: .english,
            candidateSource: TestWordQuizCandidateSource(all: []),
            lexiconCandidateSource: source
        )
        store.load()
        store.selectRangeMode(.lexicon)

        #expect(store.lexiconLevel == nil)
        #expect(store.scopeTitle == "词库 · 全部")
        #expect(store.canStart)

        store.start()
        #expect(store.session?.configuration.scope == .lexicon(.all))
        #expect(source.requestedScopes == [.all])
    }

    /// 两个范围各自取池：切到词库范围之后，单词本范围的候选与判据都不能变。
    @Test @MainActor
    func lexiconRangeDoesNotPolluteTheWordBookRange() {
        let wordBookCandidates = makeCandidates(count: 4)
        let lexiconTargets = [
            candidate(index: 90, meaning: "词库一"),
            candidate(index: 91, meaning: "词库二")
        ]
        let store = WordQuizStore(
            space: .english,
            candidateSource: TestWordQuizCandidateSource(all: wordBookCandidates),
            lexiconCandidateSource: TestLexiconQuizCandidateSource(
                targets: lexiconTargets,
                distractors: lexiconTargets
            )
        )
        store.load()

        #expect(!store.isLexiconScoped)
        #expect(store.scopeTitle == "单词本 · 默认")
        #expect(store.canStart)

        store.selectRangeMode(.lexicon)
        // 目标集只有 2 条不同词义，判据必须按词库池算，不能退回单词本那 4 条。
        #expect(!store.canStart)
        #expect(store.startValidationMessage == "当前筛选范围的不同词义不足 4 个，无法组成四选一。")

        store.selectRangeMode(.allImported)

        #expect(!store.isLexiconScoped)
        #expect(store.scopeTitle == "单词本 · 默认")
        #expect(store.canStart)
        // 切回单词本范围后再读取一次（界面进入页面时会调用），词库池不得被复用。
        store.load()
        #expect(store.currentTargetCandidates.map(\.id) == wordBookCandidates.map(\.id))
    }

    @Test @MainActor
    func emptyLexiconRangeReportsAScopeSpecificMessage() {
        let store = WordQuizStore(
            space: .english,
            candidateSource: TestWordQuizCandidateSource(all: []),
            lexiconCandidateSource: TestLexiconQuizCandidateSource(targets: [], distractors: [])
        )
        store.load()
        store.selectRangeMode(.lexicon)

        #expect(!store.canStart)
        // 不能提示"请先导入单词"——词库范围与导入无关。
        #expect(store.startValidationMessage == "当前筛选范围没有可以测试的词条。")
    }

    @Test @MainActor
    func failedLexiconLoadKeepsTheQuizBlockedWithTheRepositoryMessage() {
        let store = WordQuizStore(
            space: .english,
            candidateSource: TestWordQuizCandidateSource(all: makeCandidates(count: 4)),
            lexiconCandidateSource: FailingLexiconQuizSource()
        )
        store.load()
        store.selectRangeMode(.lexicon)

        #expect(!store.canStart)
        // 保留仓储的失败原因，不能被"范围没有词条"盖掉。
        #expect(store.startValidationMessage?.contains("词库数据缺失") == true)
    }

    /// 答题进行中不允许换范围或换等级。
    @Test @MainActor
    func lexiconLevelIsLockedWhileAQuizIsRunning() {
        let candidates = makeCandidates(count: 4)
        let store = WordQuizStore(
            space: .english,
            candidateSource: TestWordQuizCandidateSource(all: []),
            lexiconCandidateSource: TestLexiconQuizCandidateSource(
                targets: candidates,
                distractors: candidates
            )
        )
        store.load()
        store.selectRangeMode(.lexicon)
        store.start()

        store.selectLexiconLevel(.cet6)
        store.selectRangeMode(.allImported)

        #expect(store.lexiconLevel == nil)
        #expect(store.isLexiconScoped)
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

@MainActor
private final class TestLexiconQuizCandidateSource: LexiconQuizCandidateProviding {
    let targets: [WordQuizCandidate]
    let distractors: [WordQuizCandidate]
    private(set) var requestedScopes: [LexiconQuizScope] = []

    init(targets: [WordQuizCandidate], distractors: [WordQuizCandidate]) {
        self.targets = targets
        self.distractors = distractors
    }

    func lexiconQuizCandidates(
        in scope: LexiconQuizScope
    ) throws -> (targets: [WordQuizCandidate], distractors: [WordQuizCandidate]) {
        requestedScopes.append(scope)
        return (targets, distractors)
    }
}

@MainActor
private final class FailingLexiconQuizSource: LexiconQuizCandidateProviding {
    func lexiconQuizCandidates(
        in scope: LexiconQuizScope
    ) throws -> (targets: [WordQuizCandidate], distractors: [WordQuizCandidate]) {
        throw LexiconRepositoryError.resourceMissing
    }
}

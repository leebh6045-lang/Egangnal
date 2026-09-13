//
//  WordQuizEngineTests.swift
//  EgangnalTests
//

import Foundation
import Testing
@testable import Egangnal

struct WordQuizEngineTests {
    @Test(arguments: [1, 19, 20, 21])
    func samplingHandlesRangeBoundaries(candidateCount: Int) throws {
        let allCandidates = makeCandidates(count: 24)
        var randomGenerator = SeededWordQuizGenerator(seed: UInt64(candidateCount))

        let session = try WordQuizEngine.makeSession(
            configuration: configuration(difficulty: .simple),
            targetCandidates: Array(allCandidates.prefix(candidateCount)),
            distractorCandidates: allCandidates,
            using: &randomGenerator
        )

        #expect(session.selectedCandidates.count == min(candidateCount, 20))
        #expect(session.questions.count == min(candidateCount, 20))
    }

    @Test func emptyRangeCannotStartASession() {
        var randomGenerator = SeededWordQuizGenerator(seed: 1)

        #expect(throws: WordQuizEngineError.noCandidates) {
            try WordQuizEngine.makeSession(
                configuration: configuration(difficulty: .simple),
                targetCandidates: [],
                distractorCandidates: makeCandidates(count: 4),
                using: &randomGenerator
            )
        }
    }

    @Test func simpleModeSamplesTwentyUniqueWordsAndBuildsFourChoices() throws {
        let candidates = makeCandidates(count: 25)
        var randomGenerator = SeededWordQuizGenerator(seed: 17)

        let session = try WordQuizEngine.makeSession(
            configuration: configuration(difficulty: .simple),
            targetCandidates: candidates,
            distractorCandidates: candidates,
            using: &randomGenerator
        )

        #expect(session.selectedCandidates.count == 20)
        #expect(Set(session.selectedCandidates.map(\.id)).count == 20)
        #expect(session.questions.count == 20)
        #expect(session.questions.allSatisfy { $0.kind == .meaningChoice })

        for question in session.questions {
            #expect(question.choiceOptions.count == 4)
            #expect(Set(question.choiceOptions.map(\.meaning)).count == 4)
            #expect(question.choiceOptions.count { $0.id == question.candidateID } == 1)
        }
    }

    @Test func deepModeBuildsChoicePhaseBeforeIndependentSpellingPhase() throws {
        let candidates = makeCandidates(count: 6)
        var randomGenerator = SeededWordQuizGenerator(seed: 29)

        let session = try WordQuizEngine.makeSession(
            configuration: configuration(difficulty: .deep),
            targetCandidates: candidates,
            distractorCandidates: candidates,
            using: &randomGenerator
        )

        #expect(session.questions.count == 12)
        #expect(session.questions.prefix(6).allSatisfy { $0.kind == .meaningChoice })
        #expect(session.questions.suffix(6).allSatisfy { $0.kind == .spelling })
        #expect(Set(session.questions.prefix(6).map(\.candidateID)) == Set(candidates.map(\.id)))
        #expect(Set(session.questions.suffix(6).map(\.candidateID)) == Set(candidates.map(\.id)))
    }

    @Test func sameSeedProducesAnIdenticalFrozenSession() throws {
        let candidates = makeCandidates(count: 24)
        let config = configuration(difficulty: .deep)
        var firstGenerator = SeededWordQuizGenerator(seed: 42)
        var secondGenerator = SeededWordQuizGenerator(seed: 42)

        let first = try WordQuizEngine.makeSession(
            configuration: config,
            targetCandidates: candidates,
            distractorCandidates: candidates,
            using: &firstGenerator
        )
        let second = try WordQuizEngine.makeSession(
            configuration: config,
            targetCandidates: candidates,
            distractorCandidates: candidates,
            using: &secondGenerator
        )

        #expect(first == second)
    }

    @Test func strictChoiceModeRejectsFewerThanFourDistinctMeanings() {
        let candidates = [
            candidate(index: 1, term: "one", meaning: "一"),
            candidate(index: 2, term: "uno", meaning: "一"),
            candidate(index: 3, term: "two", meaning: "二"),
            candidate(index: 4, term: "three", meaning: "三")
        ]
        var randomGenerator = SeededWordQuizGenerator(seed: 3)

        #expect(throws: WordQuizEngineError.insufficientDistinctMeanings(
            required: 4,
            available: 3
        )) {
            try WordQuizEngine.makeSession(
                configuration: configuration(difficulty: .simple),
                targetCandidates: candidates,
                distractorCandidates: candidates,
                using: &randomGenerator
            )
        }
    }

    @Test func spellingUsesEnglishAndJapaneseNormalizationRules() throws {
        let englishCandidates = [
            candidate(index: 1, term: "Language", meaning: "语言"),
            candidate(index: 2, term: "study", meaning: "学习"),
            candidate(index: 3, term: "book", meaning: "书"),
            candidate(index: 4, term: "time", meaning: "时间")
        ]
        let japaneseCandidates = [
            candidate(index: 11, term: "ことば", meaning: "语言"),
            candidate(index: 12, term: "勉強", meaning: "学习"),
            candidate(index: 13, term: "本", meaning: "书"),
            candidate(index: 14, term: "時間", meaning: "时间")
        ]
        var englishGenerator = SeededWordQuizGenerator(seed: 7)
        var japaneseGenerator = SeededWordQuizGenerator(seed: 7)
        let englishSession = try WordQuizEngine.makeSession(
            configuration: configuration(language: .english, difficulty: .deep),
            targetCandidates: englishCandidates,
            distractorCandidates: englishCandidates,
            using: &englishGenerator
        )
        let japaneseSession = try WordQuizEngine.makeSession(
            configuration: configuration(language: .japanese, difficulty: .deep),
            targetCandidates: japaneseCandidates,
            distractorCandidates: japaneseCandidates,
            using: &japaneseGenerator
        )
        let englishQuestion = try #require(
            englishSession.questions.first {
                $0.candidateID == englishCandidates[0].id && $0.kind == .spelling
            }
        )
        let japaneseQuestion = try #require(
            japaneseSession.questions.first {
                $0.candidateID == japaneseCandidates[0].id && $0.kind == .spelling
            }
        )

        #expect(try WordQuizEngine.evaluate(
            .spelling("  lAnGuAgE  "),
            for: englishQuestion,
            language: .english
        ).isCorrect)
        #expect(try WordQuizEngine.evaluate(
            .spelling("  ことば  "),
            for: japaneseQuestion,
            language: .japanese
        ).isCorrect)
        #expect(try !WordQuizEngine.evaluate(
            .spelling("コトバ"),
            for: japaneseQuestion,
            language: .japanese
        ).isCorrect)
        #expect(throws: WordQuizEngineError.emptySpellingAnswer) {
            try WordQuizEngine.evaluate(
                .spelling("   "),
                for: japaneseQuestion,
                language: .japanese
            )
        }
    }

    @Test func equalMeaningsAcceptEveryMatchingTermForSpelling() throws {
        let candidates = [
            candidate(index: 1, term: "language", meaning: "语言"),
            candidate(index: 2, term: "tongue", meaning: "语言"),
            candidate(index: 3, term: "study", meaning: "学习"),
            candidate(index: 4, term: "book", meaning: "书"),
            candidate(index: 5, term: "time", meaning: "时间")
        ]
        var randomGenerator = SeededWordQuizGenerator(seed: 11)
        let session = try WordQuizEngine.makeSession(
            configuration: configuration(difficulty: .deep),
            targetCandidates: candidates,
            distractorCandidates: candidates,
            using: &randomGenerator
        )
        let languageQuestion = try #require(
            session.questions.first {
                $0.candidateID == candidates[0].id && $0.kind == .spelling
            }
        )

        #expect(Set(languageQuestion.acceptedSpellings) == ["language", "tongue"])
        #expect(try WordQuizEngine.evaluate(
            .spelling("Tongue"),
            for: languageQuestion,
            language: .english
        ).isCorrect)
    }

    /// 真实词库里确实存在"完整释义不同、显示文本相同"的词对，最典型的是英美拼写变体
    /// （`aeroplane` 与 `airplane` 的释义都是 `n. 飞机\n[机] 飞机`）与近义词
    /// （`absolutely` 与 `altogether` 都显示成 `adv. 完全地…`）。
    /// 旧逻辑按完整释义去重，会把这类词对同时选进同一题的选项里。
    ///
    /// 用词库里真实存在的释义文本，避免测试用编造数据"自证"。
    @Test func nearSynonymDistractorsNeverShareTheSameDisplayText() throws {
        let candidates = [
            candidate(index: 1, term: "aeroplane", meaning: "n. 飞机\n[机] 飞机"),
            candidate(index: 2, term: "airplane", meaning: "n. 飞机\n[机] 飞机"),
            candidate(index: 3, term: "abandon", meaning: "vt. 放弃, 抛弃, 遗弃"),
            candidate(index: 4, term: "language", meaning: "n. 语言, 语言文字"),
            candidate(index: 5, term: "study", meaning: "vt. 学习, 研究"),
            candidate(index: 6, term: "book", meaning: "n. 书, 书籍")
        ]
        // 同一场景换多个种子，避免只在一个随机顺序下侥幸成立。
        for seed in UInt64(1)...20 {
            var randomGenerator = SeededWordQuizGenerator(seed: seed)
            let session = try WordQuizEngine.makeSession(
                configuration: configuration(difficulty: .simple),
                targetCandidates: candidates,
                distractorCandidates: candidates,
                using: &randomGenerator
            )

            let termByID = Dictionary(
                uniqueKeysWithValues: candidates.map { ($0.id, $0.term) }
            )
            for question in session.questions {
                let displayTexts = question.choiceOptions.map {
                    WordQuizEngine.displayText(of: $0.meaning)
                }
                // 两条断言各有分工：先确认选项没被悄悄减少，再确认没有两条看起来一样。
                #expect(displayTexts.count == 4)
                #expect(Set(displayTexts).count == 4)
                #expect(question.choiceOptions.contains { $0.id == question.candidateID })

                // 显示文本相同的词对不能同时出现在一道题里。
                let optionTerms = Set(question.choiceOptions.compactMap { termByID[$0.id] })
                #expect(!(optionTerms.contains("aeroplane") && optionTerms.contains("airplane")))
            }
        }
    }

    /// 显示文本撞车到凑不齐干扰项时，必须明确失败，而不是悄悄给出一道三个选项的题。
    ///
    /// 构造要点：四条释义**互不重复**，所以外层"候选池里至少有四个不同词义"的校验会通过，
    /// 真正被触发的是组卷时的显示文本闸门。`absolutely` 与 `altogether` 用词库真实释义，
    /// 两者都会被压成 `adv. 完全地…`；`study` 与 `book` 与目标词的文本撞车，因此也当不了干扰项。
    @Test func displayTextCollisionsThatLeaveTooFewOptionsFailExplicitly() {
        let candidates = [
            candidate(index: 1, term: "study", meaning: "vt. 学习, 研究"),
            candidate(index: 2, term: "book", meaning: "vt. 学习, 研究"),
            candidate(index: 3, term: "absolutely", meaning: "adv. 完全地, 绝对地, 确确实实地"),
            candidate(index: 4, term: "altogether", meaning: "adv. 完全地, 总而言之")
        ]
        var randomGenerator = SeededWordQuizGenerator(seed: 9)

        // 目标词必然是 `absolutely` 或 `altogether`：另外两条释义重复，被已有的去重挡在抽样之外。
        #expect(throws: WordQuizEngineError.insufficientDistinctMeanings(
            required: 4,
            available: 3
        )) {
            try WordQuizEngine.makeSession(
                configuration: configuration(difficulty: .simple),
                targetCandidates: candidates,
                distractorCandidates: candidates,
                using: &randomGenerator
            )
        }
    }

    @Test func displayTextCollapsesWhitespaceWithoutRewritingTheText() {
        #expect(WordQuizEngine.displayText(of: "vt.  放弃,  抛弃") == "vt. 放弃, 抛弃")
        #expect(WordQuizEngine.displayText(of: "  n. 发现, 察觉  ") == "n. 发现, 察觉")
        #expect(WordQuizEngine.displayText(of: "完全地") == "完全地")
        #expect(WordQuizEngine.displayText(of: "") == "")
    }

    @Test func retryRoundsTrackConcreteQuestionsAndConverge() throws {
        let candidates = makeCandidates(count: 4)
        var randomGenerator = SeededWordQuizGenerator(seed: 23)
        let session = try WordQuizEngine.makeSession(
            configuration: configuration(difficulty: .deep),
            targetCandidates: candidates,
            distractorCandidates: candidates,
            using: &randomGenerator
        )
        let missedChoiceID = WordQuizQuestionID(
            candidateID: candidates[0].id,
            kind: .meaningChoice
        )
        var firstRound = session.makeInitialRound()

        while let question = firstRound.currentQuestion {
            let shouldMiss = question.id == missedChoiceID
            _ = try firstRound.submit(answer(for: question, correct: !shouldMiss))
            try firstRound.advance()
        }

        #expect(firstRound.isComplete)
        #expect(firstRound.score == firstRound.questions.count - 1)
        #expect(firstRound.incorrectQuestions.map(\.id) == [missedChoiceID])

        var retry = try #require(
            WordQuizEngine.makeRetryRound(
                from: firstRound,
                using: &randomGenerator
            )
        )
        #expect(retry.questions.map(\.id) == [missedChoiceID])
        let retryQuestion = try #require(retry.currentQuestion)
        _ = try retry.submit(answer(for: retryQuestion, correct: false))
        try retry.advance()

        var secondRetry = try #require(
            WordQuizEngine.makeRetryRound(
                from: retry,
                using: &randomGenerator
            )
        )
        let secondQuestion = try #require(secondRetry.currentQuestion)
        _ = try secondRetry.submit(answer(for: secondQuestion, correct: true))
        try secondRetry.advance()

        #expect(try WordQuizEngine.makeRetryRound(
            from: secondRetry,
            using: &randomGenerator
        ) == nil)
    }

    @Test func roundRequiresSingleSubmissionBeforeAdvancing() throws {
        let candidates = makeCandidates(count: 4)
        var randomGenerator = SeededWordQuizGenerator(seed: 5)
        let session = try WordQuizEngine.makeSession(
            configuration: configuration(difficulty: .simple),
            targetCandidates: candidates,
            distractorCandidates: candidates,
            using: &randomGenerator
        )
        var round = session.makeInitialRound()
        let question = try #require(round.currentQuestion)

        #expect(throws: WordQuizEngineError.currentQuestionUnanswered) {
            try round.advance()
        }
        _ = try round.submit(answer(for: question, correct: true))
        #expect(throws: WordQuizEngineError.answerAlreadySubmitted) {
            try round.submit(answer(for: question, correct: true))
        }
    }

    private func configuration(
        language: LanguageSpace = .english,
        difficulty: WordQuizDifficulty
    ) -> WordQuizConfiguration {
        WordQuizConfiguration(
            language: language,
            scope: .allImported,
            difficulty: difficulty
        )
    }

    private func makeCandidates(count: Int) -> [WordQuizCandidate] {
        (0..<count).map {
            candidate(index: $0, term: "word-\($0)", meaning: "词义-\($0)")
        }
    }

    private func candidate(
        index: Int,
        term: String,
        meaning: String
    ) -> WordQuizCandidate {
        WordQuizCandidate(
            id: UUID(uuidString: String(
                format: "00000000-0000-0000-0000-%012d",
                index + 1
            ))!,
            term: term,
            meaning: meaning
        )
    }

    private func answer(
        for question: WordQuizQuestion,
        correct: Bool
    ) -> WordQuizAnswer {
        switch question.kind {
        case .meaningChoice:
            let option = question.choiceOptions.first {
                ($0.id == question.candidateID) == correct
            }!
            return .choice(optionID: option.id)
        case .spelling:
            return .spelling(correct ? question.acceptedSpellings[0] : "必然错误")
        }
    }
}

private struct SeededWordQuizGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
        return state
    }
}

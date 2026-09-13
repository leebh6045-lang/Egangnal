//
//  WordQuizEngine.swift
//  Egangnal
//

import Foundation

enum WordQuizEngineError: Error, Equatable, LocalizedError {
    case noCandidates
    case invalidCandidate(UUID)
    case insufficientDistinctMeanings(required: Int, available: Int)
    case answerKindMismatch
    case invalidChoice
    case emptySpellingAnswer
    case answerAlreadySubmitted
    case currentQuestionUnanswered
    case roundNotComplete
    case roundAlreadyComplete

    var errorDescription: String? {
        switch self {
        case .noCandidates:
            "当前范围没有可以测试的单词。"
        case .invalidCandidate:
            "候选单词或词义不能为空。"
        case let .insufficientDistinctMeanings(required, available):
            "至少需要 \(required) 个不同词义，当前只有 \(available) 个。"
        case .answerKindMismatch:
            "提交的答案类型与当前题型不一致。"
        case .invalidChoice:
            "所选词义不属于当前题目。"
        case .emptySpellingAnswer:
            "请输入单词后再提交。"
        case .answerAlreadySubmitted:
            "当前题目已经提交过答案。"
        case .currentQuestionUnanswered:
            "提交当前题目后才能继续。"
        case .roundNotComplete:
            "完成当前轮次后才能再战错题。"
        case .roundAlreadyComplete:
            "当前轮次已经结束。"
        }
    }
}

enum WordQuizEngine {
    static let maximumCandidateCount = 20
    static let choiceOptionCount = 4

    static func makeSession(
        configuration: WordQuizConfiguration,
        targetCandidates: [WordQuizCandidate],
        distractorCandidates: [WordQuizCandidate]
    ) throws -> WordQuizSession {
        var randomGenerator = SystemRandomNumberGenerator()
        return try makeSession(
            configuration: configuration,
            targetCandidates: targetCandidates,
            distractorCandidates: distractorCandidates,
            using: &randomGenerator
        )
    }

    static func makeSession<R: RandomNumberGenerator>(
        configuration: WordQuizConfiguration,
        targetCandidates: [WordQuizCandidate],
        distractorCandidates: [WordQuizCandidate],
        using randomGenerator: inout R
    ) throws -> WordQuizSession {
        var targets = try preparedCandidates(targetCandidates)
        guard !targets.isEmpty else {
            throw WordQuizEngineError.noCandidates
        }

        // 先随机排列再截取，保证抽样无放回且最多二十个。
        targets.shuffle(using: &randomGenerator)
        let selected = Array(targets.prefix(maximumCandidateCount))
        let allCandidates = try mergedCandidates(
            selected,
            with: distractorCandidates
        )
        let availableMeaningCount = Set(
            allCandidates.map { normalizedMeaning($0.meaning) }
        ).count
        guard availableMeaningCount >= choiceOptionCount else {
            throw WordQuizEngineError.insufficientDistinctMeanings(
                required: choiceOptionCount,
                available: availableMeaningCount
            )
        }

        var choiceTargets = selected
        choiceTargets.shuffle(using: &randomGenerator)
        var questions = try choiceTargets.map {
            try makeMeaningQuestion(
                for: $0,
                selectedCandidates: selected,
                allCandidates: allCandidates,
                using: &randomGenerator
            )
        }

        if configuration.difficulty == .deep {
            var spellingTargets = selected
            spellingTargets.shuffle(using: &randomGenerator)
            questions.append(
                contentsOf: spellingTargets.map {
                    makeSpellingQuestion(
                        for: $0,
                        allCandidates: allCandidates,
                        language: configuration.language
                    )
                }
            )
        }

        return WordQuizSession(
            configuration: configuration,
            selectedCandidates: selected,
            questions: questions
        )
    }

    static func evaluate(
        _ answer: WordQuizAnswer,
        for question: WordQuizQuestion,
        language: LanguageSpace
    ) throws -> WordQuizAnswerResult {
        let isCorrect: Bool
        switch (question.kind, answer) {
        case let (.meaningChoice, .choice(optionID)):
            guard question.choiceOptions.contains(where: { $0.id == optionID }) else {
                throw WordQuizEngineError.invalidChoice
            }
            isCorrect = optionID == question.candidateID

        case let (.spelling, .spelling(submittedTerm)):
            let normalizedAnswer = WordNormalizer.normalizedTerm(
                submittedTerm,
                in: language
            )
            guard !normalizedAnswer.isEmpty else {
                throw WordQuizEngineError.emptySpellingAnswer
            }
            let acceptableAnswers = Set(
                question.acceptedSpellings.map {
                    WordNormalizer.normalizedTerm($0, in: language)
                }
            )
            isCorrect = acceptableAnswers.contains(normalizedAnswer)

        case (.meaningChoice, .spelling), (.spelling, .choice):
            throw WordQuizEngineError.answerKindMismatch
        }

        return WordQuizAnswerResult(
            questionID: question.id,
            answer: answer,
            isCorrect: isCorrect,
            correctAnswer: question.correctAnswer
        )
    }

    static func makeRetryRound(
        from completedRound: WordQuizRound
    ) throws -> WordQuizRound? {
        var randomGenerator = SystemRandomNumberGenerator()
        return try makeRetryRound(
            from: completedRound,
            using: &randomGenerator
        )
    }

    static func makeRetryRound<R: RandomNumberGenerator>(
        from completedRound: WordQuizRound,
        using randomGenerator: inout R
    ) throws -> WordQuizRound? {
        guard completedRound.isComplete else {
            throw WordQuizEngineError.roundNotComplete
        }

        var questions = completedRound.incorrectQuestions
        guard !questions.isEmpty else { return nil }
        questions.shuffle(using: &randomGenerator)
        return WordQuizRound(
            language: completedRound.language,
            questions: questions
        )
    }

    /// 选项在界面上实际显示的文本，也是"两个选项看起来是否一样"的唯一判定依据。
    ///
    /// 目前词库收藏写入单词本的释义已经是限长 12 字的短释义（`LexiconGlossFormatter`），
    /// 因此这里不改变文本，只折叠空白。**这条等式的依赖关系必须保持**：
    /// 若将来把完整释义直接传进引擎，必须在这里接上词库的派生规则，
    /// 否则界面按原样渲染、引擎按派生结果判重，两边会各说各话。
    static func displayText(of meaning: String) -> String {
        meaning
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
    }

    private static func makeMeaningQuestion<R: RandomNumberGenerator>(
        for target: WordQuizCandidate,
        selectedCandidates: [WordQuizCandidate],
        allCandidates: [WordQuizCandidate],
        using randomGenerator: inout R
    ) throws -> WordQuizQuestion {
        let correctMeaning = normalizedMeaning(target.meaning)
        var usedMeanings = Set([correctMeaning])
        // 显示文本单独记一份：完整释义不同、显示文本却相同的词在词库里真实存在
        // （实测 93 组、189 条词，如 `aeroplane` 与 `airplane` 释义逐字相同，
        // `absolutely` 与 `altogether` 都被压成 `adv. 完全地…`），只靠释义去重拦不住。
        var usedDisplayTexts = Set([displayText(of: target.meaning)])
        var distractors: [WordQuizCandidate] = []

        // 优先使用本轮词条；不足时再从当前语言空间的完整候选池补齐。
        // 干扰项每次挑两个条件：释义不能重复（usedMeanings），显示文本也不能撞车（usedDisplayTexts）。
        var preferred = uniqueMeaningCandidates(
            selectedCandidates,
            excluding: target.id,
            usedMeanings: usedMeanings
        )
        preferred.shuffle(using: &randomGenerator)
        for candidate in preferred where distractors.count < choiceOptionCount - 1 {
            guard acceptDistractor(
                candidate,
                usedMeanings: &usedMeanings,
                usedDisplayTexts: &usedDisplayTexts
            ) else { continue }
            distractors.append(candidate)
        }

        var fallback = uniqueMeaningCandidates(
            allCandidates,
            excluding: target.id,
            usedMeanings: usedMeanings
        )
        fallback.shuffle(using: &randomGenerator)
        for candidate in fallback where distractors.count < choiceOptionCount - 1 {
            guard acceptDistractor(
                candidate,
                usedMeanings: &usedMeanings,
                usedDisplayTexts: &usedDisplayTexts
            ) else { continue }
            distractors.append(candidate)
        }

        // 宁可明确报错，也不静默少给一个选项——四选一是产品契约。
        guard distractors.count == choiceOptionCount - 1 else {
            throw WordQuizEngineError.insufficientDistinctMeanings(
                required: choiceOptionCount,
                available: usedMeanings.count
            )
        }

        var options = [WordQuizChoiceOption(id: target.id, meaning: target.meaning)]
        options.append(
            contentsOf: distractors.map {
                WordQuizChoiceOption(id: $0.id, meaning: $0.meaning)
            }
        )
        options.shuffle(using: &randomGenerator)

        return WordQuizQuestion(
            id: WordQuizQuestionID(
                candidateID: target.id,
                kind: .meaningChoice
            ),
            candidateID: target.id,
            term: target.term,
            meaning: target.meaning,
            kind: .meaningChoice,
            choiceOptions: options,
            acceptedSpellings: []
        )
    }

    private static func makeSpellingQuestion(
        for target: WordQuizCandidate,
        allCandidates: [WordQuizCandidate],
        language: LanguageSpace
    ) -> WordQuizQuestion {
        let targetMeaning = normalizedMeaning(target.meaning)
        let matchingCandidates = allCandidates.filter {
            normalizedMeaning($0.meaning) == targetMeaning
        }
        var usedTerms = Set<String>()
        let acceptedSpellings = matchingCandidates.compactMap { candidate in
            let normalizedTerm = WordNormalizer.normalizedTerm(
                candidate.term,
                in: language
            )
            return usedTerms.insert(normalizedTerm).inserted ? candidate.term : nil
        }

        return WordQuizQuestion(
            id: WordQuizQuestionID(
                candidateID: target.id,
                kind: .spelling
            ),
            candidateID: target.id,
            term: target.term,
            meaning: target.meaning,
            kind: .spelling,
            choiceOptions: [],
            acceptedSpellings: acceptedSpellings
        )
    }

    private static func preparedCandidates(
        _ candidates: [WordQuizCandidate]
    ) throws -> [WordQuizCandidate] {
        var candidatesByID: [UUID: WordQuizCandidate] = [:]
        for candidate in candidates {
            let term = candidate.term.trimmingCharacters(in: .whitespacesAndNewlines)
            let meaning = candidate.meaning.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !term.isEmpty, !meaning.isEmpty else {
                throw WordQuizEngineError.invalidCandidate(candidate.id)
            }
            if candidatesByID[candidate.id] == nil {
                candidatesByID[candidate.id] = WordQuizCandidate(
                    id: candidate.id,
                    term: term,
                    meaning: meaning
                )
            }
        }
        return candidatesByID.values.sorted { $0.id.uuidString < $1.id.uuidString }
    }

    private static func mergedCandidates(
        _ selectedCandidates: [WordQuizCandidate],
        with distractorCandidates: [WordQuizCandidate]
    ) throws -> [WordQuizCandidate] {
        let preparedDistractors = try preparedCandidates(distractorCandidates)
        var candidatesByID = Dictionary(
            uniqueKeysWithValues: preparedDistractors.map { ($0.id, $0) }
        )
        for candidate in selectedCandidates {
            candidatesByID[candidate.id] = candidate
        }
        return candidatesByID.values.sorted { $0.id.uuidString < $1.id.uuidString }
    }

    /// 判断一个候选干扰项是否可用，可用时把它的释义与显示文本一并登记。
    ///
    /// 返回 `false` 表示这条候选不能用：要么释义重复，要么显示文本与已选中的选项撞车
    /// （近义词、同根词，或将来完整释义被截断成同一段文字）。两者都只需换一条候选。
    private static func acceptDistractor(
        _ candidate: WordQuizCandidate,
        usedMeanings: inout Set<String>,
        usedDisplayTexts: inout Set<String>
    ) -> Bool {
        let meaning = normalizedMeaning(candidate.meaning)
        let displayText = displayText(of: candidate.meaning)
        // 两道闸门都通过才登记：先登记的写法会让被拒候选的释义占掉名额，
        // 使报错信息里的"可用释义数"虚高。
        guard !usedMeanings.contains(meaning),
              !usedDisplayTexts.contains(displayText) else {
            return false
        }
        usedMeanings.insert(meaning)
        usedDisplayTexts.insert(displayText)
        return true
    }

    private static func uniqueMeaningCandidates(
        _ candidates: [WordQuizCandidate],
        excluding candidateID: UUID,
        usedMeanings: Set<String>
    ) -> [WordQuizCandidate] {
        var meanings = usedMeanings
        return candidates.filter { candidate in
            guard candidate.id != candidateID else { return false }
            return meanings.insert(normalizedMeaning(candidate.meaning)).inserted
        }
    }

    private static func normalizedMeaning(_ meaning: String) -> String {
        meaning
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
            .precomposedStringWithCanonicalMapping
    }
}

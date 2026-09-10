//
//  WordQuizModels.swift
//  Egangnal
//

import Foundation

enum WordQuizScope: Hashable, Sendable {
    case allImported
    case date(VocabularyDocumentDate)
}

enum WordQuizDifficulty: String, CaseIterable, Identifiable, Sendable {
    case simple
    case deep

    var id: Self { self }
}

struct WordQuizCandidate: Identifiable, Hashable, Sendable {
    let id: UUID
    let term: String
    let meaning: String

    init(id: UUID, term: String, meaning: String) {
        self.id = id
        self.term = term
        self.meaning = meaning
    }
}

struct WordQuizConfiguration: Equatable, Sendable {
    let language: LanguageSpace
    let scope: WordQuizScope
    let difficulty: WordQuizDifficulty

    init(
        language: LanguageSpace,
        scope: WordQuizScope,
        difficulty: WordQuizDifficulty
    ) {
        self.language = language
        self.scope = scope
        self.difficulty = difficulty
    }
}

enum WordQuizQuestionKind: String, Hashable, Sendable {
    case meaningChoice
    case spelling
}

struct WordQuizQuestionID: Hashable, Sendable {
    let candidateID: UUID
    let kind: WordQuizQuestionKind
}

struct WordQuizChoiceOption: Identifiable, Equatable, Sendable {
    let id: UUID
    let meaning: String
}

struct WordQuizQuestion: Identifiable, Equatable, Sendable {
    let id: WordQuizQuestionID
    let candidateID: UUID
    let term: String
    let meaning: String
    let kind: WordQuizQuestionKind
    let choiceOptions: [WordQuizChoiceOption]
    let acceptedSpellings: [String]

    var correctAnswer: String {
        switch kind {
        case .meaningChoice:
            meaning
        case .spelling:
            term
        }
    }
}

enum WordQuizAnswer: Equatable, Sendable {
    case choice(optionID: UUID)
    case spelling(String)
}

struct WordQuizAnswerResult: Equatable, Sendable {
    let questionID: WordQuizQuestionID
    let answer: WordQuizAnswer
    let isCorrect: Bool
    let correctAnswer: String
}

struct WordQuizSession: Equatable, Sendable {
    let configuration: WordQuizConfiguration
    let selectedCandidates: [WordQuizCandidate]
    let questions: [WordQuizQuestion]

    func makeInitialRound() -> WordQuizRound {
        WordQuizRound(
            language: configuration.language,
            questions: questions
        )
    }
}

struct WordQuizRound: Equatable, Sendable {
    let language: LanguageSpace
    let questions: [WordQuizQuestion]
    private(set) var currentIndex = 0
    private(set) var responses: [WordQuizQuestionID: WordQuizAnswerResult] = [:]

    init(language: LanguageSpace, questions: [WordQuizQuestion]) {
        self.language = language
        self.questions = questions
    }

    var currentQuestion: WordQuizQuestion? {
        guard questions.indices.contains(currentIndex) else { return nil }
        return questions[currentIndex]
    }

    var currentResponse: WordQuizAnswerResult? {
        guard let currentQuestion else { return nil }
        return responses[currentQuestion.id]
    }

    var isComplete: Bool {
        currentIndex >= questions.count
    }

    var score: Int {
        responses.values.filter(\.isCorrect).count
    }

    var incorrectQuestions: [WordQuizQuestion] {
        questions.filter { responses[$0.id]?.isCorrect == false }
    }

    @discardableResult
    mutating func submit(_ answer: WordQuizAnswer) throws -> WordQuizAnswerResult {
        guard let question = currentQuestion else {
            throw WordQuizEngineError.roundAlreadyComplete
        }
        guard responses[question.id] == nil else {
            throw WordQuizEngineError.answerAlreadySubmitted
        }

        let result = try WordQuizEngine.evaluate(
            answer,
            for: question,
            language: language
        )
        responses[question.id] = result
        return result
    }

    mutating func advance() throws {
        guard !isComplete else {
            throw WordQuizEngineError.roundAlreadyComplete
        }
        guard currentResponse != nil else {
            throw WordQuizEngineError.currentQuestionUnanswered
        }
        currentIndex += 1
    }
}

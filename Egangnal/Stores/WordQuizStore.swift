//
//  WordQuizStore.swift
//  Egangnal
//

import Foundation
import Observation

enum WordQuizRangeMode: String, CaseIterable, Identifiable, Sendable {
    case allImported
    case date

    var id: Self { self }

    var title: String {
        switch self {
        case .allImported:
            "默认"
        case .date:
            "日期"
        }
    }
}

@MainActor
@Observable
final class WordQuizStore {
    let space: LanguageSpace

    private let candidateSource: any WordQuizCandidateProviding
    private var allCandidates: [WordQuizCandidate] = []
    private var datedCandidates: [WordQuizCandidate] = []
    private(set) var session: WordQuizSession?
    private(set) var round: WordQuizRound?

    private(set) var availableDates: [VocabularyDocumentDate] = []
    private(set) var notice: String?
    private(set) var hasSubmittedAnyAnswer = false
    var rangeMode: WordQuizRangeMode = .allImported
    var selectedDate: VocabularyDocumentDate?
    var difficulty: WordQuizDifficulty = .simple
    var spellingDraft = ""

    init(
        space: LanguageSpace,
        candidateSource: any WordQuizCandidateProviding
    ) {
        self.space = space
        self.candidateSource = candidateSource
    }

    var currentQuestion: WordQuizQuestion? {
        round?.currentQuestion
    }

    var currentResponse: WordQuizAnswerResult? {
        round?.currentResponse
    }

    var isShowingResult: Bool {
        round?.isComplete == true
    }

    var settingsAreLocked: Bool {
        round != nil
    }

    var needsExitConfirmation: Bool {
        hasSubmittedAnyAnswer && round != nil
    }

    var currentQuestionNumber: Int {
        guard let round, !round.isComplete else { return 0 }
        return round.currentIndex + 1
    }

    var currentRoundQuestionCount: Int {
        round?.questions.count ?? 0
    }

    var currentScore: Int {
        round?.score ?? 0
    }

    var hasIncorrectQuestions: Bool {
        !(round?.incorrectQuestions.isEmpty ?? true)
    }

    var selectedChoiceID: UUID? {
        guard case let .choice(optionID)? = currentResponse?.answer else {
            return nil
        }
        return optionID
    }

    var submittedSpelling: String? {
        guard case let .spelling(answer)? = currentResponse?.answer else {
            return nil
        }
        return answer
    }

    var startValidationMessage: String? {
        if let notice {
            return notice
        }
        guard !allCandidates.isEmpty else {
            return "请先向当前语言空间导入单词。"
        }
        let distinctMeaningCount = Set(
            allCandidates.map(Self.normalizedMeaning)
        ).count
        guard distinctMeaningCount >= WordQuizEngine.choiceOptionCount else {
            return "至少需要 4 个具有不同词义的已导入单词。"
        }
        if rangeMode == .date {
            guard selectedDate != nil else {
                return "当前没有可选择的导入日期。"
            }
            guard !datedCandidates.isEmpty else {
                return "所选日期没有可以测试的单词。"
            }
        }
        return nil
    }

    var canStart: Bool {
        !settingsAreLocked && startValidationMessage == nil
    }

    func load() {
        guard !settingsAreLocked else { return }

        do {
            allCandidates = try candidateSource.allImportedCandidates(in: space)
            availableDates = try candidateSource.availableDates(in: space)
            if let selectedDate, availableDates.contains(selectedDate) {
                self.selectedDate = selectedDate
            } else {
                selectedDate = availableDates.first
            }
            try reloadDatedCandidatesIfNeeded()
            notice = nil
        } catch {
            allCandidates = []
            datedCandidates = []
            availableDates = []
            selectedDate = nil
            notice = "读取单词本失败：\(error.localizedDescription)"
        }
    }

    func selectRangeMode(_ mode: WordQuizRangeMode) {
        guard !settingsAreLocked else { return }
        rangeMode = mode
        do {
            try reloadDatedCandidatesIfNeeded()
            notice = nil
        } catch {
            datedCandidates = []
            notice = "读取所选日期失败：\(error.localizedDescription)"
        }
    }

    func selectDate(_ date: VocabularyDocumentDate) {
        guard !settingsAreLocked, availableDates.contains(date) else { return }
        selectedDate = date
        do {
            try reloadDatedCandidatesIfNeeded()
            notice = nil
        } catch {
            datedCandidates = []
            notice = "读取所选日期失败：\(error.localizedDescription)"
        }
    }

    func selectDifficulty(_ difficulty: WordQuizDifficulty) {
        guard !settingsAreLocked else { return }
        self.difficulty = difficulty
    }

    func start() {
        guard canStart else { return }

        do {
            let scope: WordQuizScope
            let targets: [WordQuizCandidate]
            switch rangeMode {
            case .allImported:
                scope = .allImported
                targets = allCandidates
            case .date:
                guard let selectedDate else { return }
                scope = .date(selectedDate)
                targets = datedCandidates
            }

            let configuration = WordQuizConfiguration(
                language: space,
                scope: scope,
                difficulty: difficulty
            )
            let session = try WordQuizEngine.makeSession(
                configuration: configuration,
                targetCandidates: targets,
                distractorCandidates: allCandidates
            )
            self.session = session
            round = session.makeInitialRound()
            hasSubmittedAnyAnswer = false
            spellingDraft = ""
            notice = nil
        } catch {
            session = nil
            round = nil
            notice = error.localizedDescription
        }
    }

    @discardableResult
    func submitChoice(optionID: UUID) -> Bool {
        submit(.choice(optionID: optionID))
    }

    func submitSpelling() {
        guard !spellingDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }
        _ = submit(.spelling(spellingDraft))
    }

    func advance() {
        guard var round else { return }
        do {
            try round.advance()
            self.round = round
            spellingDraft = ""
            notice = nil
        } catch {
            notice = error.localizedDescription
        }
    }

    func retryIncorrect() {
        guard let completedRound = round, completedRound.isComplete else { return }
        do {
            guard let retryRound = try WordQuizEngine.makeRetryRound(
                from: completedRound
            ) else {
                return
            }
            round = retryRound
            spellingDraft = ""
            notice = nil
        } catch {
            notice = error.localizedDescription
        }
    }

    func returnToIdle() {
        discardSession()
        load()
    }

    func discardSession() {
        session = nil
        round = nil
        hasSubmittedAnyAnswer = false
        spellingDraft = ""
        notice = nil
    }

    private func submit(_ answer: WordQuizAnswer) -> Bool {
        guard var round else { return false }
        do {
            _ = try round.submit(answer)
            self.round = round
            hasSubmittedAnyAnswer = true
            notice = nil
            return true
        } catch {
            notice = error.localizedDescription
            return false
        }
    }

    private func reloadDatedCandidatesIfNeeded() throws {
        guard let selectedDate else {
            datedCandidates = []
            return
        }
        datedCandidates = try candidateSource.candidates(
            on: selectedDate,
            in: space
        )
    }

    private static func normalizedMeaning(_ candidate: WordQuizCandidate) -> String {
        candidate.meaning
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
            .precomposedStringWithCanonicalMapping
    }
}

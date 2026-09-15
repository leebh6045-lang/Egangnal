//
//  WordQuizStore.swift
//  Egangnal
//

import Foundation
import Observation

enum WordQuizRangeMode: String, CaseIterable, Identifiable, Sendable {
    case allImported
    case date
    /// 考公共词库：范围是词库的某个等级（或全部），与个人单词本无关。
    case lexicon

    var id: Self { self }

    var title: String {
        switch self {
        case .allImported:
            "默认"
        case .date:
            "日期"
        case .lexicon:
            "集词阁"
        }
    }
}

@MainActor
@Observable
final class WordQuizStore {
    let space: LanguageSpace

    private let candidateSource: any WordQuizCandidateProviding
    private let lexiconCandidateSource: (any LexiconQuizCandidateProviding)?
    private var allCandidates: [WordQuizCandidate] = []
    private var datedCandidates: [WordQuizCandidate] = []
    /// 词库范围的干扰项池（整个词库）。与 `allCandidates` 分开保存：两个池子的释义文本形态不同，
    /// 混在一个数组里会让同一题出现两种风格的选项。
    private var lexiconCandidates: [WordQuizCandidate] = []
    /// 词库范围的目标集（当前等级筛选结果），是干扰项池的子集。
    private var targetLexiconCandidates: [WordQuizCandidate] = []
    /// 词库范围内选中的等级；`nil` 表示全部等级。等级变化会重新加载候选集。
    private(set) var lexiconLevel: VocabularyLevel?
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
        candidateSource: any WordQuizCandidateProviding,
        lexiconCandidateSource: (any LexiconQuizCandidateProviding)? = nil
    ) {
        self.space = space
        self.candidateSource = candidateSource
        self.lexiconCandidateSource = lexiconCandidateSource
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

    /// 题库范围的一句话说明，供设置区与辅助功能使用。
    var scopeTitle: String {
        guard isLexiconScoped else {
            return "单词本 · \(rangeMode.title)"
        }
        return "集词阁 · \(lexiconLevel?.title ?? "全部")"
    }

    /// 这次测试是否考公共词库。为真时设置区显示等级选择器而不是日期选择器。
    var isLexiconScoped: Bool {
        rangeMode == .lexicon
    }

    /// 本次测试的候选范围。词库范围只按等级筛选。
    var lexiconScope: LexiconQuizScope {
        guard let lexiconLevel else { return .all }
        return .level(lexiconLevel)
    }

    /// 本次测试的目标词条：
    /// 词库范围 → 词库等级筛选结果；日期范围 → 当天出现过的词；默认范围 → 个人单词本中可抽题的词。
    var currentTargetCandidates: [WordQuizCandidate] {
        guard !isLexiconScoped else { return targetLexiconCandidates }
        return rangeMode == .date ? datedCandidates : allCandidates
    }

    /// 与目标集配套的干扰项池。两个池子分开：它们的释义文本形态不同，不能混用。
    private var currentDistractorCandidates: [WordQuizCandidate] {
        isLexiconScoped ? lexiconCandidates : allCandidates
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
        // 读取失败的原因优先：读不到词库时若先报"筛选范围没有词条"，
        // 用户会以为是自己筛选得不对，而不是数据出了问题。
        if let notice {
            return notice
        }
        let targets = currentTargetCandidates
        guard !targets.isEmpty else {
            return isLexiconScoped
                ? "当前筛选范围没有可以测试的词条。"
                : "请先向当前语言空间导入或收藏单词。"
        }
        // 与引擎同一套判据：四选一需要至少 4 个不同词义的词条，且不只看目标集——
        // 词库范围下干扰项来自全库，所以判据要用最终的选项来源。
        let distinctMeaningCount = Set(
            currentDistractorCandidates.map(Self.normalizedMeaning)
        ).count
        guard distinctMeaningCount >= WordQuizEngine.choiceOptionCount else {
            return isLexiconScoped
                ? "当前筛选范围的不同词义不足 4 个，无法组成四选一。"
                : "至少需要 4 个具有不同词义的单词。"
        }
        // 日期范围还要有选中的日期与之匹配。
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

    /// 进入页面时加载词库候选**一次**。
    ///
    /// 词库范围是用户随时可能切过去的，所以候选要提前备好；但 7,116 条只在页面进入时读一次，
    /// 打字、答题、切难度都不会重复查询。读失败不阻塞单词本范围——两个池子互不影响。
    func loadLexiconCandidatesIfNeeded() {
        guard lexiconCandidates.isEmpty else { return }
        loadLexiconCandidates()
    }

    /// 词库范围内的等级筛选。改等级要换目标集，因此立即重新加载。
    func selectLexiconLevel(_ level: VocabularyLevel?) {
        guard !settingsAreLocked, lexiconLevel != level else { return }
        lexiconLevel = level
        loadLexiconCandidates()
    }

    private func clearLexiconCandidates() {
        lexiconCandidates = []
        targetLexiconCandidates = []
        notice = nil
    }

    private func loadLexiconCandidates() {
        guard let lexiconCandidateSource else {
            lexiconCandidates = []
            targetLexiconCandidates = []
            notice = "集词阁范围暂不可用。"
            return
        }
        do {
            let candidates = try lexiconCandidateSource.lexiconQuizCandidates(in: lexiconScope)
            lexiconCandidates = candidates.distractors
            targetLexiconCandidates = candidates.targets
            notice = nil
        } catch {
            lexiconCandidates = []
            targetLexiconCandidates = []
            notice = (error as? LocalizedError)?.errorDescription
                ?? "读取集词阁失败：\(error.localizedDescription)"
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
            return
        }
        // 切到词库范围时补一次加载；失败原因由它自己写入，这里不能再清 notice，
        // 否则"词库读取失败"会被抹成一股"范围不可用"的模糊提示。
        if mode == .lexicon, lexiconCandidates.isEmpty {
            loadLexiconCandidates()
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
            // 词库与单词本两个范围共用同一套组卷逻辑，差别只在目标集与干扰项池的来源。
            let scope: WordQuizScope
            switch rangeMode {
            case .allImported:
                scope = .allImported
            case .date:
                guard let selectedDate else { return }
                scope = .date(selectedDate)
            case .lexicon:
                scope = .lexicon(lexiconScope)
            }

            let configuration = WordQuizConfiguration(
                language: space,
                scope: scope,
                difficulty: difficulty
            )
            let session = try WordQuizEngine.makeSession(
                configuration: configuration,
                targetCandidates: currentTargetCandidates,
                distractorCandidates: currentDistractorCandidates
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

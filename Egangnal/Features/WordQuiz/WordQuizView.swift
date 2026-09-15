//
//  WordQuizView.swift
//  Egangnal
//

import SwiftUI

enum WordQuizFeedbackTiming {
    static let successRingDurationSeconds: TimeInterval = 0.4
    static let successRingDuration: Duration = .milliseconds(400)
    static let correctDelay: Duration = .milliseconds(1_500)
    static let incorrectDelay: Duration = .seconds(3)

    static func delay(isCorrect: Bool) -> Duration {
        isCorrect ? correctDelay : incorrectDelay
    }
}

// 空闲提示与开始按钮统一按语言空间切换，避免视图中散落条件判断。
struct WordQuizPageCopy: Equatable {
    let idleWatermarkTopLine: String
    let idleWatermarkBottomLine: String
    let startButtonTitle: String

    static func make(for space: LanguageSpace) -> WordQuizPageCopy {
        switch space {
        case .japanese:
            WordQuizPageCopy(
                idleWatermarkTopLine: "準備が",
                idleWatermarkBottomLine: "できましたか",
                startButtonTitle: "始めます"
            )
        case .english:
            WordQuizPageCopy(
                idleWatermarkTopLine: "I know",
                idleWatermarkBottomLine: "you‘re ready",
                startButtonTitle: "Let's go"
            )
        }
    }
}

enum WordQuizLayout {
    static func preferredAnswerContentWidth(
        for availableWidth: CGFloat
    ) -> CGFloat {
        let safeWidth = max(availableWidth, 0)
        let fourChoiceWidth = (AppTheme.wordQuizChoiceWidth * 4)
            + (AppTheme.wordQuizChoiceSpacing * 3)
        if safeWidth >= fourChoiceWidth {
            return fourChoiceWidth
        }

        let compactChoiceWidth = (AppTheme.wordQuizCompactChoiceWidth * 2)
            + AppTheme.wordQuizChoiceSpacing
        return min(safeWidth, compactChoiceWidth)
    }

    static func answerContentOffset(for availableWidth: CGFloat) -> CGFloat {
        let preferredWidth = preferredAnswerContentWidth(for: availableWidth)
        let unusedWidth = max(availableWidth - preferredWidth, 0)
        // 只移动答题内容；二分补偿可以保持可见内容居中，同时固定设置区位置。
        return -(unusedWidth / 2)
    }
}

struct WordQuizView: View {
    @Environment(\.appPalette) private var palette
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let space: LanguageSpace
    let settingsStore: AppSettingsStore
    let soundPlayer: any WordQuizSoundPlaying
    let openWorkspace: () -> Void
    let exitCoordinator: WorkspaceExitCoordinator?

    @State private var store: WordQuizStore
    @State private var isExitConfirmationPresented = false
    @State private var pendingExitAction: (() -> Void)?
    @State private var exitInterceptorID: UUID?
    @State private var pendingAdvanceTask: Task<Void, Never>?
    @State private var spellingIsFocused = false

    init(
        space: LanguageSpace,
        candidateSource: any WordQuizCandidateProviding,
        lexiconCandidateSource: (any LexiconQuizCandidateProviding)? = nil,
        settingsStore: AppSettingsStore,
        soundPlayer: any WordQuizSoundPlaying,
        openWorkspace: @escaping () -> Void,
        exitCoordinator: WorkspaceExitCoordinator? = nil
    ) {
        self.space = space
        self.settingsStore = settingsStore
        self.soundPlayer = soundPlayer
        self.openWorkspace = openWorkspace
        self.exitCoordinator = exitCoordinator
        _store = State(
            initialValue: WordQuizStore(
                space: space,
                candidateSource: candidateSource,
                lexiconCandidateSource: lexiconCandidateSource
            )
        )
    }

    var body: some View {
        ZStack {
            ZStack(alignment: .topLeading) {
                // 答题主体占据整个窗口可用区域，页眉叠加显示，不再挤压主体中心。
                quizBody
                header
            }
            .padding(AppTheme.contentPadding)
        }
        .onAppear {
            store.load()
            // 词库范围用户随时可能切过去，候选在进入页面时备好一次。
            store.loadLexiconCandidatesIfNeeded()
            installExitInterceptor()
        }
        .onChange(of: store.currentQuestion?.id) {
            focusSpellingQuestionIfNeeded()
        }
        .onChange(of: store.currentResponse) { _, response in
            scheduleAutomaticAdvance(for: response)
        }
        .onDisappear {
            cancelAutomaticAdvance()
            removeExitInterceptor()
        }
        .alert("放弃本次测试？", isPresented: $isExitConfirmationPresented) {
            Button("继续答题", role: .cancel) {
                pendingExitAction = nil
                scheduleAutomaticAdvance(for: store.currentResponse)
            }
            Button("放弃并离开", role: .destructive) {
                let action = pendingExitAction
                pendingExitAction = nil
                cancelAutomaticAdvance()
                store.discardSession()
                action?()
            }
        } message: {
            Text("当前答题进度不会保存。")
        }
    }

    private var header: some View {
        HStack(spacing: 14) {
            Button(action: requestWorkspaceReturn) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 17, weight: .semibold))
                    .frame(width: 32, height: 32, alignment: .leading)
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.escape, modifiers: [])
            .help("返回学习空间")
            .accessibilityLabel("返回学习空间")
            .accessibilityIdentifier("wordQuiz.back")

            Text("\(space.title)单词刷")
                .font(.title2.weight(.semibold))
                .foregroundStyle(palette.primaryText)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("wordQuiz.\(space.rawValue).title")

            Spacer()
        }
    }

    private var quizBody: some View {
        GeometryReader { proxy in
            let availableHeight = max(
                proxy.size.height - 24,
                AppTheme.wordQuizContentMinHeight
            )
            let contentHeight = min(
                availableHeight,
                AppTheme.wordQuizContentHeight
            )
            let bodyWidth = min(
                proxy.size.width,
                AppTheme.wordQuizBodyMaxWidth
            )
            let innerWidth = max(
                bodyWidth - (AppTheme.wordQuizBodyHorizontalInset * 2),
                0
            )
            let answerWidth = max(
                innerWidth
                    - AppTheme.wordQuizSettingsWidth
                    - (AppTheme.wordQuizColumnSpacing * 2)
                    - 1,
                0
            )
            let preferredAnswerContentWidth = WordQuizLayout
                .preferredAnswerContentWidth(for: answerWidth)
            let answerContentOffset = WordQuizLayout
                .answerContentOffset(for: answerWidth)

            HStack(spacing: AppTheme.wordQuizColumnSpacing) {
                answerArea(
                    preferredContentWidth: preferredAnswerContentWidth
                )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .offset(x: answerContentOffset)

                Rectangle()
                    .fill(palette.border.opacity(0.78))
                    .frame(width: 1, height: contentHeight)
                    .accessibilityHidden(true)

                settingsArea
                    .frame(width: AppTheme.wordQuizSettingsWidth)
                    .frame(height: contentHeight)
            }
            // 显式固定主体边界后再定位，避免弹性 frame 让整组控件产生视觉偏移。
            .frame(width: innerWidth, height: contentHeight)
            .padding(.horizontal, AppTheme.wordQuizBodyHorizontalInset)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("wordQuiz.body")
            .position(
                x: proxy.size.width / 2,
                y: proxy.size.height / 2
            )
        }
    }

    @ViewBuilder
    private func answerArea(preferredContentWidth: CGFloat) -> some View {
        if store.isShowingResult {
            WordQuizResultView(
                score: store.currentScore,
                total: store.currentRoundQuestionCount,
                hasIncorrectQuestions: store.hasIncorrectQuestions,
                retry: { store.retryIncorrect() },
                finish: { store.returnToIdle() }
            )
            .transition(contentTransition)
        } else if let question = store.currentQuestion {
            VStack(spacing: 22) {
                Text("第 \(store.currentQuestionNumber) / \(store.currentRoundQuestionCount) 题")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(palette.secondaryText)
                    .monospacedDigit()
                    .accessibilityIdentifier("wordQuiz.progress")

                switch question.kind {
                case .meaningChoice:
                    WordQuizChoiceQuestionView(
                        question: question,
                        response: store.currentResponse,
                        submit: submitChoice
                    )
                    .id(question.id)
                case .spelling:
                    WordQuizSpellingQuestionView(
                        question: question,
                        response: store.currentResponse,
                        isFocused: $spellingIsFocused,
                        submit: submitSpelling
                    )
                    .id(question.id)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .transition(contentTransition)
        } else {
            idleWatermark(preferredContentWidth: preferredContentWidth)
        }
    }

    private func idleWatermark(preferredContentWidth: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(pageCopy.idleWatermarkTopLine)
            Text(pageCopy.idleWatermarkBottomLine)
        }
        .font(
            .system(
                size: AppTheme.wordQuizIdleWatermarkFontSize,
                weight: .semibold,
                design: .rounded
            )
        )
        .foregroundStyle(palette.watermark)
        .lineLimit(1)
        .minimumScaleFactor(0.75)
        .frame(width: preferredContentWidth, alignment: .leading)
        .allowsHitTesting(false)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "\(pageCopy.idleWatermarkTopLine) \(pageCopy.idleWatermarkBottomLine)"
        )
        .accessibilityIdentifier("wordQuiz.idle.watermark")
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }

    private var settingsArea: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("测试范围")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(palette.secondaryText)

                Picker("测试范围", selection: rangeModeBinding) {
                    ForEach(WordQuizRangeMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .font(.body.weight(.medium))
                .controlSize(.large)
                .accessibilityIdentifier("wordQuiz.range")

                // 日期与等级是同一位置的二级选择：范围选了哪个，就显示对应的细分。
                Group {
                    if store.isLexiconScoped {
                        lexiconLevelSelector
                    } else {
                        dateSelector
                    }
                }
                .frame(height: 44)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("测试难度")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(palette.secondaryText)

                Picker("测试难度", selection: difficultyBinding) {
                    ForEach(WordQuizDifficulty.allCases) { difficulty in
                        Text(difficulty.title).tag(difficulty)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .font(.body.weight(.medium))
                .controlSize(.large)
                .accessibilityIdentifier("wordQuiz.difficulty")
            }

            VStack(alignment: .leading, spacing: 8) {
                Button {
                    store.start()
                } label: {
                    Text(pageCopy.startButtonTitle)
                        .font(.title3.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: 40)
                }
                .buttonStyle(.borderedProminent)
                .tint(palette.accent(for: space))
                .controlSize(.large)
                .disabled(!store.canStart)
                .accessibilityIdentifier("wordQuiz.start")

                Text(store.startValidationMessage ?? "最多随机抽取 20 个单词")
                    .font(.callout)
                    .foregroundStyle(
                        store.startValidationMessage == nil
                            ? palette.tertiaryText
                            : palette.error
                    )
                    .lineLimit(2)
                    .minimumScaleFactor(0.82)
                    // 提示槽固定高度，错误文案变化也不能带动上方设置控件位移。
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(height: 40, alignment: .top)
                    .accessibilityIdentifier("wordQuiz.settings.notice")
            }
        }
        .frame(maxHeight: .infinity, alignment: .center)
        .disabled(store.settingsAreLocked)
        .accessibilityValue(
            store.settingsAreLocked ? "答题进行中，不可更改" : "可以更改"
        )
    }

    @ViewBuilder
    private var dateSelector: some View {
        if store.rangeMode == .date {
            if let selectedDate = store.selectedDate {
                Picker("导入日期", selection: selectedDateBinding(selectedDate)) {
                    ForEach(store.availableDates, id: \.self) { date in
                        Text(date.templateText).tag(date)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .font(.body.weight(.medium))
                .controlSize(.large)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityIdentifier("wordQuiz.date")
            } else {
                Text("暂无导入日期")
                    .font(.subheadline)
                    .foregroundStyle(palette.tertiaryText)
                    .accessibilityIdentifier("wordQuiz.date.empty")
            }
        } else {
            Color.clear
                .accessibilityHidden(true)
        }
    }

    /// 词库范围的等级细分。等级是"考哪一批词"的一部分，因此与范围放在同一组控件里。
    private var lexiconLevelSelector: some View {
        Picker("集词阁等级", selection: lexiconLevelBinding) {
            Text("全部").tag(VocabularyLevel?.none)
            ForEach(VocabularyLevel.allCases) { level in
                Text(level.title).tag(VocabularyLevel?.some(level))
            }
        }
        .pickerStyle(.menu)
        .labelsHidden()
        .font(.body.weight(.medium))
        .controlSize(.large)
        .frame(maxWidth: .infinity, alignment: .leading)
        .help("只考集词阁中该等级的单词")
        .accessibilityLabel("集词阁等级")
        .accessibilityIdentifier("wordQuiz.lexiconLevel")
    }

    private var pageCopy: WordQuizPageCopy {
        WordQuizPageCopy.make(for: space)
    }

    private var rangeModeBinding: Binding<WordQuizRangeMode> {
        Binding(
            get: { store.rangeMode },
            set: { store.selectRangeMode($0) }
        )
    }

    private var lexiconLevelBinding: Binding<VocabularyLevel?> {
        Binding(
            get: { store.lexiconLevel },
            set: { store.selectLexiconLevel($0) }
        )
    }

    private var difficultyBinding: Binding<WordQuizDifficulty> {
        Binding(
            get: { store.difficulty },
            set: { store.selectDifficulty($0) }
        )
    }

    private func selectedDateBinding(
        _ fallback: VocabularyDocumentDate
    ) -> Binding<VocabularyDocumentDate> {
        Binding(
            get: { store.selectedDate ?? fallback },
            set: { store.selectDate($0) }
        )
    }

    private var contentTransition: AnyTransition {
        reduceMotion ? .identity : .opacity
    }

    private func requestWorkspaceReturn() {
        requestExit(perform: openWorkspace)
    }

    private func requestExit(perform action: @escaping () -> Void) {
        if store.needsExitConfirmation {
            cancelAutomaticAdvance()
            pendingExitAction = action
            isExitConfirmationPresented = true
        } else {
            cancelAutomaticAdvance()
            store.discardSession()
            action()
        }
    }

    private func installExitInterceptor() {
        guard exitInterceptorID == nil, let exitCoordinator else { return }
        exitInterceptorID = exitCoordinator.install { action in
            requestExit(perform: action)
        }
    }

    private func removeExitInterceptor() {
        guard let exitInterceptorID else { return }
        exitCoordinator?.remove(id: exitInterceptorID)
        self.exitInterceptorID = nil
        pendingExitAction = nil
    }

    private func submitSpelling(_ draft: String) {
        store.spellingDraft = draft
        store.submitSpelling()
        if store.currentResponse != nil {
            spellingIsFocused = false
        }
    }

    private func submitChoice(_ optionID: UUID) {
        guard store.submitChoice(optionID: optionID) else { return }
        // 音效是附加反馈，播放结果不能影响已经完成的判题。
        soundPlayer.play(settingsStore.wordQuizSoundEffect)
    }

    private func focusSpellingQuestionIfNeeded() {
        guard store.currentQuestion?.kind == .spelling,
              store.currentResponse == nil else {
            spellingIsFocused = false
            return
        }
        Task { @MainActor in
            spellingIsFocused = true
        }
    }

    private func scheduleAutomaticAdvance(
        for response: WordQuizAnswerResult?
    ) {
        cancelAutomaticAdvance()
        guard let response,
              let questionID = store.currentQuestion?.id else {
            return
        }

        let delay = WordQuizFeedbackTiming.delay(isCorrect: response.isCorrect)
        pendingAdvanceTask = Task { @MainActor in
            do {
                try await Task.sleep(for: delay)
            } catch {
                return
            }
            guard !Task.isCancelled,
                  store.currentQuestion?.id == questionID,
                  store.currentResponse?.questionID == response.questionID else {
                return
            }
            pendingAdvanceTask = nil
            store.advance()
        }
    }

    private func cancelAutomaticAdvance() {
        pendingAdvanceTask?.cancel()
        pendingAdvanceTask = nil
    }
}

private extension WordQuizDifficulty {
    var title: String {
        switch self {
        case .simple:
            "简单"
        case .deep:
            "深度"
        }
    }
}

#Preview("英语单词刷") {
    WordQuizView(
        space: .english,
        candidateSource: WordQuizCandidateSource(
            repository: PreviewWordBookRepository()
        ),
        lexiconCandidateSource: LexiconQuizCandidateSource(
            lexiconRepository: PreviewLexiconRepository()
        ),
        settingsStore: .preview,
        soundPlayer: SilentWordQuizSoundPlayer(),
        openWorkspace: {}
    )
    .frame(width: 1080, height: 700)
}

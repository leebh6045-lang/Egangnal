//
//  WordQuizComponents.swift
//  Egangnal
//

import AppKit
import SwiftUI

enum WordQuizChoiceFeedbackPolicy {
    static func showsSuccessRing(
        response: WordQuizAnswerResult?,
        optionID: UUID,
        correctOptionID: UUID
    ) -> Bool {
        guard response?.isCorrect == true,
              case let .choice(selectedID)? = response?.answer else {
            return false
        }
        return selectedID == optionID && optionID == correctOptionID
    }
}

struct WordQuizChoiceQuestionView: View {
    @Environment(\.appPalette) private var palette
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let question: WordQuizQuestion
    let response: WordQuizAnswerResult?
    let submit: (UUID) -> Void

    @State private var successRingProgress: CGFloat = 0

    var body: some View {
        VStack(spacing: 26) {
            Text(question.term)
                .font(.system(size: 44, weight: .semibold, design: .rounded))
                .foregroundStyle(palette.primaryText)
                .lineLimit(2)
                .minimumScaleFactor(0.62)
                .multilineTextAlignment(.center)
                .frame(height: 72)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("wordQuiz.question.term")

            choiceLayout

            feedback
        }
        .frame(maxWidth: 660)
        .onAppear {
            updateSuccessRing(for: response)
        }
        .onChange(of: response) { _, newResponse in
            updateSuccessRing(for: newResponse)
        }
        .onChange(of: question.id) {
            setSuccessRingProgressImmediately(0)
        }
        .onChange(of: reduceMotion) { _, isReduced in
            guard isReduced, response?.isCorrect == true else { return }
            setSuccessRingProgressImmediately(1)
        }
    }

    @ViewBuilder
    private var choiceLayout: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: AppTheme.wordQuizChoiceSpacing) {
                choiceButtons(width: AppTheme.wordQuizChoiceWidth)
            }
            .fixedSize(horizontal: true, vertical: false)

            LazyVGrid(
                columns: [
                    GridItem(
                        .fixed(AppTheme.wordQuizCompactChoiceWidth),
                        spacing: AppTheme.wordQuizChoiceSpacing
                    ),
                    GridItem(
                        .fixed(AppTheme.wordQuizCompactChoiceWidth),
                        spacing: AppTheme.wordQuizChoiceSpacing
                    )
                ],
                spacing: AppTheme.wordQuizChoiceSpacing
            ) {
                choiceButtons(width: AppTheme.wordQuizCompactChoiceWidth)
            }
            .fixedSize(horizontal: true, vertical: false)
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func choiceButtons(width: CGFloat?) -> some View {
        ForEach(Array(question.choiceOptions.enumerated()), id: \.element.id) { index, option in
            Button {
                submit(option.id)
            } label: {
                VStack(spacing: 3) {
                    Text(option.meaning)
                        .font(.title3.weight(.medium))
                        .lineLimit(3)
                        .minimumScaleFactor(0.78)
                        .multilineTextAlignment(.center)
                        .frame(maxHeight: .infinity)

                    let status = optionStatus(option)
                    Text(status?.text ?? "状态占位")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(status?.color ?? .clear)
                        .frame(height: 14)
                        .accessibilityHidden(status == nil)
                }
                .padding(.horizontal, 10)
                .frame(
                    minWidth: width,
                    maxWidth: width ?? .infinity,
                    minHeight: AppTheme.wordQuizChoiceHeight,
                    maxHeight: AppTheme.wordQuizChoiceHeight
                )
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .foregroundStyle(palette.primaryText)
            .background(optionBackground(option))
            .clipShape(.rect(cornerRadius: 8))
            .overlay {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(
                            optionBorder(option),
                            lineWidth: response == nil ? 1 : 2
                        )

                    if showsSuccessRing(for: option) {
                        WordQuizClockwiseRoundedBorder(cornerRadius: 8)
                            .inset(by: AppTheme.wordQuizSuccessRingLineWidth / 2)
                            .trim(from: 0, to: successRingProgress)
                            .stroke(
                                palette.success,
                                style: StrokeStyle(
                                    lineWidth: AppTheme.wordQuizSuccessRingLineWidth,
                                    lineCap: .round,
                                    lineJoin: .round
                                )
                            )
                            .accessibilityHidden(true)
                    }
                }
            }
            .disabled(response != nil)
            .keyboardShortcut(
                KeyEquivalent(Character(String(index + 1))),
                modifiers: []
            )
            .accessibilityLabel("选项 \(index + 1)，\(option.meaning)")
            .accessibilityValue(optionAccessibilityValue(option))
            .accessibilityIdentifier("wordQuiz.choice.option.\(index + 1)")
        }
    }

    @ViewBuilder
    private var feedback: some View {
        if let response {
            Label(
                response.isCorrect ? "回答正确" : "回答错误，正确答案是：\(question.meaning)",
                systemImage: response.isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill"
            )
            .font(.headline)
            .foregroundStyle(response.isCorrect ? palette.success : palette.error)
            .lineLimit(2)
            .minimumScaleFactor(0.82)
            .multilineTextAlignment(.center)
            .frame(height: AppTheme.wordQuizFeedbackHeight)
            .accessibilityIdentifier("wordQuiz.feedback")
        } else {
            Color.clear
                .frame(height: AppTheme.wordQuizFeedbackHeight)
                .accessibilityHidden(true)
        }
    }

    private func optionStatus(
        _ option: WordQuizChoiceOption
    ) -> (text: String, color: Color)? {
        guard let response else { return nil }
        if option.id == question.candidateID {
            return ("正确答案", palette.success)
        }
        guard case let .choice(selectedID) = response.answer,
              selectedID == option.id else {
            return nil
        }
        return ("你的选择", palette.error)
    }

    private func optionBackground(_ option: WordQuizChoiceOption) -> Color {
        guard let response else { return palette.panel }
        if option.id == question.candidateID {
            return palette.success.opacity(0.12)
        }
        if case let .choice(selectedID) = response.answer, selectedID == option.id {
            return palette.error.opacity(0.12)
        }
        return palette.panel
    }

    private func optionBorder(_ option: WordQuizChoiceOption) -> Color {
        guard let response else { return palette.border }
        if option.id == question.candidateID {
            // 答对时由上层进度线逐步绘制完整绿色边框。
            return response.isCorrect ? palette.border.opacity(0.65) : palette.success
        }
        if case let .choice(selectedID) = response.answer, selectedID == option.id {
            return palette.error
        }
        return palette.border.opacity(0.65)
    }

    private func showsSuccessRing(for option: WordQuizChoiceOption) -> Bool {
        WordQuizChoiceFeedbackPolicy.showsSuccessRing(
            response: response,
            optionID: option.id,
            correctOptionID: question.candidateID
        )
    }

    private func updateSuccessRing(for response: WordQuizAnswerResult?) {
        setSuccessRingProgressImmediately(0)
        guard response?.isCorrect == true else { return }

        if reduceMotion {
            setSuccessRingProgressImmediately(1)
        } else {
            withAnimation(
                .linear(duration: WordQuizFeedbackTiming.successRingDurationSeconds)
            ) {
                successRingProgress = 1
            }
        }
    }

    private func setSuccessRingProgressImmediately(_ progress: CGFloat) {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            successRingProgress = progress
        }
    }

    private func optionAccessibilityValue(_ option: WordQuizChoiceOption) -> String {
        guard let response else { return "未选择" }
        if option.id == question.candidateID {
            return "正确答案"
        }
        if case let .choice(selectedID) = response.answer, selectedID == option.id {
            return "你的选择，回答错误"
        }
        return "未选择"
    }
}

private struct WordQuizClockwiseRoundedBorder: InsettableShape {
    let cornerRadius: CGFloat
    private var insetAmount: CGFloat

    init(cornerRadius: CGFloat, insetAmount: CGFloat = 0) {
        self.cornerRadius = cornerRadius
        self.insetAmount = insetAmount
    }

    func inset(by amount: CGFloat) -> Self {
        WordQuizClockwiseRoundedBorder(
            cornerRadius: cornerRadius,
            insetAmount: insetAmount + amount
        )
    }

    func path(in bounds: CGRect) -> Path {
        let rect = bounds.insetBy(dx: insetAmount, dy: insetAmount)
        guard rect.width > 0, rect.height > 0 else { return Path() }

        let radius = min(
            max(cornerRadius - insetAmount, 0),
            min(rect.width, rect.height) / 2
        )
        var path = Path()
        // 从左上圆角的顶部切点出发，按右、下、左、上的顺序形成顺时针路径。
        path.move(to: CGPoint(x: rect.minX + radius, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - radius, y: rect.minY))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.minY + radius),
            control: CGPoint(x: rect.maxX, y: rect.minY)
        )
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - radius))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX - radius, y: rect.maxY),
            control: CGPoint(x: rect.maxX, y: rect.maxY)
        )
        path.addLine(to: CGPoint(x: rect.minX + radius, y: rect.maxY))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX, y: rect.maxY - radius),
            control: CGPoint(x: rect.minX, y: rect.maxY)
        )
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + radius))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX + radius, y: rect.minY),
            control: CGPoint(x: rect.minX, y: rect.minY)
        )
        return path
    }
}

struct WordQuizSpellingQuestionView: View {
    @Environment(\.appPalette) private var palette

    let question: WordQuizQuestion
    let response: WordQuizAnswerResult?
    @Binding var isFocused: Bool
    let submit: (String) -> Void

    @State private var draft = ""

    var body: some View {
        VStack(spacing: 26) {
            HStack(alignment: .firstTextBaseline, spacing: 28) {
                WordQuizContinuousTextField(
                    text: $draft,
                    isEnabled: response == nil,
                    isFocused: $isFocused,
                    textColor: NSColor(palette.primaryText),
                    submit: submitDraft
                )
                    .frame(minWidth: 200, idealWidth: 270, maxWidth: 320)
                    .padding(.vertical, 8)
                    .overlay(alignment: .bottom) {
                        Rectangle()
                            .fill(responseBorderColor)
                            .frame(height: response == nil ? 1 : 2)
                    }

                Text(question.meaning)
                    .font(.system(size: 34, weight: .medium))
                    .foregroundStyle(palette.primaryText)
                    .lineLimit(3)
                    .minimumScaleFactor(0.72)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityIdentifier("wordQuiz.question.meaning")
            }
            .frame(maxWidth: 560, minHeight: 72)

            ZStack {
                if response == nil {
                    Button("确认") {
                        submitDraft()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(palette.calendarAccent)
                    .controlSize(.large)
                    .keyboardShortcut(.return, modifiers: [.command])
                    .accessibilityIdentifier("wordQuiz.spelling.submit")
                    .accessibilityValue(
                        draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            ? "没有输入"
                            : "可以提交"
                    )
                } else {
                    let isCorrect = response?.isCorrect == true
                    let feedbackText = isCorrect
                        ? "回答正确"
                        : "回答错误，正确答案是：\(question.term)"
                    Label(
                        feedbackText,
                        systemImage: isCorrect
                            ? "checkmark.circle.fill"
                            : "xmark.circle.fill"
                    )
                    .font(.headline)
                    .foregroundStyle(
                        isCorrect ? palette.success : palette.error
                    )
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(feedbackText)
                    .accessibilityIdentifier("wordQuiz.feedback")
                }
            }
            .frame(height: AppTheme.wordQuizFeedbackHeight)
        }
        .frame(maxWidth: 620)
    }

    private var responseBorderColor: Color {
        guard let response else { return palette.border }
        return response.isCorrect ? palette.success : palette.error
    }

    private func submitDraft() {
        guard !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }
        isFocused = false
        submit(draft)
    }
}

private struct WordQuizContinuousTextField: NSViewRepresentable {
    @Binding var text: String

    let isEnabled: Bool
    @Binding var isFocused: Bool
    let textColor: NSColor
    let submit: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeNSView(context: Context) -> NSTextField {
        let textField = NSTextField()
        context.coordinator.textField = textField
        textField.delegate = context.coordinator
        textField.isBordered = false
        textField.drawsBackground = false
        textField.focusRingType = .none
        textField.alignment = .center
        textField.placeholderString = "输入单词"
        textField.font = .systemFont(ofSize: 32, weight: .semibold)
        textField.setAccessibilityLabel("根据词义拼写单词")
        textField.setAccessibilityIdentifier("wordQuiz.spelling.input")
        return textField
    }

    func updateNSView(_ textField: NSTextField, context: Context) {
        context.coordinator.parent = self
        let isEditing = textField.currentEditor() != nil

        // 编辑期间原生 field editor 拥有文本与选区，重复回写会中断光标。
        if !isEditing, textField.stringValue != text {
            textField.stringValue = text
        }

        if textField.isEnabled != isEnabled {
            textField.isEnabled = isEnabled
        }
        if textField.isEditable != isEnabled {
            textField.isEditable = isEnabled
        }
        if textField.isSelectable != isEnabled {
            textField.isSelectable = isEnabled
        }
        if textField.textColor != textColor {
            textField.textColor = textColor
        }

        if isFocused, isEnabled, !isEditing {
            let coordinator = context.coordinator
            Task { @MainActor [weak textField, weak coordinator] in
                guard let textField,
                      let coordinator,
                      textField.window != nil,
                      textField.isEnabled,
                      coordinator.parent.isFocused else { return }
                textField.window?.makeFirstResponder(textField)
            }
        } else if (!isFocused || !isEnabled), isEditing {
            let coordinator = context.coordinator
            Task { @MainActor [weak textField, weak coordinator] in
                guard let textField,
                      let coordinator,
                      textField.window != nil,
                      (!coordinator.parent.isFocused || !textField.isEnabled) else { return }
                textField.window?.makeFirstResponder(nil)
            }
        }
    }

    final class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: WordQuizContinuousTextField
        weak var textField: NSTextField?

        init(parent: WordQuizContinuousTextField) {
            self.parent = parent
        }

        func controlTextDidBeginEditing(_ notification: Notification) {
            if let textField,
               let editor = textField.currentEditor() as? NSTextView {
                // 拼写题必须保留用户原始输入，关闭系统自动修正与替换。
                editor.isAutomaticSpellingCorrectionEnabled = false
                editor.isAutomaticTextReplacementEnabled = false
                editor.isAutomaticTextCompletionEnabled = false
            }
            parent.isFocused = true
        }

        func controlTextDidChange(_ notification: Notification) {
            guard let textField else { return }
            // 编辑期间 field editor 比 stringValue 更新更及时，直接读取可避免末字符滞后。
            parent.text = textField.currentEditor()?.string ?? textField.stringValue
        }

        func controlTextDidEndEditing(_ notification: Notification) {
            guard let textField else { return }
            parent.text = textField.stringValue
            parent.isFocused = false
        }

        func control(
            _ control: NSControl,
            textView: NSTextView,
            doCommandBy commandSelector: Selector
        ) -> Bool {
            let submitsAnswer = commandSelector == #selector(NSResponder.insertNewline(_:))
                || commandSelector == #selector(
                    NSResponder.insertNewlineIgnoringFieldEditor(_:)
                )
            guard submitsAnswer else {
                return false
            }
            parent.text = textView.string
            parent.submit()
            return true
        }
    }
}

struct WordQuizResultView: View {
    @Environment(\.appPalette) private var palette

    let score: Int
    let total: Int
    let hasIncorrectQuestions: Bool
    let retry: () -> Void
    let finish: () -> Void

    var body: some View {
        VStack(spacing: 30) {
            Text("回答正确：\(score) / \(total)")
                .font(.system(size: 38, weight: .semibold, design: .rounded))
                .foregroundStyle(palette.primaryText)
                .monospacedDigit()
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("wordQuiz.result.score")

            HStack(spacing: 20) {
                if hasIncorrectQuestions {
                    Button("再战错题", action: retry)
                        .buttonStyle(.borderedProminent)
                        .tint(palette.calendarAccent)
                        .accessibilityIdentifier("wordQuiz.result.retry")
                }

                if hasIncorrectQuestions {
                    Button("返回", action: finish)
                        .buttonStyle(.bordered)
                        .accessibilityIdentifier("wordQuiz.result.return")
                } else {
                    Button("返回", action: finish)
                        .buttonStyle(.borderedProminent)
                        .tint(palette.calendarAccent)
                        .accessibilityIdentifier("wordQuiz.result.return")
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("wordQuiz.result")
    }
}

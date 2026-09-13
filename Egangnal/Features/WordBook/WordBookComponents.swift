//
//  WordBookComponents.swift
//  Egangnal
//

import SwiftUI

struct WordBookEntryRow: View {
    @Environment(\.appPalette) private var palette

    let entry: WordBookEntrySnapshot
    let frequencyColor: Color
    let emphasizesFrequency: Bool
    let isEditing: Bool
    let isWordVisible: Bool
    let isMeaningVisible: Bool
    let toggleWord: () -> Void
    let toggleMeaning: () -> Void
    let edit: () -> Void
    let delete: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            EqualFieldsLayout(spacing: AppTheme.wordBookFieldSpacing) {
                maskedTextButton(
                    text: entry.term,
                    isVisible: isWordVisible,
                    visibleLabel: wordAccessibilityLabel,
                    hiddenLabel: "单词已隐藏",
                    accessibilityIdentifier: "wordBook.entry.\(entry.id.uuidString).word",
                    action: toggleWord
                )
                .font(.system(size: AppTheme.wordBookEntryFontSize, weight: .semibold))
                .foregroundStyle(termColor)

                maskedTextButton(
                    text: entry.meaning,
                    isVisible: isMeaningVisible,
                    visibleLabel: entry.meaning,
                    hiddenLabel: "释义已隐藏",
                    accessibilityIdentifier: "wordBook.entry.\(entry.id.uuidString).meaning",
                    action: toggleMeaning
                )
                .font(.system(size: AppTheme.wordBookEntryFontSize))
                .foregroundStyle(palette.primaryText)
            }
            .frame(maxWidth: .infinity, alignment: .center)

            if isEditing {
                HStack(spacing: 8) {
                    Button(action: edit) {
                        Image(systemName: "pencil")
                    }
                    .buttonStyle(.borderless)
                    .help("编辑 \(entry.term)")
                    .accessibilityLabel("编辑 \(entry.term)")
                    .accessibilityIdentifier("wordBook.entry.\(entry.id.uuidString).edit")

                    Button(role: .destructive, action: delete) {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.borderless)
                    .help("删除 \(entry.term)")
                    .accessibilityLabel("删除 \(entry.term)")
                    .accessibilityIdentifier("wordBook.entry.\(entry.id.uuidString).delete")
                }
            }
        }
        .frame(
            maxWidth: .infinity,
            minHeight: AppTheme.wordBookEntryMinHeight,
            alignment: .center
        )
        .contentShape(.rect)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("wordBook.entry.\(entry.id.uuidString)")
    }

    private func maskedTextButton(
        text: String,
        isVisible: Bool,
        visibleLabel: String,
        hiddenLabel: String,
        accessibilityIdentifier: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(text)
                .multilineTextAlignment(.center)
                .opacity(0)
                // 遮盖层复用原文字尺寸，切换显隐时不改变网格布局。
                .overlay {
                    if isVisible {
                        Text(text)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity, alignment: .center)
                    } else {
                        RoundedRectangle(cornerRadius: AppTheme.wordBookMaskCornerRadius)
                            .fill(palette.panelRaised)
                            .overlay {
                                RoundedRectangle(
                                    cornerRadius: AppTheme.wordBookMaskCornerRadius
                                )
                                .stroke(palette.border.opacity(0.8), lineWidth: 1)
                            }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isVisible ? visibleLabel : hiddenLabel)
        .accessibilityHint(isVisible ? "点击隐藏" : "点击显示")
        .accessibilityIdentifier(accessibilityIdentifier)
    }

    private var termColor: Color {
        emphasizesFrequency && entry.isHighFrequency ? frequencyColor : palette.primaryText
    }

    private var wordAccessibilityLabel: String {
        emphasizesFrequency && entry.isHighFrequency
            ? "\(entry.term)，高频词"
            : entry.term
    }
}

struct WordBookGuidePopover: View {
    @Environment(\.appPalette) private var palette

    let accent: Color

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "questionmark.circle")
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(accent)

            VStack(alignment: .leading, spacing: 8) {
                Text("请先导出模版，将生词记录到文档后导入单词本；")
                Text("点击单词或词义可隐藏文本协助记忆；")
            }
            .font(.callout)
            .foregroundStyle(palette.guideText)
            .fixedSize(horizontal: true, vertical: false)
        }
        .padding(16)
        .background(palette.guideBackground)
        .clipShape(.rect(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(palette.guideBorder.opacity(0.75), lineWidth: 1)
        }
        .foregroundStyle(palette.guideText)
        .presentationBackground(palette.guideBackground)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "请先导出模版，将生词记录到文档后导入单词本；点击单词或词义可隐藏文本协助记忆；"
        )
        .accessibilityIdentifier("wordBook.guide.content")
    }
}

struct WordBookEmptyState: View {
    @Environment(\.appPalette) private var palette

    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "text.book.closed")
                .font(.system(size: 28, weight: .medium))
                .foregroundStyle(palette.tertiaryText)
            Text(title)
                .font(.headline)
                .foregroundStyle(palette.primaryText)
            Text(message)
                .font(.callout)
                .foregroundStyle(palette.secondaryText)
        }
        .multilineTextAlignment(.center)
        .padding(24)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("wordBook.empty")
    }
}

struct WordBookEditorDraft: Identifiable {
    enum Kind {
        case new
        case existing(UUID)
    }

    let id = UUID()
    let kind: Kind
    let term: String
    let meaning: String

    static let newEntry = WordBookEditorDraft(kind: .new, term: "", meaning: "")

    static func editing(_ entry: WordBookEntrySnapshot) -> Self {
        WordBookEditorDraft(
            kind: .existing(entry.id),
            term: entry.term,
            meaning: entry.meaning
        )
    }
}

struct WordBookEditorSheet: View {
    @Environment(\.appPalette) private var palette

    let draft: WordBookEditorDraft
    let tint: Color
    let save: (String, String) -> String?
    let cancel: () -> Void

    @State private var term: String
    @State private var meaning: String
    @State private var errorMessage: String?

    init(
        draft: WordBookEditorDraft,
        tint: Color,
        save: @escaping (String, String) -> String?,
        cancel: @escaping () -> Void
    ) {
        self.draft = draft
        self.tint = tint
        self.save = save
        self.cancel = cancel
        _term = State(initialValue: draft.term)
        _meaning = State(initialValue: draft.meaning)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text(title)
                .font(.title2.weight(.semibold))
                .foregroundStyle(palette.primaryText)

            VStack(alignment: .leading, spacing: 8) {
                Text("单词")
                    .font(.callout.weight(.medium))
                    .foregroundStyle(palette.secondaryText)
                TextField("请输入单词", text: $term)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityIdentifier("wordBook.editor.term")
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("中文意思")
                    .font(.callout.weight(.medium))
                    .foregroundStyle(palette.secondaryText)
                TextField("请输入中文意思", text: $meaning, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(2...4)
                    .accessibilityIdentifier("wordBook.editor.meaning")
            }

            Group {
                if let errorMessage {
                    Label(errorMessage, systemImage: "exclamationmark.circle")
                        .foregroundStyle(.red)
                }
            }
            .font(.callout)
            .frame(maxWidth: .infinity, minHeight: 22, alignment: .leading)

            HStack {
                Spacer()
                Button("取消", action: cancel)
                    .keyboardShortcut(.cancelAction)
                    .accessibilityIdentifier("wordBook.editor.cancel")
                Button("保存") {
                    errorMessage = save(term, meaning)
                }
                .buttonStyle(.borderedProminent)
                .tint(tint)
                .keyboardShortcut(.defaultAction)
                .accessibilityIdentifier("wordBook.editor.save")
            }
        }
        .padding(24)
        .frame(width: 420)
        .background(palette.panel)
    }

    private var title: String {
        switch draft.kind {
        case .new:
            "新增单词"
        case .existing:
            "编辑单词"
        }
    }
}

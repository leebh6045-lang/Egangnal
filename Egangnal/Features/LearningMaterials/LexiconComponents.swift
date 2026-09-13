//
//  LexiconComponents.swift
//  Egangnal
//

import SwiftUI

/// 上报每个词块在网格坐标空间中的位置，供悬停浮层定位使用。
struct LexiconCellFramePreferenceKey: PreferenceKey {
    static let defaultValue: [UUID: CGRect] = [:]

    static func reduce(value: inout [UUID: CGRect], nextValue: () -> [UUID: CGRect]) {
        value.merge(nextValue()) { _, latest in latest }
    }
}

/// 上报浮层自身尺寸，用于把它完整地收在窗口内。
struct LexiconTooltipSizePreferenceKey: PreferenceKey {
    static let defaultValue: CGSize = .zero

    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        let next = nextValue()
        if next != .zero {
            value = next
        }
    }
}

// MARK: - 标题行与分隔线

struct LexiconHeaderRow: View {
    @Environment(\.appPalette) private var palette

    let title: String
    let resultCount: Int
    /// 搜索时顺序由词频决定，换一批没有可见效果，因此隐藏按钮。
    let canReshuffle: Bool
    let reshuffle: () -> Void
    let openDashboard: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: openDashboard) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 17, weight: .semibold))
                    .frame(width: 32, height: 32, alignment: .leading)
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.escape, modifiers: [])
            .help("返回总览")
            .accessibilityLabel("返回总览")
            .accessibilityIdentifier("workspace.lexicon.back")

            Text(title)
                .font(.title3.weight(.semibold))
                .foregroundStyle(palette.primaryText)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("lexicon.title")

            Spacer(minLength: 16)

            if canReshuffle {
                Button(action: reshuffle) {
                    HStack(spacing: 5) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 12, weight: .medium))
                        Text("换一批")
                            .font(.system(size: 13))
                    }
                    .foregroundStyle(palette.secondaryText)
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .help("换一批单词")
                .accessibilityLabel("换一批单词")
                .accessibilityIdentifier("lexicon.reshuffle")
            }

            Text(Self.formattedCount(resultCount))
                .font(.system(size: AppTheme.lexiconResultCountFontSize))
                .monospacedDigit()
                .foregroundStyle(palette.secondaryText)
                .accessibilityLabel(Self.formattedCount(resultCount))
                .accessibilityIdentifier("lexicon.resultCount")
        }
        .padding(.horizontal, AppTheme.contentPadding)
        .frame(height: 48)
    }

    /// 千分位，让“海量”有实感。
    static func formattedCount(_ count: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        // en_US_POSIX 不做千位分组，这里需要的是展示格式。
        formatter.locale = Locale(identifier: "en_US")
        let text = formatter.string(from: NSNumber(value: count)) ?? String(count)
        return "\(text) 条"
    }
}

/// 检索区上下的分隔线：中间粗、两端细，两端再淡出。
struct LexiconSeparator: View {
    @Environment(\.appPalette) private var palette

    var body: some View {
        LexiconTaperedRule()
            .fill(palette.border.opacity(0.55))
            .frame(height: AppTheme.lexiconSeparatorThickness)
            .mask {
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0),
                        .init(color: .black, location: 0.16),
                        .init(color: .black, location: 0.84),
                        .init(color: .clear, location: 1)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            }
            .accessibilityHidden(true)
    }
}

private struct LexiconTaperedRule: Shape {
    func path(in rect: CGRect) -> Path {
        let midY = rect.midY
        let maximum = rect.height
        let minimum = max(rect.height * 0.3, 0.5)

        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: midY - minimum / 2))
        path.addLine(to: CGPoint(x: rect.midX, y: midY - maximum / 2))
        path.addLine(to: CGPoint(x: rect.maxX, y: midY - minimum / 2))
        path.addLine(to: CGPoint(x: rect.maxX, y: midY + minimum / 2))
        path.addLine(to: CGPoint(x: rect.midX, y: midY + maximum / 2))
        path.addLine(to: CGPoint(x: rect.minX, y: midY + minimum / 2))
        path.closeSubpath()
        return path
    }
}

// MARK: - 检索区

struct LexiconFilterBar: View {
    @Environment(\.appPalette) private var palette

    let selectedLevel: VocabularyLevel?
    @Binding var keyword: String
    let accent: Color
    let selectLevel: (VocabularyLevel?) -> Void

    var body: some View {
        HStack(spacing: 0) {
            HStack(spacing: 22) {
                levelButton(nil, title: "全部")
                ForEach(VocabularyLevel.allCases) { level in
                    levelButton(level, title: level.title)
                }
            }

            Spacer(minLength: 20)

            LexiconSearchField(keyword: $keyword)
        }
        // 收窄到居中的一条带：筛选与搜索彼此靠近，整体居中。
        .frame(maxWidth: AppTheme.lexiconFilterBandMaxWidth)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, AppTheme.contentPadding)
        .frame(height: 52)
    }

    private func levelButton(_ level: VocabularyLevel?, title: String) -> some View {
        let isSelected = level == selectedLevel
        return Button {
            selectLevel(level)
        } label: {
            // 下划线用覆盖层画在文字下方：如果放进 VStack 会抬高文字，
            // 导致筛选与搜索框不在同一基线上。
            Text(title)
                .font(
                    .system(
                        size: AppTheme.lexiconFilterFontSize,
                        weight: isSelected ? .semibold : .regular
                    )
                )
                .foregroundStyle(isSelected ? accent : palette.secondaryText)
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(isSelected ? accent : Color.clear)
                        .frame(height: AppTheme.lexiconFilterUnderlineHeight)
                        .offset(y: 7)
                }
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityValue(isSelected ? "已选择" : "未选择")
        .accessibilityIdentifier(
            level.map { "lexicon.filter.\($0.rawValue)" } ?? "lexicon.filter.all"
        )
    }
}

struct LexiconSearchField: View {
    @Environment(\.appPalette) private var palette

    @Binding var keyword: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(palette.tertiaryText)

            TextField("输入单词、首字母或中文意思", text: $keyword)
                .textFieldStyle(.plain)
                .font(.system(size: AppTheme.lexiconSearchFontSize))
                .foregroundStyle(palette.primaryText)
                .accessibilityIdentifier("lexicon.search")
        }
        .frame(maxWidth: 300)
    }
}

// MARK: - 词块

/// 一个词块：单词在上、词性词义在下，两行居中。
///
/// 与单词本的四栏横排不同，词库的释义带上词性前缀后更长，需要整列宽度。
struct LexiconEntryCell: View {
    @Environment(\.appPalette) private var palette

    let entry: LexiconEntry
    let display: LexiconGlossDisplay
    let keyword: String
    let searchMode: LexiconSearchMode
    let accent: Color
    let isTermMasked: Bool
    let isGlossMasked: Bool
    /// 鼠标是否停在本词块上（立即生效，不等悬停延迟）。
    let isHovered: Bool
    /// 该词相对“词库收藏”的状态。
    let collectionState: LexiconCollectionState
    let toggleTerm: () -> Void
    let toggleGloss: () -> Void
    let collect: () -> Void
    /// 只有悬浮在词性词义上才考虑弹出浮层，避免光标经过时随处误触发。
    let glossHoverChanged: (Bool) -> Void

    var body: some View {
        // 单词在左、词性词义在右，两个字段等宽；网格每行两个词条，
        // 合起来就是单词本那样的四等分横向排布。
        HStack(spacing: 6) {
            EqualFieldsLayout(spacing: AppTheme.lexiconEntryFieldSpacing) {
                maskedField(
                    isMasked: isTermMasked,
                    visibleLabel: entry.term,
                    hiddenLabel: "单词已隐藏",
                    identifier: "lexicon.entry.\(entry.id.uuidString).word",
                    color: termColor,
                    action: toggleTerm
                ) {
                    Text(highlightedTerm)
                }
                .font(.system(size: AppTheme.lexiconEntryTermFontSize, weight: .semibold))

                maskedField(
                    isMasked: isGlossMasked,
                    // 读屏读完整释义与音标：视觉上的短释义与浮层里的音标
                    // 对读屏用户都不可用，必须在这里补齐。
                    visibleLabel: meaningAccessibilityLabel,
                    hiddenLabel: "释义已隐藏",
                    identifier: "lexicon.entry.\(entry.id.uuidString).meaning",
                    color: palette.primaryText,
                    action: toggleGloss
                ) {
                    Text(highlightedGloss)
                }
                .font(.system(size: AppTheme.lexiconEntryGlossFontSize))
                .onHover(perform: glossHoverChanged)
            }
            .frame(maxWidth: .infinity, alignment: .center)

            // 与词条同一行、垂直居中；宽度常驻，显隐时不推动词条。
            collectButton
                .frame(width: AppTheme.lexiconCollectButtonWidth)
        }
        .frame(
            maxWidth: .infinity,
            minHeight: AppTheme.lexiconEntryMinHeight,
            alignment: .center
        )
        .contentShape(.rect)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("lexicon.entry.\(entry.id.uuidString)")
        // 收录按钮只在悬停时可见，键盘与 VoiceOver 无法悬停，
        // 因此把同一个动作挂到词块上，保证辅助技术始终能够收录。
        .accessibilityAction(named: Text(collectLabel)) {
            collect()
        }
    }

    private var meaningAccessibilityLabel: String {
        guard let phonetic = entry.displayPhonetic else { return entry.gloss }
        return "\(entry.gloss)，音标 \(phonetic)"
    }

    private var isCollected: Bool {
        collectionState == .collected
    }

    /// 只要词在个人单词本里（含文档导入与手动新增）就用标记色。
    private var isInWordBook: Bool {
        collectionState != .notInWordBook
    }

    /// 已收录的单词用标记色，一眼可辨。
    private var termColor: Color {
        isInWordBook ? palette.collectedAccent : palette.primaryText
    }

    private var isCollectControlVisible: Bool {
        isInWordBook || isHovered
    }

    private var collectSymbol: String {
        switch collectionState {
        case .notInWordBook: "plus.circle"
        case .collected: "checkmark.circle.fill"
        case .managedInWordBook: "checkmark.circle"
        }
    }

    private var collectLabel: String {
        switch collectionState {
        case .notInWordBook: "加入单词本"
        case .collected: "取消收藏"
        case .managedInWordBook: "已在单词本"
        }
    }

    private var collectButton: some View {
        Button(action: collect) {
            Image(systemName: collectSymbol)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(
                    collectionState == .notInWordBook
                        ? palette.secondaryText
                        : palette.collectedAccent
                )
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .opacity(isCollectControlVisible ? 1 : 0)
        // 不可见时绝不能拦截点击，否则会挡住单词本身的遮盖切换。
        .allowsHitTesting(isCollectControlVisible)
        .help(collectLabel)
        .accessibilityLabel(collectLabel)
        .accessibilityIdentifier("lexicon.entry.\(entry.id.uuidString).collect")
    }

    /// 遮盖块复用原文字尺寸，切换显隐时网格布局不跳动。
    ///
    /// 关键在修饰顺序：遮罩必须贴在**文字自身**上，最后才用 `frame` 撑开占位。
    /// 反过来先撑开再遮罩，遮盖块就会铺满整个字段，看起来像一条黑条。
    private func maskedField<Content: View>(
        isMasked: Bool,
        visibleLabel: String,
        hiddenLabel: String,
        identifier: String,
        color: Color,
        action: @escaping () -> Void,
        @ViewBuilder content: () -> Content
    ) -> some View {
        Button(action: action) {
            content()
                .multilineTextAlignment(.center)
                .lineLimit(1)
                .truncationMode(.tail)
                .foregroundStyle(color)
                .opacity(0)
                .overlay {
                    if isMasked {
                        RoundedRectangle(cornerRadius: AppTheme.wordBookMaskCornerRadius)
                            .fill(palette.panelRaised)
                            .overlay {
                                RoundedRectangle(
                                    cornerRadius: AppTheme.wordBookMaskCornerRadius
                                )
                                .stroke(palette.border.opacity(0.8), lineWidth: 1)
                            }
                            // 遮盖块贴合文字长度，短词只遮一小段。
                            .padding(.horizontal, -6)
                    } else {
                        // 可见副本必须自己上色：`.foregroundStyle` 是环境值，
                        // 不会传播到后加的 overlay 内容里，漏掉就会一直用默认色
                        // （表现就是"已收藏的单词没有变黄"）。
                        content()
                            .multilineTextAlignment(.center)
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .foregroundStyle(color)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .center)
                // 让整个字段区域都可点击/可悬停，而不是只有文字笔画上才算。
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isMasked ? hiddenLabel : visibleLabel)
        .accessibilityHint(isMasked ? "点击显示" : "点击隐藏")
        .accessibilityIdentifier(identifier)
    }

    // MARK: - 高亮

    private var highlightedTerm: AttributedString {
        // 已收录时整词已是标记色，再叠前缀高亮会分不清哪个状态在生效。
        guard !isInWordBook, searchMode == .englishPrefix else {
            return AttributedString(entry.term)
        }
        let length = min(
            WordNormalizer.normalizedTerm(keyword, in: .english).count,
            entry.term.count
        )
        guard length > 0 else { return AttributedString(entry.term) }
        let end = entry.term.index(entry.term.startIndex, offsetBy: length)
        return Self.highlighted(
            entry.term,
            ranges: [entry.term.startIndex..<end],
            accent: accent
        )
    }

    private var highlightedGloss: AttributedString {
        guard searchMode == .chineseMeaning else {
            return AttributedString(display.text)
        }
        let tokens = keyword
            .split(whereSeparator: \.isWhitespace)
            .map(String.init)
            .filter { !$0.isEmpty }
        return Self.highlighted(
            display.text,
            ranges: Self.matchedRanges(in: display.text, tokens: tokens),
            accent: accent
        )
    }

    static func highlighted(
        _ text: String,
        ranges: [Range<String.Index>],
        accent: Color
    ) -> AttributedString {
        var attributed = AttributedString(text)
        for range in ranges {
            guard let attributeRange = Range(range, in: attributed) else { continue }
            attributed[attributeRange].foregroundColor = accent
        }
        return attributed
    }

    static func matchedRanges(in text: String, tokens: [String]) -> [Range<String.Index>] {
        var ranges: [Range<String.Index>] = []
        for token in tokens {
            var cursor = text.startIndex
            while cursor < text.endIndex,
                  let found = text.range(of: token, range: cursor..<text.endIndex) {
                ranges.append(found)
                cursor = found.upperBound
            }
        }
        return ranges
    }
}

// MARK: - 悬停浮层

struct LexiconTooltip: View {
    @Environment(\.appPalette) private var palette

    let entry: LexiconEntry
    let showsFullGloss: Bool
    /// 词库收藏的日期；非空时浮层显示已收藏标记。
    let collectedDates: [VocabularyDocumentDate]

    var body: some View {
        VStack(spacing: 10) {
            if let phonetic = entry.displayPhonetic {
                Text(phonetic)
                    .font(.system(size: 22, design: .monospaced))
                    .foregroundStyle(palette.primaryText)
                    .accessibilityIdentifier("lexicon.tooltip.phonetic")
            }

            if showsFullGloss {
                Text(entry.gloss)
                    .font(.system(size: 16))
                    .foregroundStyle(palette.secondaryText)
                    .multilineTextAlignment(.center)
                    .lineLimit(6)
                    .accessibilityIdentifier("lexicon.tooltip.gloss")
            }

            // 等级总是显示，保证浮层永远有内容。
            Text(entry.levels.map(\.title).joined(separator: " · "))
                .font(.system(size: 13))
                .foregroundStyle(palette.tertiaryText)
                .accessibilityIdentifier("lexicon.tooltip.levels")

            if !collectedDates.isEmpty {
                Text("已收藏 · \(collectedDates.map(\.templateText).joined(separator: "、"))")
                    .font(.system(size: 13))
                    .foregroundStyle(palette.collectedAccent)
                    .accessibilityIdentifier("lexicon.tooltip.collected")
            }
        }
        .padding(16)
        .frame(
            minWidth: AppTheme.lexiconTooltipMinWidth,
            maxWidth: AppTheme.lexiconTooltipMaxWidth
        )
        .background(palette.panel, in: .rect(cornerRadius: 10))
        .overlay {
            RoundedRectangle(cornerRadius: 10)
                .stroke(palette.border, lineWidth: 1)
        }
        .shadow(color: palette.panelShadow, radius: 14, y: 6)
        .accessibilityHidden(true)
    }
}

// MARK: - 分页与空状态

struct LexiconPaginationBar: View {
    @Environment(\.appPalette) private var palette

    let page: LexiconPage
    let goToPrevious: () -> Void
    let goToNext: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            if page.pageCount > 0 {
                Button(action: goToPrevious) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 13, weight: .semibold))
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .disabled(!page.hasPreviousPage)
                .foregroundStyle(
                    page.hasPreviousPage ? palette.primaryText : palette.tertiaryText
                )
                .accessibilityLabel("上一页")
                .accessibilityIdentifier("lexicon.pagination.previous")

                Text(statusText)
                    .font(.system(size: AppTheme.lexiconPaginationFontSize))
                    .monospacedDigit()
                    .foregroundStyle(palette.tertiaryText)
                    .accessibilityIdentifier("lexicon.pagination.status")

                Button(action: goToNext) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .disabled(!page.hasNextPage)
                .foregroundStyle(
                    page.hasNextPage ? palette.primaryText : palette.tertiaryText
                )
                .accessibilityLabel("下一页")
                .accessibilityIdentifier("lexicon.pagination.next")
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 44)
    }

    private var statusText: String {
        "第 \(page.pageIndex + 1) / \(page.pageCount) 页 · "
            + "\(page.firstItemNumber)–\(page.lastItemNumber) 条"
    }
}

struct LexiconEmptyState: View {
    @Environment(\.appPalette) private var palette

    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "text.magnifyingglass")
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
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("lexicon.empty")
    }
}

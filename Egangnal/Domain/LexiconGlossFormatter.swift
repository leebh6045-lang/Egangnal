//
//  LexiconGlossFormatter.swift
//  Egangnal
//

import Foundation

/// 浏览列表的释义展示结果。
struct LexiconGlossDisplay: Equatable, Sendable {
    let text: String
    /// 完整释义是否比显示的更多。悬停浮层据此决定要不要再显示一遍完整内容。
    let isTruncated: Bool
}

/// 把词库的长释义压缩成适合单词刷选项的短释义。
///
/// 词库释义中位 26 字符、p90 53、最长 191，且包含多行、领域标注（如 `[计]`、`[古]`）
/// 和语法说明行（如 `run的过去式和过去分词`）。直接放进固定尺寸的四选一按钮会溢出，
/// 因此需要一条确定、可版本化、可单测的派生规则。
///
/// 本类型只负责"把一条释义变短"，不负责"避免同一题内选项撞车"——后者属于组卷逻辑。
enum LexiconGlossFormatter {
    /// 规则变化时必须提升版本号，并同步更新单元测试样例。
    static let version = "gloss-v1"
    /// 单词刷四选一选项可用长度。
    static let defaultMaximumLength = 12
    /// 词库浏览列表一行可容纳的长度。
    ///
    /// 词块从"上下两行、占半窗宽"改成"左右两栏、各占四分之一窗宽"之后，
    /// 一行能放下的字数明显变少，因此由 16 收紧到 12；实际仍由视图按宽度兜底截断。
    static let defaultBrowsingLength = 12

    /// 允许被剥离的词性前缀。
    ///
    /// 必须包含单字母缩写：ECDICT 用 `a.` 表示形容词（不是 `adj.`），
    /// 漏掉它会把大量形容词误判成"没有词性前缀"。
    private static let partOfSpeechTokens: Set<String> = [
        "n", "v", "vt", "vi", "adj", "adv", "ad", "a",
        "prep", "pron", "conj", "interj", "int", "num",
        "art", "aux", "abbr", "pl", "sing"
    ]

    private static let senseSeparators: Set<Character> = ["；", ";", ","]

    private static let trimmingCharacters: CharacterSet = {
        var set = CharacterSet.whitespaces
        set.formUnion(CharacterSet(charactersIn: "、。．.,;；:："))
        return set
    }()

    /// 派生短释义。输入为空或全是空白时返回空字符串，由调用方决定如何兜底。
    static func shortGloss(
        from translation: String,
        maximumLength: Int = defaultMaximumLength
    ) -> String {
        let lines = translation
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        guard let firstLine = lines.first else { return "" }

        // 优先取第一条"词性 + 释义"；领域标注行（剥离后以 `[` 开头）不能作为首选，
        // 否则 `a` 这类词的短释义会变成 `[计] 累加器`。
        let preferred = lines
            .compactMap(strippingPartOfSpeech)
            .first { !$0.hasPrefix("[") }

        // 找不到合格行时退回第一行且不剥离前缀，避免产出空释义。
        let base = preferred ?? firstLine

        let sense = base
            .split(whereSeparator: { senseSeparators.contains($0) })
            .map { $0.trimmingCharacters(in: trimmingCharacters) }
            .first { !$0.isEmpty } ?? base

        let collapsed = sense
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
            .trimmingCharacters(in: trimmingCharacters)

        return truncated(collapsed, maximumLength: maximumLength)
    }

    /// 词库浏览列表使用的显示释义：**保留词性前缀**，按完整义项累加，超长时截断。
    ///
    /// 与 `shortGloss` 的区别有两点：保留 `vt.` 这类前缀（它本身就是词库与单词本
    /// 最明显的视觉差异），以及以"完整义项"为单位累加，避免把义项切成半个词。
    /// 返回 `isTruncated` 供悬停浮层判断是否需要补显示完整内容。
    static func browsingDisplay(
        from translation: String,
        maximumLength: Int = defaultBrowsingLength
    ) -> LexiconGlossDisplay {
        let lines = translation
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        guard let firstLine = lines.first else {
            return LexiconGlossDisplay(text: "", isTruncated: false)
        }

        let hasMoreLines = lines.count > 1

        // 找不到"词性 + 释义"行时保留原文并按字符硬截断，不改写标点。
        guard let line = lines.first(where: { candidate in
            guard let stripped = strippingPartOfSpeech(candidate) else { return false }
            return !stripped.hasPrefix("[")
        }), let split = splitPartOfSpeech(line) else {
            let text = truncated(firstLine, maximumLength: maximumLength)
            return display(text: text, isTruncated: hasMoreLines || text != firstLine)
        }

        let senses = split.remainder
            .components(separatedBy: CharacterSet(charactersIn: ",，;；"))
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        guard !senses.isEmpty else {
            let text = truncated(line, maximumLength: maximumLength)
            return display(text: text, isTruncated: hasMoreLines || text != line)
        }

        var text = split.prefix
        var consumed = 0
        for (index, sense) in senses.enumerated() {
            let candidate = text + (index == 0 ? " " : ", ") + sense
            // 至少保留第一个义项，即使它本身就已经超长。
            if candidate.count > maximumLength, index > 0 {
                break
            }
            text = candidate
            consumed = index + 1
        }

        var isTruncated = hasMoreLines || consumed < senses.count
        let bounded = truncated(text, maximumLength: maximumLength)
        if bounded != text {
            text = bounded
            isTruncated = true
        }
        return display(text: text, isTruncated: isTruncated)
    }

    /// 还有更多内容时补一个省略号：否则用户看不出可以悬停查看完整释义。
    private static func display(text: String, isTruncated: Bool) -> LexiconGlossDisplay {
        guard isTruncated, !text.hasSuffix("…") else {
            return LexiconGlossDisplay(text: text, isTruncated: isTruncated)
        }
        return LexiconGlossDisplay(text: text + "…", isTruncated: true)
    }

    /// 剥离行首词性前缀；不是"词性 + 释义"形态时返回 nil。
    private static func strippingPartOfSpeech(_ line: String) -> String? {
        splitPartOfSpeech(line)?.remainder
    }

    /// 拆分"词性 + 释义"行，同时返回原始前缀写法（如 `vt.`、`A.`）。
    private static func splitPartOfSpeech(
        _ line: String
    ) -> (prefix: String, remainder: String)? {
        guard let separatorIndex = line.firstIndex(where: { $0 == "." || $0 == "．" }) else {
            return nil
        }
        let token = line[line.startIndex..<separatorIndex]
            .trimmingCharacters(in: .whitespaces)
            .lowercased(with: Locale(identifier: "en_US_POSIX"))
        // 词性缩写都很短，长度限制可以挡掉把句中普通句点误判成前缀的情况。
        guard !token.isEmpty, token.count <= 4, partOfSpeechTokens.contains(token) else {
            return nil
        }
        let remainder = line[line.index(after: separatorIndex)...]
            .trimmingCharacters(in: .whitespaces)
        guard !remainder.isEmpty else { return nil }

        return (String(line[line.startIndex...separatorIndex]), remainder)
    }

    private static func truncated(_ text: String, maximumLength: Int) -> String {
        guard maximumLength > 0, text.count > maximumLength else { return text }
        // 截断点可能正好落在分隔符上，先去掉尾随标点再补省略号。
        let head = String(text.prefix(maximumLength))
            .trimmingCharacters(in: trimmingCharacters)
        return head + "…"
    }
}

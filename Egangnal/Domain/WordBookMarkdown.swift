//
//  WordBookMarkdown.swift
//  Egangnal
//

import Foundation

enum WordBookTemplateGenerator {
    static let entrySeparatorPadding = String(repeating: " ", count: 6)
    // 新模板让用户直接在双竖线左侧输入单词，避免光标破坏左侧占位空格。
    static let entrySeparator = "｜｜\(entrySeparatorPadding)"
    static let legacyEntrySeparator = "\(entrySeparatorPadding)｜｜\(entrySeparatorPadding)"
    static let legacyShortEntrySeparatorPadding = String(repeating: " ", count: 3)
    static let legacyShortEntrySeparator = "\(legacyShortEntrySeparatorPadding)｜｜\(legacyShortEntrySeparatorPadding)"
    static let instructionText = "(请在双竖线左侧直接填写单词，右侧填写中文意思；每行填写一条，完成后保存并导入单词本。)"
    static let legacyInstructionText = "(请在每行双竖线左侧填写单词，右侧填写中文意思；每行填写一条，完成后保存并导入单词本。)"
    static let placeholderEntryCount = 20

    static func makeTemplate(
        for date: Date = .now,
        calendar: Calendar = .current
    ) -> String {
        let sourceDate = VocabularyDocumentDate(date: date, calendar: calendar)
        let placeholderEntries = Array(
            repeating: entrySeparator,
            count: placeholderEntryCount
        ).joined(separator: "\n")
        return "\(sourceDate.templateText)\n\n\n\(instructionText)\n\n\n\(placeholderEntries)\n"
    }

    static func makeTemplateData(
        for date: Date = .now,
        calendar: Calendar = .current
    ) -> Data {
        Data(makeTemplate(for: date, calendar: calendar).utf8)
    }
}

enum WordBookMarkdownError: Error, Equatable, LocalizedError {
    case invalidUTF8
    case missingDate
    case invalidDate(line: String)
    case missingRequiredBlankLines
    case invalidEntry(lineNumber: Int)
    case emptyTerm(lineNumber: Int)
    case emptyMeaning(lineNumber: Int)
    case noEntries

    var errorDescription: String? {
        switch self {
        case .invalidUTF8:
            "文档不是有效的 UTF-8 编码。"
        case .missingDate:
            "文档缺少首行日期。"
        case let .invalidDate(line):
            "日期“\(line)”不符合 yyyy年MM月dd日 格式。"
        case .missingRequiredBlankLines:
            "日期后必须保留两行空行。"
        case let .invalidEntry(lineNumber):
            "第 \(lineNumber) 行不符合“单词｜｜      中文意思”格式。"
        case let .emptyTerm(lineNumber):
            "第 \(lineNumber) 行的单词不能为空。"
        case let .emptyMeaning(lineNumber):
            "第 \(lineNumber) 行的中文意思不能为空。"
        case .noEntries:
            "文档中没有可导入的单词。"
        }
    }
}

enum WordBookMarkdownParser {
    static func parse(_ data: Data) throws -> ParsedWordDocument {
        guard var text = String(data: data, encoding: .utf8) else {
            throw WordBookMarkdownError.invalidUTF8
        }

        if text.first == "\u{FEFF}" {
            text.removeFirst()
        }

        text = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")

        let lines = text.components(separatedBy: "\n")
        guard let dateLine = lines.first, !dateLine.isEmpty else {
            throw WordBookMarkdownError.missingDate
        }
        guard let sourceDate = parseDate(dateLine) else {
            throw WordBookMarkdownError.invalidDate(line: dateLine)
        }
        guard lines.count >= 4,
              lines[1].trimmingCharacters(in: .whitespaces).isEmpty,
              lines[2].trimmingCharacters(in: .whitespaces).isEmpty else {
            throw WordBookMarkdownError.missingRequiredBlankLines
        }

        var words: [ParsedWord] = []
        var entryRowNumber = 0
        for line in lines.dropFirst(3) {
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)
            if trimmedLine.isEmpty
                || trimmedLine == WordBookTemplateGenerator.instructionText
                || trimmedLine == WordBookTemplateGenerator.legacyInstructionText {
                continue
            }

            entryRowNumber += 1
            // 导出模版的空双竖线只是占位，不应被当成空单词报错。
            if trimmedLine == "｜｜" {
                continue
            }

            guard let separator = [
                WordBookTemplateGenerator.entrySeparator,
                WordBookTemplateGenerator.legacyEntrySeparator,
                WordBookTemplateGenerator.legacyShortEntrySeparator
            ].first(where: line.contains) else {
                throw WordBookMarkdownError.invalidEntry(lineNumber: entryRowNumber)
            }
            let parts = line.components(separatedBy: separator)
            guard parts.count == 2 else {
                throw WordBookMarkdownError.invalidEntry(lineNumber: entryRowNumber)
            }

            let term = parts[0].trimmingCharacters(in: .whitespaces)
            let meaning = parts[1].trimmingCharacters(in: .whitespaces)
            if term.isEmpty && meaning.isEmpty {
                continue
            }
            guard !term.isEmpty else {
                throw WordBookMarkdownError.emptyTerm(lineNumber: entryRowNumber)
            }
            guard !meaning.isEmpty else {
                throw WordBookMarkdownError.emptyMeaning(lineNumber: entryRowNumber)
            }

            words.append(ParsedWord(term: term, meaning: meaning, lineNumber: entryRowNumber))
        }

        guard !words.isEmpty else {
            throw WordBookMarkdownError.noEntries
        }
        return ParsedWordDocument(sourceDate: sourceDate, words: words)
    }

    private static func parseDate(_ line: String) -> VocabularyDocumentDate? {
        let characters = Array(line)
        guard characters.count == 11,
              characters[4] == "年",
              characters[7] == "月",
              characters[10] == "日",
              let year = Int(String(characters[0..<4])),
              let month = Int(String(characters[5..<7])),
              let day = Int(String(characters[8..<10])) else {
            return nil
        }
        return VocabularyDocumentDate(year: year, month: month, day: day)
    }
}

enum WordNormalizer {
    static func normalizedTerm(_ term: String, in space: LanguageSpace) -> String {
        let collapsed = term
            .split(whereSeparator: \Character.isWhitespace)
            .joined(separator: " ")
            .precomposedStringWithCanonicalMapping

        switch space {
        case .english:
            return collapsed.lowercased(with: Locale(identifier: "en_US_POSIX"))
        case .japanese:
            return collapsed
        }
    }

    static func identityKey(for normalizedTerm: String, in space: LanguageSpace) -> String {
        // 单词来自单行文本，换行可作为不会与合法单词冲突的稳定边界。
        "\(space.rawValue)\n\(normalizedTerm)"
    }
}

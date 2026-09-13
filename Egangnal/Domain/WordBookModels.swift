//
//  WordBookModels.swift
//  Egangnal
//

import Foundation
import SwiftData

struct VocabularyDocumentDate: Hashable, Comparable, Sendable {
    let year: Int
    let month: Int
    let day: Int

    init?(year: Int, month: Int, day: Int) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let components = DateComponents(
            calendar: calendar,
            timeZone: calendar.timeZone,
            year: year,
            month: month,
            day: day
        )

        guard let date = calendar.date(from: components) else { return nil }
        let verified = calendar.dateComponents([.year, .month, .day], from: date)
        guard verified.year == year, verified.month == month, verified.day == day else {
            return nil
        }

        self.year = year
        self.month = month
        self.day = day
    }

    init(date: Date, calendar: Calendar = .current) {
        // 模板协议固定使用公历；只借用系统日历的时区，避免佛教历等设置改变文件格式。
        var gregorian = Calendar(identifier: .gregorian)
        gregorian.timeZone = calendar.timeZone
        let components = gregorian.dateComponents([.year, .month, .day], from: date)
        precondition(
            components.year != nil && components.month != nil && components.day != nil,
            "无法从给定日期读取年月日"
        )
        self.year = components.year!
        self.month = components.month!
        self.day = components.day!
    }

    var storageKey: String {
        String(format: "%04d-%02d-%02d", year, month, day)
    }

    var templateText: String {
        String(format: "%04d年%02d月%02d日", year, month, day)
    }

    static func < (lhs: Self, rhs: Self) -> Bool {
        (lhs.year, lhs.month, lhs.day) < (rhs.year, rhs.month, rhs.day)
    }
}

struct ParsedWord: Equatable, Sendable {
    let term: String
    let meaning: String
    // 行号从第一条双竖线占位行开始计算，不包含日期、说明和空行。
    let lineNumber: Int
}

struct ParsedWordDocument: Equatable, Sendable {
    let sourceDate: VocabularyDocumentDate
    let words: [ParsedWord]
}

/// 个人词条的来源。
///
/// 三种来源产生同样的 `WordEntry`，但语义不同，决定它是否参与日期分组与高频统计：
/// - `markdownImport`：由 Markdown 文档导入，带文档日期，参与高频词判断；
/// - `lexiconCollection`：从公共词库收藏，**没有文档日期**，永不参与高频统计；
/// - `manual`：在单词本里手动新增，同样没有文档日期。
enum WordEntrySource: String, CaseIterable, Sendable {
    case markdownImport
    case lexiconCollection
    case manual

    var title: String {
        switch self {
        case .markdownImport: "文档导入"
        case .lexiconCollection: "词库收藏"
        case .manual: "手动新增"
        }
    }
}

struct WordBookEntrySnapshot: Identifiable, Equatable, Sendable {
    let id: UUID
    let term: String
    let meaning: String
    let source: WordEntrySource
    let occurrenceDates: [VocabularyDocumentDate]

    var isHighFrequency: Bool {
        occurrenceDates.count >= 2
    }

    /// 没有文档日期的词条在日期模式下归入“未归档单词”。
    var isUnarchived: Bool {
        occurrenceDates.isEmpty
    }
}

struct WordBookImportResult: Equatable, Sendable {
    let insertedEntryCount: Int
    let insertedOccurrenceCount: Int
    let skippedDuplicateCount: Int

    var madeChanges: Bool {
        insertedOccurrenceCount > 0
    }
}

/// 从词库收藏一个词条的结果。
enum WordBookCollectionOutcome: Equatable, Sendable {
    /// 新建了个人词条，或为今天补上了收录记录。
    case inserted
    /// 今天已经收藏过这个词。
    case alreadyExists
    /// 撤销收藏：词条只来自词库收藏，已整体删除。
    case removed
    /// 撤销收藏：只移除了词库收藏记录，词条因另有文档导入或手动来源而保留。
    case removedCollectionOnly
    /// 该词从未从词库收藏过。
    case notCollected
    /// 该词在单词本中，但来自文档导入或手动新增，不能在词库取消。
    case managedInWordBook
}

/// 词条在个人单词本中的状态与收藏日期，供词库界面显示。
struct LexiconCollectionInfo: Equatable, Sendable {
    let state: LexiconCollectionState
    /// 词库收藏产生的日期，倒序。
    let collectedDates: [VocabularyDocumentDate]

    static let notInWordBook = LexiconCollectionInfo(
        state: .notInWordBook,
        collectedDates: []
    )
}

/// 词条相对"词库收藏"的状态，用于决定收录按钮的图标与可点击性。
enum LexiconCollectionState: Equatable, Sendable {
    /// 不在单词本中，可以收藏。
    case notInWordBook
    /// 在单词本中且有词库收藏记录，可以取消收藏。
    case collected
    /// 在单词本中，但只来自文档导入或手动新增，不能在词库取消。
    case managedInWordBook
}

@Model
final class WordEntry {
    @Attribute(.unique) var id: UUID
    @Attribute(.unique) var identityKey: String
    var languageSpaceID: String
    var term: String
    var normalizedTerm: String
    var meaning: String
    /// 迁移期保留的旧字段。早期版本用布尔值区分“手动新增”，
    /// 现在判定一律走 `source`；失去用途后可以移除。
    @Attribute(originalName: "isManuallyCreated") var legacyIsManuallyCreated: Bool = false
    /// 来源枚举的稳定原始值。空字符串表示旧库升级后尚未回填。
    var sourceRawValue: String = ""
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        identityKey: String,
        languageSpaceID: String,
        term: String,
        normalizedTerm: String,
        meaning: String,
        source: WordEntrySource,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.identityKey = identityKey
        self.languageSpaceID = languageSpaceID
        self.term = term
        self.normalizedTerm = normalizedTerm
        self.meaning = meaning
        self.sourceRawValue = source.rawValue
        // 同步旧字段：降级回旧版本时语义不会丢失。
        self.legacyIsManuallyCreated = source == .manual
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    /// 来源的唯一判定入口。
    ///
    /// 旧库尚未回填时退回旧布尔字段推断，避免把历史数据误判成“文档导入”
    /// ——那会让手动新增的词条在日期模式里凭空消失。
    var source: WordEntrySource {
        WordEntrySource(rawValue: sourceRawValue)
            ?? (legacyIsManuallyCreated ? .manual : .markdownImport)
    }

    /// 是否需要回填来源。
    var needsSourceBackfill: Bool {
        WordEntrySource(rawValue: sourceRawValue) == nil
    }
}

@Model
final class WordImportBatch {
    @Attribute(.unique) var id: UUID
    var languageSpaceID: String
    var sourceDateKey: String
    var sourceYear: Int
    var sourceMonth: Int
    var sourceDay: Int
    var importedAt: Date
    var sourceFilename: String
    /// 批次来源。用于把"从词库收藏"产生的出现记录与文档导入区分开：
    /// 取消收藏只能撤销自己写入的记录，绝不能连带删除文档导入的日期。
    var sourceRawValue: String = WordEntrySource.markdownImport.rawValue

    init(
        id: UUID = UUID(),
        languageSpaceID: String,
        sourceDate: VocabularyDocumentDate,
        importedAt: Date = .now,
        sourceFilename: String,
        source: WordEntrySource = .markdownImport
    ) {
        self.id = id
        self.languageSpaceID = languageSpaceID
        self.sourceDateKey = sourceDate.storageKey
        self.sourceYear = sourceDate.year
        self.sourceMonth = sourceDate.month
        self.sourceDay = sourceDate.day
        self.importedAt = importedAt
        self.sourceFilename = sourceFilename
        self.sourceRawValue = source.rawValue
    }

    var source: WordEntrySource {
        WordEntrySource(rawValue: sourceRawValue) ?? .markdownImport
    }
}

@Model
final class WordOccurrence {
    @Attribute(.unique) var id: UUID
    @Attribute(.unique) var occurrenceKey: String
    var languageSpaceID: String
    var wordEntryID: UUID
    var importBatchID: UUID
    var sourceDateKey: String
    var sourceYear: Int
    var sourceMonth: Int
    var sourceDay: Int

    init(
        id: UUID = UUID(),
        occurrenceKey: String,
        languageSpaceID: String,
        wordEntryID: UUID,
        importBatchID: UUID,
        sourceDate: VocabularyDocumentDate
    ) {
        self.id = id
        self.occurrenceKey = occurrenceKey
        self.languageSpaceID = languageSpaceID
        self.wordEntryID = wordEntryID
        self.importBatchID = importBatchID
        self.sourceDateKey = sourceDate.storageKey
        self.sourceYear = sourceDate.year
        self.sourceMonth = sourceDate.month
        self.sourceDay = sourceDate.day
    }
}

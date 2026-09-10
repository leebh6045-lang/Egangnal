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

struct WordBookEntrySnapshot: Identifiable, Equatable, Sendable {
    let id: UUID
    let term: String
    let meaning: String
    let isManuallyCreated: Bool
    let occurrenceDates: [VocabularyDocumentDate]

    var isHighFrequency: Bool {
        occurrenceDates.count >= 2
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

@Model
final class WordEntry {
    @Attribute(.unique) var id: UUID
    @Attribute(.unique) var identityKey: String
    var languageSpaceID: String
    var term: String
    var normalizedTerm: String
    var meaning: String
    var isManuallyCreated: Bool
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        identityKey: String,
        languageSpaceID: String,
        term: String,
        normalizedTerm: String,
        meaning: String,
        isManuallyCreated: Bool,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.identityKey = identityKey
        self.languageSpaceID = languageSpaceID
        self.term = term
        self.normalizedTerm = normalizedTerm
        self.meaning = meaning
        self.isManuallyCreated = isManuallyCreated
        self.createdAt = createdAt
        self.updatedAt = updatedAt
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

    init(
        id: UUID = UUID(),
        languageSpaceID: String,
        sourceDate: VocabularyDocumentDate,
        importedAt: Date = .now,
        sourceFilename: String
    ) {
        self.id = id
        self.languageSpaceID = languageSpaceID
        self.sourceDateKey = sourceDate.storageKey
        self.sourceYear = sourceDate.year
        self.sourceMonth = sourceDate.month
        self.sourceDay = sourceDate.day
        self.importedAt = importedAt
        self.sourceFilename = sourceFilename
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

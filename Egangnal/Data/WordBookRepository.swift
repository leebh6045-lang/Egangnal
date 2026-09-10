//
//  WordBookRepository.swift
//  Egangnal
//

import Foundation
import SwiftData

enum WordBookRepositoryError: Error, Equatable, LocalizedError {
    case emptyTerm
    case emptyMeaning
    case duplicateTerm
    case entryNotFound
    case storageUnavailable

    var errorDescription: String? {
        switch self {
        case .emptyTerm:
            "单词不能为空。"
        case .emptyMeaning:
            "中文意思不能为空。"
        case .duplicateTerm:
            "当前语言空间已存在这个单词。"
        case .entryNotFound:
            "需要操作的单词不存在。"
        case .storageUnavailable:
            "本地持久化暂不可用，单词本写入已被禁止。"
        }
    }
}

@MainActor
protocol WordBookRepository: AnyObject {
    func importDocument(
        _ document: ParsedWordDocument,
        into space: LanguageSpace,
        sourceFilename: String,
        importedAt: Date
    ) throws -> WordBookImportResult

    func entries(in space: LanguageSpace) throws -> [WordBookEntrySnapshot]
    func entries(on date: VocabularyDocumentDate, in space: LanguageSpace) throws -> [WordBookEntrySnapshot]
    func addManualEntry(term: String, meaning: String, in space: LanguageSpace) throws -> UUID
    func updateEntry(id: UUID, term: String, meaning: String, in space: LanguageSpace) throws
    func deleteEntry(id: UUID, in space: LanguageSpace) throws
}

@MainActor
final class SwiftDataWordBookRepository: WordBookRepository {
    private let modelContext: ModelContext

    init(modelContainer: ModelContainer) {
        modelContext = ModelContext(modelContainer)
        modelContext.autosaveEnabled = false
    }

    func importDocument(
        _ document: ParsedWordDocument,
        into space: LanguageSpace,
        sourceFilename: String,
        importedAt: Date = .now
    ) throws -> WordBookImportResult {
        do {
            let existingEntries = try fetchEntries(in: space)
            var entriesByTerm = Dictionary(
                uniqueKeysWithValues: existingEntries.map { ($0.normalizedTerm, $0) }
            )
            let existingOccurrenceKeys = Set(
                try fetchOccurrences(in: space).map(\.occurrenceKey)
            )

            var pendingWords: [(entry: WordEntry, occurrenceKey: String)] = []
            var seenTerms = Set<String>()
            var insertedEntryCount = 0
            var skippedDuplicateCount = 0

            for word in document.words {
                let cleanedTerm = word.term.trimmingCharacters(in: .whitespacesAndNewlines)
                let cleanedMeaning = word.meaning.trimmingCharacters(in: .whitespacesAndNewlines)
                let normalizedTerm = WordNormalizer.normalizedTerm(cleanedTerm, in: space)
                guard !normalizedTerm.isEmpty else {
                    throw WordBookRepositoryError.emptyTerm
                }
                guard !cleanedMeaning.isEmpty else {
                    throw WordBookRepositoryError.emptyMeaning
                }

                if !seenTerms.insert(normalizedTerm).inserted {
                    skippedDuplicateCount += 1
                    continue
                }

                let entry: WordEntry
                if let existingEntry = entriesByTerm[normalizedTerm] {
                    entry = existingEntry
                } else {
                    let identityKey = WordNormalizer.identityKey(
                        for: normalizedTerm,
                        in: space
                    )
                    entry = WordEntry(
                        identityKey: identityKey,
                        languageSpaceID: space.rawValue,
                        term: cleanedTerm,
                        normalizedTerm: normalizedTerm,
                        meaning: cleanedMeaning,
                        isManuallyCreated: false,
                        createdAt: importedAt,
                        updatedAt: importedAt
                    )
                    modelContext.insert(entry)
                    entriesByTerm[normalizedTerm] = entry
                    insertedEntryCount += 1
                }

                let occurrenceKey = Self.occurrenceKey(
                    space: space,
                    entryID: entry.id,
                    date: document.sourceDate
                )
                if existingOccurrenceKeys.contains(occurrenceKey) {
                    skippedDuplicateCount += 1
                } else {
                    pendingWords.append((entry, occurrenceKey))
                }
            }

            guard !pendingWords.isEmpty else {
                // 完全重复的导入不写数据库，也不生成空批次。
                modelContext.rollback()
                return WordBookImportResult(
                    insertedEntryCount: 0,
                    insertedOccurrenceCount: 0,
                    skippedDuplicateCount: skippedDuplicateCount
                )
            }

            let batch = WordImportBatch(
                languageSpaceID: space.rawValue,
                sourceDate: document.sourceDate,
                importedAt: importedAt,
                sourceFilename: sourceFilename
            )
            modelContext.insert(batch)

            for pendingWord in pendingWords {
                modelContext.insert(
                    WordOccurrence(
                        occurrenceKey: pendingWord.occurrenceKey,
                        languageSpaceID: space.rawValue,
                        wordEntryID: pendingWord.entry.id,
                        importBatchID: batch.id,
                        sourceDate: document.sourceDate
                    )
                )
            }

            try modelContext.save()
            return WordBookImportResult(
                insertedEntryCount: insertedEntryCount,
                insertedOccurrenceCount: pendingWords.count,
                skippedDuplicateCount: skippedDuplicateCount
            )
        } catch {
            // 一次导入共享一次提交，失败时必须丢弃所有未保存变化。
            modelContext.rollback()
            throw error
        }
    }

    func entries(in space: LanguageSpace) throws -> [WordBookEntrySnapshot] {
        let entries = try fetchEntries(in: space)
        let occurrences = try fetchOccurrences(in: space)
        return snapshots(entries: entries, occurrences: occurrences)
    }

    func entries(
        on date: VocabularyDocumentDate,
        in space: LanguageSpace
    ) throws -> [WordBookEntrySnapshot] {
        let entries = try fetchEntries(in: space)
        let allOccurrences = try fetchOccurrences(in: space)
        let entryIDs = Set(
            allOccurrences
                .filter { $0.sourceDateKey == date.storageKey }
                .map(\.wordEntryID)
        )
        return snapshots(
            entries: entries.filter { entryIDs.contains($0.id) },
            occurrences: allOccurrences
        )
    }

    func addManualEntry(
        term: String,
        meaning: String,
        in space: LanguageSpace
    ) throws -> UUID {
        let cleanedTerm = term.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanedMeaning = meaning.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanedTerm.isEmpty else { throw WordBookRepositoryError.emptyTerm }
        guard !cleanedMeaning.isEmpty else { throw WordBookRepositoryError.emptyMeaning }

        let normalizedTerm = WordNormalizer.normalizedTerm(cleanedTerm, in: space)
        guard try findEntry(normalizedTerm: normalizedTerm, in: space) == nil else {
            throw WordBookRepositoryError.duplicateTerm
        }

        let entry = WordEntry(
            identityKey: WordNormalizer.identityKey(for: normalizedTerm, in: space),
            languageSpaceID: space.rawValue,
            term: cleanedTerm,
            normalizedTerm: normalizedTerm,
            meaning: cleanedMeaning,
            isManuallyCreated: true
        )
        modelContext.insert(entry)
        try saveOrRollback()
        return entry.id
    }

    func updateEntry(
        id: UUID,
        term: String,
        meaning: String,
        in space: LanguageSpace
    ) throws {
        let cleanedTerm = term.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanedMeaning = meaning.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanedTerm.isEmpty else { throw WordBookRepositoryError.emptyTerm }
        guard !cleanedMeaning.isEmpty else { throw WordBookRepositoryError.emptyMeaning }
        guard let entry = try findEntry(id: id, in: space) else {
            throw WordBookRepositoryError.entryNotFound
        }

        let normalizedTerm = WordNormalizer.normalizedTerm(cleanedTerm, in: space)
        if let conflictingEntry = try findEntry(normalizedTerm: normalizedTerm, in: space),
           conflictingEntry.id != id {
            throw WordBookRepositoryError.duplicateTerm
        }

        entry.term = cleanedTerm
        entry.normalizedTerm = normalizedTerm
        entry.identityKey = WordNormalizer.identityKey(for: normalizedTerm, in: space)
        entry.meaning = cleanedMeaning
        entry.updatedAt = .now
        try saveOrRollback()
    }

    func deleteEntry(id: UUID, in space: LanguageSpace) throws {
        do {
            guard let entry = try findEntry(id: id, in: space) else {
                throw WordBookRepositoryError.entryNotFound
            }

            // 先完成所有可能失败的查询，再修改上下文，保证失败路径可以完整回滚。
            let occurrences = try fetchOccurrences(in: space)
            let batches = try fetchBatches(in: space)
            let removedOccurrences = occurrences.filter { $0.wordEntryID == id }
            let removedBatchIDs = Set(removedOccurrences.map(\.importBatchID))
            for occurrence in removedOccurrences {
                modelContext.delete(occurrence)
            }
            modelContext.delete(entry)

            // 删除最后一个关联词条后同步清理空批次，避免留下无意义的导入历史。
            let remainingBatchIDs = Set(
                occurrences
                    .filter { $0.wordEntryID != id }
                    .map(\.importBatchID)
            )
            let emptyBatchIDs = removedBatchIDs.subtracting(remainingBatchIDs)
            for batch in batches where emptyBatchIDs.contains(batch.id) {
                modelContext.delete(batch)
            }

            try modelContext.save()
        } catch {
            modelContext.rollback()
            throw error
        }
    }

    private func snapshots(
        entries: [WordEntry],
        occurrences: [WordOccurrence]
    ) -> [WordBookEntrySnapshot] {
        let datesByEntryID = Dictionary(grouping: occurrences, by: \.wordEntryID)
            .mapValues { values in
                Set(values.compactMap(Self.documentDate(from:))).sorted()
            }

        return entries.map { entry in
            WordBookEntrySnapshot(
                id: entry.id,
                term: entry.term,
                meaning: entry.meaning,
                isManuallyCreated: entry.isManuallyCreated,
                occurrenceDates: datesByEntryID[entry.id] ?? []
            )
        }
    }

    private func fetchEntries(in space: LanguageSpace) throws -> [WordEntry] {
        let languageSpaceID = space.rawValue
        let descriptor = FetchDescriptor<WordEntry>(
            predicate: #Predicate { entry in
                entry.languageSpaceID == languageSpaceID
            },
            sortBy: [
                SortDescriptor(\.createdAt),
                SortDescriptor(\.normalizedTerm)
            ]
        )
        return try modelContext.fetch(descriptor)
    }

    private func fetchOccurrences(in space: LanguageSpace) throws -> [WordOccurrence] {
        let languageSpaceID = space.rawValue
        let descriptor = FetchDescriptor<WordOccurrence>(
            predicate: #Predicate { occurrence in
                occurrence.languageSpaceID == languageSpaceID
            }
        )
        return try modelContext.fetch(descriptor)
    }

    private func fetchBatches(in space: LanguageSpace) throws -> [WordImportBatch] {
        let languageSpaceID = space.rawValue
        let descriptor = FetchDescriptor<WordImportBatch>(
            predicate: #Predicate { batch in
                batch.languageSpaceID == languageSpaceID
            }
        )
        return try modelContext.fetch(descriptor)
    }

    private func findEntry(
        normalizedTerm: String,
        in space: LanguageSpace
    ) throws -> WordEntry? {
        let identityKey = WordNormalizer.identityKey(for: normalizedTerm, in: space)
        var descriptor = FetchDescriptor<WordEntry>(
            predicate: #Predicate { entry in
                entry.identityKey == identityKey
            }
        )
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }

    private func findEntry(id: UUID, in space: LanguageSpace) throws -> WordEntry? {
        let languageSpaceID = space.rawValue
        var descriptor = FetchDescriptor<WordEntry>(
            predicate: #Predicate { entry in
                entry.id == id && entry.languageSpaceID == languageSpaceID
            }
        )
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }

    private func saveOrRollback() throws {
        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
            throw error
        }
    }

    private static func occurrenceKey(
        space: LanguageSpace,
        entryID: UUID,
        date: VocabularyDocumentDate
    ) -> String {
        "\(space.rawValue)|\(entryID.uuidString)|\(date.storageKey)"
    }

    private static func documentDate(
        from occurrence: WordOccurrence
    ) -> VocabularyDocumentDate? {
        VocabularyDocumentDate(
            year: occurrence.sourceYear,
            month: occurrence.sourceMonth,
            day: occurrence.sourceDay
        )
    }
}

@MainActor
final class UnavailableWordBookRepository: WordBookRepository {
    func importDocument(
        _ document: ParsedWordDocument,
        into space: LanguageSpace,
        sourceFilename: String,
        importedAt: Date
    ) throws -> WordBookImportResult {
        throw WordBookRepositoryError.storageUnavailable
    }

    func entries(in space: LanguageSpace) throws -> [WordBookEntrySnapshot] {
        throw WordBookRepositoryError.storageUnavailable
    }

    func entries(
        on date: VocabularyDocumentDate,
        in space: LanguageSpace
    ) throws -> [WordBookEntrySnapshot] {
        throw WordBookRepositoryError.storageUnavailable
    }

    func addManualEntry(term: String, meaning: String, in space: LanguageSpace) throws -> UUID {
        throw WordBookRepositoryError.storageUnavailable
    }

    func updateEntry(id: UUID, term: String, meaning: String, in space: LanguageSpace) throws {
        throw WordBookRepositoryError.storageUnavailable
    }

    func deleteEntry(id: UUID, in space: LanguageSpace) throws {
        throw WordBookRepositoryError.storageUnavailable
    }
}

@MainActor
final class PreviewWordBookRepository: WordBookRepository {
    func importDocument(
        _ document: ParsedWordDocument,
        into space: LanguageSpace,
        sourceFilename: String,
        importedAt: Date
    ) throws -> WordBookImportResult {
        WordBookImportResult(
            insertedEntryCount: document.words.count,
            insertedOccurrenceCount: document.words.count,
            skippedDuplicateCount: 0
        )
    }

    func entries(in space: LanguageSpace) throws -> [WordBookEntrySnapshot] {
        []
    }

    func entries(
        on date: VocabularyDocumentDate,
        in space: LanguageSpace
    ) throws -> [WordBookEntrySnapshot] {
        []
    }

    func addManualEntry(term: String, meaning: String, in space: LanguageSpace) throws -> UUID {
        UUID()
    }

    func updateEntry(id: UUID, term: String, meaning: String, in space: LanguageSpace) throws {}

    func deleteEntry(id: UUID, in space: LanguageSpace) throws {}
}

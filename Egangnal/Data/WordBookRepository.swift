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
    /// 从公共词库收藏一个词条：同语言内幂等、不覆盖已有释义，并记为**当日**收录的生词。
    func collectFromLexicon(
        term: String,
        meaning: String,
        collectedAt: Date,
        in space: LanguageSpace
    ) throws -> WordBookCollectionOutcome
    /// 撤销词库收藏。只移除词库收藏写入的记录；文档导入与手动新增的词条不受影响。
    func uncollectFromLexicon(
        term: String,
        in space: LanguageSpace
    ) throws -> WordBookCollectionOutcome
    /// 每个词条相对“词库收藏”的状态与收藏日期，键为规范化词形。
    func lexiconCollectionInfo(in space: LanguageSpace) throws -> [String: LexiconCollectionInfo]
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
                        source: .markdownImport,
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
            source: .manual
        )
        modelContext.insert(entry)
        try saveOrRollback()
        return entry.id
    }

    /// 从词库收藏一个词条。
    ///
    /// 三条不变量：同语言内幂等；已有词条（无论来自导入、手动还是收藏）**不覆盖释义**；
    /// 收藏同时计入**当日**出现记录，因此当天的日期分组会包含它。
    func collectFromLexicon(
        term: String,
        meaning: String,
        collectedAt: Date,
        in space: LanguageSpace
    ) throws -> WordBookCollectionOutcome {
        let cleanedTerm = term.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanedMeaning = meaning.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanedTerm.isEmpty else { throw WordBookRepositoryError.emptyTerm }
        guard !cleanedMeaning.isEmpty else { throw WordBookRepositoryError.emptyMeaning }

        let normalizedTerm = WordNormalizer.normalizedTerm(cleanedTerm, in: space)
        let today = VocabularyDocumentDate(date: collectedAt)

        do {
            let entry = try findEntry(normalizedTerm: normalizedTerm, in: space)
                ?? makeCollectedEntry(
                    term: cleanedTerm,
                    normalizedTerm: normalizedTerm,
                    meaning: cleanedMeaning,
                    space: space,
                    createdAt: collectedAt
                )

            let occurrenceKey = Self.occurrenceKey(
                space: space,
                entryID: entry.id,
                date: today
            )
            let alreadyRecordedToday = try fetchOccurrences(in: space)
                .contains { $0.occurrenceKey == occurrenceKey }
            guard !alreadyRecordedToday else {
                modelContext.rollback()
                return .alreadyExists
            }

            let batch = try collectionBatch(on: today, in: space)
            modelContext.insert(
                WordOccurrence(
                    occurrenceKey: occurrenceKey,
                    languageSpaceID: space.rawValue,
                    wordEntryID: entry.id,
                    importBatchID: batch.id,
                    sourceDate: today
                )
            )
            try modelContext.save()
            return .inserted
        } catch {
            modelContext.rollback()
            throw error
        }
    }

    /// 撤销词库收藏。
    ///
    /// **绝不删除文档导入或手动新增的内容**：只有当词条唯一来源就是词库收藏时才整体删除，
    /// 否则只移除词库收藏写入的出现记录，并在返回值里说明词条仍然保留。
    func uncollectFromLexicon(
        term: String,
        in space: LanguageSpace
    ) throws -> WordBookCollectionOutcome {
        let cleanedTerm = term.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanedTerm.isEmpty else { throw WordBookRepositoryError.emptyTerm }

        let normalizedTerm = WordNormalizer.normalizedTerm(cleanedTerm, in: space)
        do {
            guard let entry = try findEntry(normalizedTerm: normalizedTerm, in: space) else {
                return .notCollected
            }

            let collectionBatchIDs = Set(
                try fetchBatches(in: space)
                    .filter { $0.source == .lexiconCollection }
                    .map(\.id)
            )
            let allOccurrences = try fetchOccurrences(in: space)
            let entryOccurrences = allOccurrences.filter { $0.wordEntryID == entry.id }
            let collectionOccurrences = entryOccurrences.filter {
                collectionBatchIDs.contains($0.importBatchID)
            }

            // 词条来自文档导入或手动新增时，词库没有权限删除它。
            guard !collectionOccurrences.isEmpty || entry.source == .lexiconCollection else {
                return .managedInWordBook
            }

            for occurrence in collectionOccurrences {
                modelContext.delete(occurrence)
            }

            let remainingOccurrences = entryOccurrences.count - collectionOccurrences.count
            let removesEntry = remainingOccurrences == 0 && entry.source == .lexiconCollection
            if removesEntry {
                modelContext.delete(entry)
            }

            // 收藏批次可能还装着同一天其它词的收藏记录，只有彻底空了才清理。
            let stillUsedBatchIDs = Set(
                allOccurrences
                    .filter { $0.wordEntryID != entry.id }
                    .map(\.importBatchID)
            )
            for batch in try fetchBatches(in: space)
            where collectionBatchIDs.contains(batch.id)
                && !stillUsedBatchIDs.contains(batch.id) {
                modelContext.delete(batch)
            }

            try modelContext.save()
            return removesEntry ? .removed : .removedCollectionOnly
        } catch {
            modelContext.rollback()
            throw error
        }
    }

    func lexiconCollectionInfo(
        in space: LanguageSpace
    ) throws -> [String: LexiconCollectionInfo] {
        let entries = try fetchEntries(in: space)
        let collectionBatchIDs = Set(
            try fetchBatches(in: space)
                .filter { $0.source == .lexiconCollection }
                .map(\.id)
        )

        var datesByEntryID: [UUID: Set<VocabularyDocumentDate>] = [:]
        for occurrence in try fetchOccurrences(in: space)
        where collectionBatchIDs.contains(occurrence.importBatchID) {
            guard let date = Self.documentDate(from: occurrence) else { continue }
            datesByEntryID[occurrence.wordEntryID, default: []].insert(date)
        }

        var info: [String: LexiconCollectionInfo] = [:]
        for entry in entries {
            let dates = (datesByEntryID[entry.id] ?? []).sorted(by: >)
            // 早期版本收藏的词条没有出现记录，用来源字段兜底。
            let isCollected = !dates.isEmpty || entry.source == .lexiconCollection
            info[entry.normalizedTerm] = LexiconCollectionInfo(
                state: isCollected ? .collected : .managedInWordBook,
                collectedDates: dates
            )
        }
        return info
    }

    private func makeCollectedEntry(
        term: String,
        normalizedTerm: String,
        meaning: String,
        space: LanguageSpace,
        createdAt: Date
    ) -> WordEntry {
        let entry = WordEntry(
            identityKey: WordNormalizer.identityKey(for: normalizedTerm, in: space),
            languageSpaceID: space.rawValue,
            term: term,
            normalizedTerm: normalizedTerm,
            meaning: meaning,
            source: .lexiconCollection,
            createdAt: createdAt
        )
        modelContext.insert(entry)
        return entry
    }

    /// 当天的词库收藏批次：同一天只建一个，重复收藏直接复用。
    private func collectionBatch(
        on date: VocabularyDocumentDate,
        in space: LanguageSpace
    ) throws -> WordImportBatch {
        let languageSpaceID = space.rawValue
        let dateKey = date.storageKey
        let collectionSource = WordEntrySource.lexiconCollection.rawValue

        var descriptor = FetchDescriptor<WordImportBatch>(
            predicate: #Predicate { batch in
                batch.languageSpaceID == languageSpaceID
                    && batch.sourceDateKey == dateKey
                    && batch.sourceRawValue == collectionSource
            }
        )
        descriptor.fetchLimit = 1
        if let existing = try modelContext.fetch(descriptor).first {
            return existing
        }

        let batch = WordImportBatch(
            languageSpaceID: space.rawValue,
            sourceDate: date,
            sourceFilename: "词库收藏-\(date.storageKey)",
            source: .lexiconCollection
        )
        modelContext.insert(batch)
        return batch
    }

    /// 把旧库中的布尔来源回填成来源枚举。返回回填条数。
    ///
    /// 必须在任何依赖 `source` 的读取之前执行一次；回填只写来源字段，不改动释义与日期。
    @discardableResult
    func migrateLegacyEntrySourcesIfNeeded() throws -> Int {
        let descriptor = FetchDescriptor<WordEntry>()
        let entries = try modelContext.fetch(descriptor)
        let pending = entries.filter(\.needsSourceBackfill)
        guard !pending.isEmpty else { return 0 }

        for entry in pending {
            entry.sourceRawValue = entry.source.rawValue
        }
        try saveOrRollback()
        return pending.count
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
                source: entry.source,
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

    func collectFromLexicon(
        term: String,
        meaning: String,
        collectedAt: Date,
        in space: LanguageSpace
    ) throws -> WordBookCollectionOutcome {
        throw WordBookRepositoryError.storageUnavailable
    }

    func uncollectFromLexicon(
        term: String,
        in space: LanguageSpace
    ) throws -> WordBookCollectionOutcome {
        throw WordBookRepositoryError.storageUnavailable
    }

    func lexiconCollectionInfo(
        in space: LanguageSpace
    ) throws -> [String: LexiconCollectionInfo] {
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

    func collectFromLexicon(
        term: String,
        meaning: String,
        collectedAt: Date,
        in space: LanguageSpace
    ) throws -> WordBookCollectionOutcome {
        .inserted
    }

    func uncollectFromLexicon(
        term: String,
        in space: LanguageSpace
    ) throws -> WordBookCollectionOutcome {
        .removed
    }

    func lexiconCollectionInfo(
        in space: LanguageSpace
    ) throws -> [String: LexiconCollectionInfo] {
        [:]
    }

    func updateEntry(id: UUID, term: String, meaning: String, in space: LanguageSpace) throws {}

    func deleteEntry(id: UUID, in space: LanguageSpace) throws {}
}

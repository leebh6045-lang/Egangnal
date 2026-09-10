//
//  StudyTimeRepository.swift
//  Egangnal
//

import Foundation
import SwiftData

enum StudyTimeStorageError: LocalizedError, Equatable, Sendable {
    case invalidLanguage(String)
    case invalidTotalSeconds
    case duplicateLanguageRecord(String)
    case missingLanguageRecord(String)
    case invalidDateKey(String)
    case duplicateDailyActivity(String)
    case persistenceUnavailable

    var errorDescription: String? {
        switch self {
        case let .invalidLanguage(value):
            "学习时长记录包含未知语言空间：\(value)"
        case .invalidTotalSeconds:
            "学习时长记录不是有效的非负数。"
        case let .duplicateLanguageRecord(value):
            "语言空间存在重复的学习时长记录：\(value)"
        case let .missingLanguageRecord(value):
            "缺少语言空间的学习时长记录：\(value)"
        case let .invalidDateKey(value):
            "每日学习反馈包含无效日期：\(value)"
        case let .duplicateDailyActivity(value):
            "每日学习反馈存在重复记录：\(value)"
        case .persistenceUnavailable:
            "本地学习时长存储当前不可用。"
        }
    }
}

@MainActor
protocol StudyTimeRepository {
    func loadAll() throws -> [LanguageSpace: StudyTimeSnapshot]
    func loadDailyActivities() throws -> [DailyStudyActivitySnapshot]
    func markEntered(
        on dateKey: StudyDateKey,
        for space: LanguageSpace,
        at date: Date
    ) throws
    func saveStudyTime(
        _ totalSeconds: Double,
        for space: LanguageSpace,
        dailyIncrements: [DailyStudyActivityIncrement],
        at date: Date
    ) throws
    func saveTotalSeconds(
        _ totalSeconds: Double,
        for space: LanguageSpace,
        at date: Date
    ) throws
}

@MainActor
final class SwiftDataStudyTimeRepository: StudyTimeRepository {
    private let modelContext: ModelContext

    init(modelContainer: ModelContainer) {
        modelContext = ModelContext(modelContainer)
    }

    func loadAll() throws -> [LanguageSpace: StudyTimeSnapshot] {
        let records = try modelContext.fetch(FetchDescriptor<StudyTimeRecord>())
        var recordsBySpace: [LanguageSpace: StudyTimeRecord] = [:]

        for record in records {
            guard let space = LanguageSpace(rawValue: record.languageSpaceID) else {
                throw StudyTimeStorageError.invalidLanguage(record.languageSpaceID)
            }
            guard record.totalSeconds.isFinite, record.totalSeconds >= 0 else {
                throw StudyTimeStorageError.invalidTotalSeconds
            }
            guard recordsBySpace[space] == nil else {
                throw StudyTimeStorageError.duplicateLanguageRecord(space.rawValue)
            }
            recordsBySpace[space] = record
        }

        var didCreateRecords = false
        for space in LanguageSpace.allCases where recordsBySpace[space] == nil {
            let record = StudyTimeRecord(languageSpace: space)
            modelContext.insert(record)
            recordsBySpace[space] = record
            didCreateRecords = true
        }

        if didCreateRecords {
            do {
                try modelContext.save()
            } catch {
                modelContext.rollback()
                throw error
            }
        }

        return try recordsBySpace.reduce(into: [:]) { result, pair in
            guard let space = LanguageSpace(rawValue: pair.key.rawValue) else {
                throw StudyTimeStorageError.missingLanguageRecord(pair.key.rawValue)
            }
            result[space] = StudyTimeSnapshot(totalSeconds: pair.value.totalSeconds)
        }
    }

    func saveTotalSeconds(
        _ totalSeconds: Double,
        for space: LanguageSpace,
        at date: Date
    ) throws {
        try saveStudyTime(
            totalSeconds,
            for: space,
            dailyIncrements: [],
            at: date
        )
    }

    func loadDailyActivities() throws -> [DailyStudyActivitySnapshot] {
        let records = try modelContext.fetch(FetchDescriptor<DailyStudyActivity>())
        var identities = Set<String>()

        return try records.map { record in
            guard let dateKey = StudyDateKey(rawValue: record.dateKey) else {
                throw StudyTimeStorageError.invalidDateKey(record.dateKey)
            }
            guard let space = LanguageSpace(rawValue: record.languageSpaceID) else {
                throw StudyTimeStorageError.invalidLanguage(record.languageSpaceID)
            }
            guard record.studiedSeconds.isFinite, record.studiedSeconds >= 0 else {
                throw StudyTimeStorageError.invalidTotalSeconds
            }

            let identity = DailyStudyActivity.makeIdentityKey(
                dateKey: dateKey,
                languageSpace: space
            )
            guard identities.insert(identity).inserted else {
                throw StudyTimeStorageError.duplicateDailyActivity(identity)
            }
            return DailyStudyActivitySnapshot(
                dateKey: dateKey,
                space: space,
                studiedSeconds: record.studiedSeconds,
                hasEntered: record.hasEntered
            )
        }
    }

    func markEntered(
        on dateKey: StudyDateKey,
        for space: LanguageSpace,
        at date: Date
    ) throws {
        let identity = DailyStudyActivity.makeIdentityKey(
            dateKey: dateKey,
            languageSpace: space
        )
        let records = try modelContext.fetch(FetchDescriptor<DailyStudyActivity>())
        let matchingRecords = records.filter { $0.identityKey == identity }

        guard matchingRecords.count <= 1 else {
            throw StudyTimeStorageError.duplicateDailyActivity(identity)
        }

        let record: DailyStudyActivity
        if let existing = matchingRecords.first {
            record = existing
        } else {
            record = DailyStudyActivity(dateKey: dateKey, languageSpace: space)
            modelContext.insert(record)
        }
        record.hasEntered = true
        record.updatedAt = date

        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
            throw error
        }
    }

    func saveStudyTime(
        _ totalSeconds: Double,
        for space: LanguageSpace,
        dailyIncrements: [DailyStudyActivityIncrement],
        at date: Date
    ) throws {
        guard totalSeconds.isFinite, totalSeconds >= 0 else {
            throw StudyTimeStorageError.invalidTotalSeconds
        }

        var incrementsByIdentity: [String: DailyStudyActivityIncrement] = [:]
        for increment in dailyIncrements {
            guard increment.space == space,
                  increment.seconds.isFinite,
                  increment.seconds >= 0,
                  StudyDateKey(rawValue: increment.dateKey.rawValue) != nil else {
                throw StudyTimeStorageError.invalidTotalSeconds
            }

            let identity = DailyStudyActivity.makeIdentityKey(
                dateKey: increment.dateKey,
                languageSpace: space
            )
            if let existing = incrementsByIdentity[identity] {
                let combinedSeconds = existing.seconds + increment.seconds
                guard combinedSeconds.isFinite else {
                    throw StudyTimeStorageError.invalidTotalSeconds
                }
                incrementsByIdentity[identity] = DailyStudyActivityIncrement(
                    dateKey: existing.dateKey,
                    space: space,
                    seconds: combinedSeconds
                )
            } else {
                incrementsByIdentity[identity] = increment
            }
        }

        // 先完成所有每日记录校验，再修改 SwiftData 对象，避免校验失败时留下半写入状态。
        let dailyRecords = try modelContext.fetch(FetchDescriptor<DailyStudyActivity>())
        var dailyRecordsByIdentity: [String: [DailyStudyActivity]] = [:]
        for dailyRecord in dailyRecords {
            dailyRecordsByIdentity[dailyRecord.identityKey, default: []].append(dailyRecord)
        }
        for (identity, increment) in incrementsByIdentity where increment.seconds > 0 {
            let matchingDailyRecords = dailyRecordsByIdentity[identity] ?? []
            guard matchingDailyRecords.count <= 1 else {
                throw StudyTimeStorageError.duplicateDailyActivity(identity)
            }
            if let existing = matchingDailyRecords.first {
                let combinedSeconds = existing.studiedSeconds + increment.seconds
                guard existing.studiedSeconds.isFinite,
                      existing.studiedSeconds >= 0,
                      combinedSeconds.isFinite else {
                    throw StudyTimeStorageError.invalidTotalSeconds
                }
            }
        }

        let records = try modelContext.fetch(FetchDescriptor<StudyTimeRecord>())
        let matchingRecords = records.filter { $0.languageSpaceID == space.rawValue }

        guard matchingRecords.count <= 1 else {
            throw StudyTimeStorageError.duplicateLanguageRecord(space.rawValue)
        }

        let record: StudyTimeRecord
        if let existing = matchingRecords.first {
            record = existing
        } else {
            record = StudyTimeRecord(languageSpace: space)
            modelContext.insert(record)
        }

        record.totalSeconds = totalSeconds
        record.updatedAt = date

        for (identity, increment) in incrementsByIdentity where increment.seconds > 0 {
            let matchingDailyRecords = dailyRecordsByIdentity[identity] ?? []
            let dailyRecord: DailyStudyActivity
            if let existing = matchingDailyRecords.first {
                dailyRecord = existing
            } else {
                dailyRecord = DailyStudyActivity(
                    dateKey: increment.dateKey,
                    languageSpace: space
                )
                modelContext.insert(dailyRecord)
            }
            dailyRecord.studiedSeconds += increment.seconds
            dailyRecord.hasEntered = true
            dailyRecord.updatedAt = date
        }

        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
            throw error
        }
    }
}

/// 生产环境无法创建正式容器时使用，避免把不可持久化的计时伪装成已保存。
@MainActor
final class UnavailableStudyTimeRepository: StudyTimeRepository {
    func loadAll() throws -> [LanguageSpace: StudyTimeSnapshot] {
        throw StudyTimeStorageError.persistenceUnavailable
    }

    func saveTotalSeconds(
        _ totalSeconds: Double,
        for space: LanguageSpace,
        at date: Date
    ) throws {
        throw StudyTimeStorageError.persistenceUnavailable
    }

    func loadDailyActivities() throws -> [DailyStudyActivitySnapshot] {
        throw StudyTimeStorageError.persistenceUnavailable
    }

    func markEntered(
        on dateKey: StudyDateKey,
        for space: LanguageSpace,
        at date: Date
    ) throws {
        throw StudyTimeStorageError.persistenceUnavailable
    }

    func saveStudyTime(
        _ totalSeconds: Double,
        for space: LanguageSpace,
        dailyIncrements: [DailyStudyActivityIncrement],
        at date: Date
    ) throws {
        throw StudyTimeStorageError.persistenceUnavailable
    }
}

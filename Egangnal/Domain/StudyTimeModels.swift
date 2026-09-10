//
//  StudyTimeModels.swift
//  Egangnal
//

import Foundation
import SwiftData

/// 计时控制器读取的只读快照，不把 SwiftData 对象暴露给界面。
struct StudyTimeSnapshot: Equatable, Sendable {
    let totalSeconds: Double
}

/// 计时控制器读取的每日聚合快照，不把 SwiftData 对象暴露给界面。
struct DailyStudyActivitySnapshot: Equatable, Sendable {
    let dateKey: StudyDateKey
    let space: LanguageSpace
    let studiedSeconds: Double
    let hasEntered: Bool
}

/// 一次计时提交分配到某个本地日期的增量。
struct DailyStudyActivityIncrement: Equatable, Sendable {
    let dateKey: StudyDateKey
    let space: LanguageSpace
    let seconds: Double
}

@Model
final class StudyTimeRecord {
    @Attribute(.unique) var languageSpaceID: String
    var totalSeconds: Double
    var updatedAt: Date

    init(
        languageSpace: LanguageSpace,
        totalSeconds: Double = 0,
        updatedAt: Date = .now
    ) {
        self.languageSpaceID = languageSpace.rawValue
        self.totalSeconds = totalSeconds
        self.updatedAt = updatedAt
    }
}

@Model
final class DailyStudyActivity {
    @Attribute(.unique) var identityKey: String
    var dateKey: String
    var languageSpaceID: String
    var studiedSeconds: Double
    var hasEntered: Bool
    var updatedAt: Date

    init(
        dateKey: StudyDateKey,
        languageSpace: LanguageSpace,
        studiedSeconds: Double = 0,
        hasEntered: Bool = false,
        updatedAt: Date = .now
    ) {
        self.identityKey = Self.makeIdentityKey(
            dateKey: dateKey,
            languageSpace: languageSpace
        )
        self.dateKey = dateKey.rawValue
        self.languageSpaceID = languageSpace.rawValue
        self.studiedSeconds = studiedSeconds
        self.hasEntered = hasEntered
        self.updatedAt = updatedAt
    }

    static func makeIdentityKey(
        dateKey: StudyDateKey,
        languageSpace: LanguageSpace
    ) -> String {
        "\(dateKey.rawValue)|\(languageSpace.rawValue)"
    }
}

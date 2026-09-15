//
//  DashboardSummary.swift
//  Egangnal
//

import Foundation

/// 首页展示的一页单词摘要；它只描述数据，不携带任何导航或点击意图。
struct DashboardRecentPage: Identifiable, Equatable, Sendable {
    enum Kind: Hashable, Sendable {
        case dated(VocabularyDocumentDate)
        case unarchived
    }

    let kind: Kind
    let wordCount: Int

    var id: String {
        switch kind {
        case let .dated(date):
            date.storageKey
        case .unarchived:
            "unarchived"
        }
    }

    var title: String {
        switch kind {
        case let .dated(date):
            "\(date.month)月\(date.day)日"
        case .unarchived:
            "未归档"
        }
    }
}

/// 把两个语言空间的个人词条合并为首页所需的最近页面摘要。
enum DashboardSummaryBuilder {
    static let recentPageLimit = 3

    /// 同一词可以出现在多个日期页；跨语言的相同拼写也分别计数。
    static func recentPages(
        from entriesBySpace: [LanguageSpace: [WordBookEntrySnapshot]],
        limit: Int = recentPageLimit
    ) -> [DashboardRecentPage] {
        guard limit > 0 else { return [] }

        var countByDate: [VocabularyDocumentDate: Int] = [:]
        var unarchivedCount = 0

        for entries in entriesBySpace.values {
            for entry in entries {
                let dates = Set(entry.occurrenceDates)
                if dates.isEmpty {
                    unarchivedCount += 1
                } else {
                    for date in dates {
                        countByDate[date, default: 0] += 1
                    }
                }
            }
        }

        var pages = countByDate
            .sorted { $0.key > $1.key }
            .prefix(limit)
            .map { date, count in
                DashboardRecentPage(kind: .dated(date), wordCount: count)
            }

        if unarchivedCount > 0 {
            pages.append(
                DashboardRecentPage(kind: .unarchived, wordCount: unarchivedCount)
            )
        }
        return pages
    }
}

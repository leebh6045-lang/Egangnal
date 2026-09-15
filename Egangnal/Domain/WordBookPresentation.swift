//
//  WordBookPresentation.swift
//  Egangnal
//

import Foundation

enum WordBookBrowseMode: String, CaseIterable, Identifiable {
    case all
    case date

    var id: Self { self }

    var title: String {
        switch self {
        case .all:
            "默认分页"
        case .date:
            "按日期"
        }
    }
}

enum WordBookMaskMode: String, CaseIterable, Sendable {
    case normal
    case hideWords
    case hideMeanings

    var next: Self {
        switch self {
        case .normal, .hideMeanings:
            .hideWords
        case .hideWords:
            .hideMeanings
        }
    }
}

struct WordBookMaskState: Equatable, Sendable {
    private(set) var mode: WordBookMaskMode = .normal
    private var hiddenWordIDs: Set<UUID> = []
    private var hiddenMeaningIDs: Set<UUID> = []
    private var revealedWordIDs: Set<UUID> = []
    private var revealedMeaningIDs: Set<UUID> = []

    func isWordVisible(_ id: UUID) -> Bool {
        switch mode {
        case .normal, .hideMeanings:
            !hiddenWordIDs.contains(id)
        case .hideWords:
            revealedWordIDs.contains(id)
        }
    }

    func isMeaningVisible(_ id: UUID) -> Bool {
        switch mode {
        case .normal, .hideWords:
            !hiddenMeaningIDs.contains(id)
        case .hideMeanings:
            revealedMeaningIDs.contains(id)
        }
    }

    mutating func toggleWord(_ id: UUID) {
        switch mode {
        case .hideWords:
            Self.toggle(id, in: &revealedWordIDs)
        case .normal, .hideMeanings:
            Self.toggle(id, in: &hiddenWordIDs)
        }
    }

    mutating func toggleMeaning(_ id: UUID) {
        switch mode {
        case .hideMeanings:
            Self.toggle(id, in: &revealedMeaningIDs)
        case .normal, .hideWords:
            Self.toggle(id, in: &hiddenMeaningIDs)
        }
    }

    mutating func cycleMode() {
        mode = mode.next
        clearOverrides()
    }

    mutating func reset() {
        mode = .normal
        clearOverrides()
    }

    private mutating func clearOverrides() {
        hiddenWordIDs.removeAll()
        hiddenMeaningIDs.removeAll()
        revealedWordIDs.removeAll()
        revealedMeaningIDs.removeAll()
    }

    private static func toggle(_ id: UUID, in ids: inout Set<UUID>) {
        if !ids.insert(id).inserted {
            ids.remove(id)
        }
    }
}

enum WordBookPaging {
    static let pageSize = 20

    static func pageCount(itemCount: Int, pageSize: Int = pageSize) -> Int {
        guard itemCount > 0, pageSize > 0 else { return 0 }
        return (itemCount + pageSize - 1) / pageSize
    }

    static func clampedPage(
        _ page: Int,
        itemCount: Int,
        pageSize: Int = pageSize
    ) -> Int {
        let lastPage = max(pageCount(itemCount: itemCount, pageSize: pageSize) - 1, 0)
        return min(max(page, 0), lastPage)
    }

    static func items(
        in entries: [WordBookEntrySnapshot],
        page: Int,
        pageSize: Int = pageSize
    ) -> [WordBookEntrySnapshot] {
        guard pageSize > 0 else { return [] }
        let safePage = clampedPage(page, itemCount: entries.count, pageSize: pageSize)
        let start = safePage * pageSize
        guard start < entries.count else { return [] }
        let end = min(start + pageSize, entries.count)
        return Array(entries[start..<end])
    }

    /// 按种子打乱词条顺序，用于「换一批」。
    ///
    /// 用 FNV-1a 从词条 UUID 与种子派生排序键：同一批词在翻页之间顺序稳定，
    /// 换种子时整批变化。单词本数据量小，直接在内存里排序即可。
    static func shuffled(
        _ entries: [WordBookEntrySnapshot],
        seed: Int
    ) -> [WordBookEntrySnapshot] {
        guard !entries.isEmpty else { return [] }
        return entries.sorted { lhs, rhs in
            shuffleKey(lhs.id, seed: seed) < shuffleKey(rhs.id, seed: seed)
        }
    }

    private static func shuffleKey(_ id: UUID, seed: Int) -> UInt64 {
        var hash: UInt64 = 14_695_981_039_346_656_037
        // 种子必须先经过完整的一轮散列再参与排序。
        // 若只写 `hash ^ seed`，XOR 只翻转种子里为 1 的位，高位几乎不变，
        // 结果就是"换了种子但顺序几乎没变"，等于没洗牌。
        var seedValue = UInt64(bitPattern: Int64(seed))
        withUnsafeBytes(of: &seedValue) { buffer in
            for byte in buffer {
                hash = (hash ^ UInt64(byte)) &* 1_099_511_628_211
            }
        }
        withUnsafeBytes(of: id.uuid) { buffer in
            for byte in buffer {
                hash = (hash ^ UInt64(byte)) &* 1_099_511_628_211
            }
        }
        return hash
    }

    static func dates(in entries: [WordBookEntrySnapshot]) -> [VocabularyDocumentDate] {
        Set(entries.flatMap(\.occurrenceDates)).sorted(by: >)
    }
}

/// 手帐里的一组词条：一个日期页一组，或“未归档”一组。
/// 放在领域层：分组规则是纯数据变换，视图层的手帐纸面只负责把它画出来。
struct JournalSection<Item>: Identifiable {
    let id: String
    /// 为空时不画分组标题（例如按日期浏览时，页面标题已经是这一天）。
    let title: String?
    let subtitle: String?
    let items: [Item]
}

/// 手帐排版的分组规则。
enum WordBookJournal {
    static let unarchivedSectionID = "unarchived"

    /// 把一页词条按"最近一次出现的日期"分组，日期由近到远；没有日期的归入末尾的"未归档"。
    /// 组内保持传入顺序（默认分页下就是洗牌后的顺序），不再二次排序。
    static func sections(
        for entries: [WordBookEntrySnapshot],
        today: VocabularyDocumentDate? = nil
    ) -> [JournalSection<WordBookEntrySnapshot>] {
        var buckets: [VocabularyDocumentDate: [WordBookEntrySnapshot]] = [:]
        var unarchived: [WordBookEntrySnapshot] = []
        for entry in entries {
            if let latest = entry.occurrenceDates.max() {
                buckets[latest, default: []].append(entry)
            } else {
                unarchived.append(entry)
            }
        }

        var sections = buckets
            .sorted { $0.key > $1.key }
            .map { date, items in
                JournalSection(
                    id: date.storageKey,
                    title: date.templateText,
                    subtitle: date == today ? "今天 · \(items.count) 词" : "\(items.count) 词",
                    items: items
                )
            }
        if !unarchived.isEmpty {
            sections.append(
                JournalSection(
                    id: unarchivedSectionID,
                    title: "未归档",
                    subtitle: "\(unarchived.count) 词",
                    items: unarchived
                )
            )
        }
        return sections
    }

    /// 按日期浏览时页面标题已经是这一天，手帐不再重复分组标题。
    static func singleSection(
        _ entries: [WordBookEntrySnapshot],
        id: String
    ) -> [JournalSection<WordBookEntrySnapshot>] {
        guard !entries.isEmpty else { return [] }
        return [JournalSection(id: id, title: nil, subtitle: nil, items: entries)]
    }
}

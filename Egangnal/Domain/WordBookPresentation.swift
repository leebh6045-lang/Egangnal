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

    static func dates(in entries: [WordBookEntrySnapshot]) -> [VocabularyDocumentDate] {
        Set(entries.flatMap(\.occurrenceDates)).sorted(by: >)
    }
}

//
//  LexiconModels.swift
//  Egangnal
//

import Foundation

/// 词库的考试等级。
///
/// 原始值必须与构建产物 `entry_level.level` 完全一致；改动会让所有等级筛选失效。
enum VocabularyLevel: String, CaseIterable, Identifiable, Codable, Hashable, Sendable {
    // 声明顺序 = 筛选条顺序 = 词条等级展示顺序，一律由高到低。
    case cet6
    case cet4
    case seniorHigh
    case juniorHigh

    var id: Self { self }

    var title: String {
        switch self {
        case .juniorHigh: "初中"
        case .seniorHigh: "高中"
        case .cet4: "四级"
        case .cet6: "六级"
        }
    }

    /// 由高到低的展示次序，用于等级筛选条与词条的等级标注。
    var sortOrder: Int {
        switch self {
        case .cet6: 0
        case .cet4: 1
        case .seniorHigh: 2
        case .juniorHigh: 3
        }
    }
}

/// 词库中的一个词条快照。
///
/// 公共词库整体只读，因此这里只保留展示需要的值类型，不映射为 SwiftData 模型，
/// 也不与个人单词本共享唯一键空间（见 ADR-003）。
struct LexiconEntry: Identifiable, Equatable, Sendable {
    /// 构建期生成的确定性 UUID；重建词库后保持不变，因此可以直接作为列表身份。
    let id: UUID
    let term: String
    let phonetic: String?
    /// 词性词义。保留词性前缀与真实换行，界面负责换行展示。
    let gloss: String
    let levels: [VocabularyLevel]

    init(
        id: UUID,
        term: String,
        phonetic: String?,
        gloss: String,
        levels: [VocabularyLevel]
    ) {
        self.id = id
        self.term = term
        self.phonetic = phonetic
        self.gloss = gloss
        // 统一排序，避免 group_concat 的返回顺序影响相等性判断与展示。
        self.levels = levels.sorted { $0.sortOrder < $1.sortOrder }
    }

    /// 勘察显示音标缺失率 0.94%，界面据此决定是否占位。
    var displayPhonetic: String? {
        guard let phonetic, !phonetic.isEmpty else { return nil }
        return phonetic
    }
}

/// 词库的检索模式。
///
/// 中文释义里含有 `vt.`、`vi.`、`[计]` 这类 ASCII 内容。如果英文前缀与中文释义
/// 两种匹配同时生效，输入单个字母 `v` 会命中全部动词（实测 3,353 条，占词库 47%），
/// 结果无法使用。因此必须**二选一**：按输入是否含中日韩字符决定走哪条路。
enum LexiconSearchMode: Equatable, Sendable {
    case englishPrefix
    case chineseMeaning

    static func mode(for keyword: String) -> LexiconSearchMode {
        keyword.unicodeScalars.contains(where: isCJK) ? .chineseMeaning : .englishPrefix
    }

    /// 汉字（含扩展区与兼容区）与日文假名。
    private static func isCJK(_ scalar: Unicode.Scalar) -> Bool {
        switch scalar.value {
        case 0x3040...0x30FF,  // 平假名与片假名
             0x3400...0x4DBF,  // 中日韩统一表意文字扩展 A
             0x4E00...0x9FFF,  // 中日韩统一表意文字基本区
             0xF900...0xFAFF:  // 兼容表意文字
            true
        default:
            false
        }
    }
}

/// 一次词库查询意图。关键词为空表示按等级浏览。
struct LexiconQuery: Equatable, Sendable {
    /// 每页 50 条。单词本用 20 条是因为数据量小；词库有 7,116 条，
    /// 按 20 条需要 356 页，翻页不现实。
    static let pageSize = 50

    var keyword: String
    var level: VocabularyLevel?
    var pageIndex: Int
    /// 浏览时的洗牌种子；`nil` 表示按词频排序（搜索时使用）。
    ///
    /// 用种子而不是 `ORDER BY RANDOM()`：后者会让第 1 页与第 2 页重叠，
    /// 而且每次翻页结果都变。种子固定时整批顺序稳定，换种子时整批变化。
    var shuffleSeed: Int?

    init(
        keyword: String = "",
        level: VocabularyLevel? = nil,
        pageIndex: Int = 0,
        shuffleSeed: Int? = nil
    ) {
        self.keyword = keyword
        self.level = level
        self.pageIndex = max(0, pageIndex)
        self.shuffleSeed = shuffleSeed
    }

    var isBrowsing: Bool {
        keyword.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var searchMode: LexiconSearchMode {
        LexiconSearchMode.mode(for: keyword)
    }
}

/// 一页词库结果。
struct LexiconPage: Equatable, Sendable {
    let entries: [LexiconEntry]
    let totalCount: Int
    let pageIndex: Int
    let pageSize: Int

    static let empty = LexiconPage(
        entries: [],
        totalCount: 0,
        pageIndex: 0,
        pageSize: LexiconQuery.pageSize
    )

    /// 总数为 0 时页数也是 0，避免空结果被算成"第 1 页"。
    var pageCount: Int {
        guard totalCount > 0 else { return 0 }
        return (totalCount + pageSize - 1) / pageSize
    }

    var hasPreviousPage: Bool { pageIndex > 0 }

    var hasNextPage: Bool { pageIndex + 1 < pageCount }

    var isEmpty: Bool { entries.isEmpty }

    /// 当前页第一条在整个结果中的序号，用于"第 x–y 条，共 n 条"。
    var firstItemNumber: Int {
        entries.isEmpty ? 0 : pageIndex * pageSize + 1
    }

    var lastItemNumber: Int {
        pageIndex * pageSize + entries.count
    }
}

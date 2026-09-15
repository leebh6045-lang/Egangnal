//
//  LexiconRepository.swift
//  Egangnal
//

import Foundation
import SQLite3

enum LexiconRepositoryError: Error, Equatable, LocalizedError {
    case resourceMissing
    case openFailed(String)
    case schemaMissing
    case schemaUnsupported(found: String?, expected: String)
    case queryFailed(String)

    var errorDescription: String? {
        switch self {
        case .resourceMissing:
            "集词阁数据缺失，暂时无法浏览。"
        case let .openFailed(message):
            "集词阁打开失败：\(message)"
        case .schemaMissing:
            "集词阁缺少版本信息，无法确认数据结构。"
        case let .schemaUnsupported(found, expected):
            "集词阁版本不兼容：当前 \(found ?? "未知")，需要 \(expected)。"
        case let .queryFailed(message):
            "集词阁查询失败：\(message)"
        }
    }
}

/// 词库产物的结构约定，必须与《ECDICT 离线词库构建契约》第 6 节一致。
enum LexiconSchema {
    static let supportedVersion = "1"
    static let resourceName = "EgangnalLexicon"
    static let resourceExtension = "sqlite"
}

/// 公共词库的只读访问边界。
///
/// 只提供读取，不提供任何写入方法：个人数据只能经 `WordBookRepository` 进入 SwiftData，
/// 这样"公共只读 / 个人可写"两个抽屉不会互相污染（ADR-003 决策 1、2）。
@MainActor
protocol LexiconRepository: AnyObject {
    func page(matching query: LexiconQuery) throws -> LexiconPage

    /// 一次返回整个筛选结果，供单词刷抽题使用。
    ///
    /// 分页是词库列表的**界面**约束，不是查询层的语义上限：抽题需要拿到筛选范围内的全部词条，
    /// 否则只能考到当前页那 50 个。实现必须与 `page(matching:)` 共用同一套筛选条件，
    /// 避免两条路径随迭代漂移出不同语义。
    func entries(matching query: LexiconQuery) throws -> [LexiconEntry]
}

/// 基于系统自带 libsqlite3 的只读实现，不引入任何第三方依赖。
@MainActor
final class SQLiteLexiconRepository: LexiconRepository {
    /// 前缀检索上界。Unicode 最大标量，保证范围查询覆盖所有以关键词开头的词，
    /// 从而命中 search_term 上的 B-tree 索引，而不是退化成全表扫描。
    private static let prefixUpperBound = "\u{10FFFF}"

    /// 只读连接句柄。
    ///
    /// 标记 `nonisolated(unsafe)` 是为了让 deinit 能关闭连接：句柄在 init 后不再变化，
    /// 所有查询都在主 actor 上执行，deinit 运行时已不存在其他引用，因此不会有并发访问。
    private nonisolated(unsafe) let database: OpaquePointer

    init(databaseURL: URL) throws {
        var handle: OpaquePointer?
        // 只读打开：即使应用被篡改，也无法通过这条连接改写词库。
        guard sqlite3_open_v2(databaseURL.path, &handle, SQLITE_OPEN_READONLY, nil) == SQLITE_OK,
              let opened = handle else {
            let message = handle.map { String(cString: sqlite3_errmsg($0)) } ?? "无法打开文件"
            if let handle {
                sqlite3_close(handle)
            }
            throw LexiconRepositoryError.openFailed(message)
        }

        database = opened
        do {
            try validateSchemaVersion()
        } catch {
            sqlite3_close(opened)
            throw error
        }
    }

    deinit {
        sqlite3_close(database)
    }

    func page(matching query: LexiconQuery) throws -> LexiconPage {
        var dataBindings = filterBindings(for: query)

        // 浏览时洗牌，搜索时按词频排序（搜索是定向的，稳定的顺序更有用）。
        let orderClause: String
        if query.isBrowsing, let seed = query.shuffleSeed {
            // 种子必须参与乘法：若写成 (id * K + seed) % P，改种子只是整体平移，
            // 排序结果几乎不变，等于没洗牌。
            orderClause = "\(Self.shuffleOrderPrefix(level: query.level))"
                + " * (((e.id + CAST(? AS INTEGER)) * 2654435761) % 1000000007),"
                + " e.search_term"
            dataBindings.append(String(seed))
        } else {
            orderClause = "(e.frequency_rank IS NULL), e.frequency_rank, e.search_term"
        }

        let entries = try fetchEntries(
            whereClause: filterClause(for: query),
            orderClause: orderClause,
            bindings: dataBindings,
            limit: LexiconQuery.pageSize,
            offset: query.pageIndex * LexiconQuery.pageSize
        )

        return LexiconPage(
            entries: entries,
            totalCount: try countEntries(
                whereClause: filterClause(for: query),
                bindings: filterBindings(for: query)
            ),
            pageIndex: query.pageIndex,
            pageSize: LexiconQuery.pageSize
        )
    }

    func entries(matching query: LexiconQuery) throws -> [LexiconEntry] {
        // 抽题不需要洗牌：引擎自己会随机抽样并打乱选项顺序。
        // 用稳定的词频顺序，让"同样的筛选得到同样的候选集"可复现、可测试。
        try fetchEntries(
            whereClause: filterClause(for: query),
            orderClause: "(e.frequency_rank IS NULL), e.frequency_rank, e.search_term",
            bindings: filterBindings(for: query),
            limit: nil,
            offset: 0
        )
    }

    // MARK: - 筛选条件（分页与不分页共用）

    /// 把查询意图翻译成 SQL 片段。
    ///
    /// 参数一律走绑定，禁止拼接用户输入；`page(matching:)` 与 `entries(matching:)` 必须共用本方法，
    /// 否则"列表看到的"和"考到的"会不一致。
    private func filterClause(for query: LexiconQuery) -> String {
        var conditions: [String] = []

        if query.level != nil {
            conditions.append("e.id IN (SELECT entry_id FROM entry_level WHERE level = ?)")
        }

        switch query.searchMode {
        case .englishPrefix:
            if !normalizedKeyword(query.keyword).isEmpty {
                conditions.append("e.search_term >= ? AND e.search_term < ?")
            }
        case .chineseMeaning:
            // 子串匹配用不上 B-tree 索引，但释义总字节仅约 208 KB，
            // 实测全表扫描 1–2 ms，当前规模不需要 FTS5。
            for _ in Self.meaningSearchTokens(from: query.keyword) {
                conditions.append("e.chinese_translation LIKE ? ESCAPE '\\'")
            }
        }

        return conditions.isEmpty
            ? ""
            : "WHERE " + conditions.joined(separator: " AND ")
    }

    /// 与 `filterClause(for:)` 一一对应的绑定值，顺序必须完全一致。
    private func filterBindings(for query: LexiconQuery) -> [String] {
        var bindings: [String] = []

        if let level = query.level {
            bindings.append(level.rawValue)
        }

        switch query.searchMode {
        case .englishPrefix:
            let keyword = normalizedKeyword(query.keyword)
            if !keyword.isEmpty {
                bindings.append(keyword)
                bindings.append(keyword + Self.prefixUpperBound)
            }

        case .chineseMeaning:
            for token in Self.meaningSearchTokens(from: query.keyword) {
                bindings.append(Self.meaningSearchPattern(for: token))
            }
        }

        return bindings
    }

    private func normalizedKeyword(_ keyword: String) -> String {
        WordNormalizer.normalizedTerm(keyword, in: .english)
    }

    /// “全部”视图下让四级/六级词获得更小的排序区间，从而倾向于排在前面。
    ///
    /// 用乘系数而不是分区：直接把四六级全部排在最前会让初高中独有的词
    /// 永远落在 100 页之后。乘 3 只是拉大它们的排序键，仍然与其它词混排。
    private static func shuffleOrderPrefix(level: VocabularyLevel?) -> String {
        guard level == nil else { return "1" }
        return """
        CASE WHEN EXISTS (SELECT 1 FROM entry_level l \
        WHERE l.entry_id = e.id AND l.level IN ('cet4', 'cet6')) THEN 1 ELSE 3 END
        """
    }

    /// 中文检索按空白切分为多个词，所有词都必须命中（取与关系）。
    private static func meaningSearchTokens(from keyword: String) -> [String] {
        keyword
            .split(whereSeparator: \.isWhitespace)
            .map(String.init)
            .filter { !$0.isEmpty }
    }

    /// LIKE 的通配符必须转义，保证用户输入的 `%`、`_` 只当作普通字符。
    private static func meaningSearchPattern(for token: String) -> String {
        var escaped = token.replacingOccurrences(of: "\\", with: "\\\\")
        escaped = escaped.replacingOccurrences(of: "%", with: "\\%")
        escaped = escaped.replacingOccurrences(of: "_", with: "\\_")
        return "%\(escaped)%"
    }

    // MARK: - 查询实现

    private func countEntries(whereClause: String, bindings: [String]) throws -> Int {
        let statement = try prepare(
            "SELECT COUNT(*) FROM dictionary_entry e \(whereClause);"
        )
        defer { sqlite3_finalize(statement) }
        try bind(bindings, to: statement)

        guard sqlite3_step(statement) == SQLITE_ROW else {
            throw LexiconRepositoryError.queryFailed(lastErrorMessage())
        }
        return Int(sqlite3_column_int64(statement, 0))
    }

    private func fetchEntries(
        whereClause: String,
        orderClause: String,
        bindings: [String],
        limit: Int?,
        offset: Int
    ) throws -> [LexiconEntry] {
        // 不分页时不拼 LIMIT/OFFSET，让分页与不分页两条路径共用同一段 SQL 主体。
        let paginationClause = limit == nil ? "" : "\nLIMIT ? OFFSET ?"
        let statement = try prepare(
            """
            SELECT e.entry_uuid, e.term, e.phonetic, e.chinese_translation,
                   (SELECT group_concat(l.level, ',')
                      FROM entry_level l WHERE l.entry_id = e.id)
            FROM dictionary_entry e
            \(whereClause)
            ORDER BY \(orderClause)\(paginationClause);
            """
        )
        defer { sqlite3_finalize(statement) }
        try bind(bindings, to: statement)

        if let limit {
            let extraBindings = Int32(bindings.count)
            sqlite3_bind_int(statement, extraBindings + 1, Int32(limit))
            sqlite3_bind_int(statement, extraBindings + 2, Int32(offset))
        }

        var entries: [LexiconEntry] = []
        while true {
            let step = sqlite3_step(statement)
            if step == SQLITE_DONE {
                break
            }
            guard step == SQLITE_ROW else {
                throw LexiconRepositoryError.queryFailed(lastErrorMessage())
            }
            entries.append(try makeEntry(from: statement))
        }
        return entries
    }

    private func makeEntry(from statement: OpaquePointer) throws -> LexiconEntry {
        // 产物由自己的构建工具生成，出现不完整记录说明产物被篡改或损坏，必须明确失败。
        guard let uuidText = text(at: 0, in: statement),
              let identifier = UUID(uuidString: uuidText),
              let term = text(at: 1, in: statement),
              let gloss = text(at: 3, in: statement) else {
            throw LexiconRepositoryError.queryFailed("词条记录不完整。")
        }

        let levels = (text(at: 4, in: statement) ?? "")
            .split(separator: ",")
            .compactMap { VocabularyLevel(rawValue: String($0)) }

        return LexiconEntry(
            id: identifier,
            term: term,
            phonetic: text(at: 2, in: statement),
            gloss: gloss,
            levels: levels
        )
    }

    private func validateSchemaVersion() throws {
        var statement: OpaquePointer?
        let sql = "SELECT value FROM metadata WHERE key = 'schema_version' LIMIT 1;"
        // metadata 表不存在时 prepare 就会失败，说明这不是本项目的词库产物。
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK,
              let statement else {
            throw LexiconRepositoryError.schemaMissing
        }
        defer { sqlite3_finalize(statement) }

        guard sqlite3_step(statement) == SQLITE_ROW else {
            throw LexiconRepositoryError.schemaMissing
        }
        let found = text(at: 0, in: statement)
        guard found == LexiconSchema.supportedVersion else {
            throw LexiconRepositoryError.schemaUnsupported(
                found: found,
                expected: LexiconSchema.supportedVersion
            )
        }
    }

    // MARK: - SQLite 薄封装

    private func prepare(_ sql: String) throws -> OpaquePointer {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK,
              let statement else {
            throw LexiconRepositoryError.queryFailed(lastErrorMessage())
        }
        return statement
    }

    private func bind(_ values: [String], to statement: OpaquePointer) throws {
        for (offset, value) in values.enumerated() {
            // SQLITE_TRANSIENT 让 SQLite 复制字符串，避免 Swift 临时缓冲区提前释放。
            let result = sqlite3_bind_text(
                statement,
                Int32(offset + 1),
                value,
                -1,
                unsafeBitCast(-1, to: sqlite3_destructor_type.self)
            )
            guard result == SQLITE_OK else {
                throw LexiconRepositoryError.queryFailed(lastErrorMessage())
            }
        }
    }

    private func text(at index: Int32, in statement: OpaquePointer) -> String? {
        guard let pointer = sqlite3_column_text(statement, index) else { return nil }
        return String(cString: pointer)
    }

    private func lastErrorMessage() -> String {
        String(cString: sqlite3_errmsg(database))
    }
}

extension SQLiteLexiconRepository {
    /// 从 App bundle 打开随包发布的词库。
    ///
    /// 资源缺失或版本不兼容时抛出明确错误，由组合根决定降级方式，
    /// 不允许静默退化成"空词库"而让用户以为词库本来就是空的。
    static func live(bundle: Bundle = .main) throws -> SQLiteLexiconRepository {
        guard let url = bundle.url(
            forResource: LexiconSchema.resourceName,
            withExtension: LexiconSchema.resourceExtension
        ) else {
            throw LexiconRepositoryError.resourceMissing
        }
        return try SQLiteLexiconRepository(databaseURL: url)
    }
}

/// 词库不可用时的明确失败实现。
///
/// 保留原始失败原因，让页面区分“资源缺失”与“版本不兼容”，
/// 而不是统一伪装成空词库让用户以为词库本来就是空的。
@MainActor
final class UnavailableLexiconRepository: LexiconRepository {
    private let failure: LexiconRepositoryError

    init(failure: LexiconRepositoryError = .resourceMissing) {
        self.failure = failure
    }

    func page(matching query: LexiconQuery) throws -> LexiconPage {
        throw failure
    }

    func entries(matching query: LexiconQuery) throws -> [LexiconEntry] {
        throw failure
    }
}

/// 预览与界面测试使用的内存样本，不读取真实数据库。
///
/// 只近似真实仓储的筛选与分页语义，用于让 SwiftUI 预览在没有 bundle 资源时也能渲染。
@MainActor
final class PreviewLexiconRepository: LexiconRepository {
    static let samples: [LexiconEntry] = [
        LexiconEntry(
            id: UUID(),
            term: "apple",
            phonetic: "'æpl",
            gloss: "n. 苹果, 家伙",
            levels: [.juniorHigh, .seniorHigh]
        ),
        LexiconEntry(
            id: UUID(),
            term: "abandon",
            phonetic: "ә'bændәn",
            gloss: "vt. 放弃, 抛弃, 遗弃",
            levels: [.seniorHigh, .cet4, .cet6]
        ),
        LexiconEntry(
            id: UUID(),
            term: "ambiguous",
            phonetic: "æm'bigjuәs",
            gloss: "a. 不明确的, 模棱两可的",
            levels: [.seniorHigh, .cet6]
        )
    ]

    private let entries: [LexiconEntry]

    init(entries: [LexiconEntry] = PreviewLexiconRepository.samples) {
        self.entries = entries.sorted { $0.term < $1.term }
    }

    func page(matching query: LexiconQuery) throws -> LexiconPage {
        let filtered = filteredEntries(matching: query)
        let offset = query.pageIndex * LexiconQuery.pageSize
        let slice: [LexiconEntry]
        if offset >= filtered.count {
            slice = []
        } else {
            slice = Array(
                filtered[offset..<min(offset + LexiconQuery.pageSize, filtered.count)]
            )
        }

        return LexiconPage(
            entries: slice,
            totalCount: filtered.count,
            pageIndex: query.pageIndex,
            pageSize: LexiconQuery.pageSize
        )
    }

    func entries(matching query: LexiconQuery) throws -> [LexiconEntry] {
        filteredEntries(matching: query)
    }

    /// 分页与不分页共用同一套筛选，保证"列表看到的"和"考到的"一致。
    private func filteredEntries(matching query: LexiconQuery) -> [LexiconEntry] {
        let keyword = WordNormalizer.normalizedTerm(query.keyword, in: .english)
        let tokens = query.keyword
            .split(whereSeparator: \.isWhitespace)
            .map(String.init)

        return entries.filter { entry in
            if let level = query.level, !entry.levels.contains(level) {
                return false
            }
            switch query.searchMode {
            case .englishPrefix:
                guard !keyword.isEmpty else { return true }
                return WordNormalizer
                    .normalizedTerm(entry.term, in: .english)
                    .hasPrefix(keyword)
            case .chineseMeaning:
                guard !tokens.isEmpty else { return true }
                return tokens.allSatisfy { entry.gloss.contains($0) }
            }
        }
    }
}

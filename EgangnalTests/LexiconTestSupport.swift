//
//  LexiconTestSupport.swift
//  EgangnalTests
//

import Foundation
import SQLite3
@testable import Egangnal

enum LexiconTestError: Error, CustomStringConvertible {
    case databaseMissing(String)
    case fixturesMissing(String)
    case temporaryDatabaseFailed(String)
    case queryFailed(String)

    var description: String {
        switch self {
        case let .databaseMissing(path):
            "找不到词库产物：\(path)。请先运行 tools/lexicon-builder/build_ecdict.py。"
        case let .fixturesMissing(path):
            "找不到规范化固定样例：\(path)。"
        case let .temporaryDatabaseFailed(message):
            "无法创建测试用临时数据库：\(message)"
        case let .queryFailed(message):
            "测试读取词库失败：\(message)"
        }
    }
}

/// 词库测试共用的路径解析与轻量 SQLite 读写。
///
/// 路径通过 `#filePath` 从编译期源文件位置反推仓库根目录，因此测试直接读取
/// 构建产物与构建工具共用的固定样例，不复制副本、不依赖 bundle 资源。
enum LexiconTestSupport {
    static var repositoryRoot: URL {
        // <repo>/EgangnalTests/LexiconTestSupport.swift
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // <repo>/EgangnalTests
            .deletingLastPathComponent()  // <repo>
    }

    static var databaseURL: URL {
        repositoryRoot
            .appending(path: "Egangnal")
            .appending(path: "Resources")
            .appending(path: "Lexicon")
            .appending(path: "EgangnalLexicon.sqlite")
    }

    static var normalizationFixturesURL: URL {
        repositoryRoot
            .appending(path: "tools")
            .appending(path: "lexicon-builder")
            .appending(path: "fixtures")
            .appending(path: "normalization-cases.json")
    }

    /// 词库缺失时直接失败。静默跳过会让"测试通过"失去意义。
    @MainActor
    static func makeRepository() throws -> SQLiteLexiconRepository {
        guard FileManager.default.fileExists(atPath: databaseURL.path) else {
            throw LexiconTestError.databaseMissing(databaseURL.path)
        }
        return try SQLiteLexiconRepository(databaseURL: databaseURL)
    }

    // MARK: - 直接读取（仅测试使用）

    /// 读取产物中全部 (term, search_term) 对，用于校验构建期与运行期规范化完全一致。
    static func termSearchPairs() throws -> [(term: String, searchTerm: String)] {
        try withReadOnlyConnection { handle in
            var statement: OpaquePointer?
            let sql = "SELECT term, search_term FROM dictionary_entry;"
            guard sqlite3_prepare_v2(handle, sql, -1, &statement, nil) == SQLITE_OK,
                  let statement else {
                throw LexiconTestError.queryFailed(String(cString: sqlite3_errmsg(handle)))
            }
            defer { sqlite3_finalize(statement) }

            var pairs: [(term: String, searchTerm: String)] = []
            while true {
                let step = sqlite3_step(statement)
                if step == SQLITE_DONE { break }
                guard step == SQLITE_ROW else {
                    throw LexiconTestError.queryFailed(String(cString: sqlite3_errmsg(handle)))
                }
                guard let termPointer = sqlite3_column_text(statement, 0),
                      let searchPointer = sqlite3_column_text(statement, 1) else {
                    throw LexiconTestError.queryFailed("发现不完整的词条记录。")
                }
                pairs.append((String(cString: termPointer), String(cString: searchPointer)))
            }
            return pairs
        }
    }

    private static func withReadOnlyConnection<T>(
        _ body: (OpaquePointer) throws -> T
    ) throws -> T {
        var handle: OpaquePointer?
        guard sqlite3_open_v2(databaseURL.path, &handle, SQLITE_OPEN_READONLY, nil) == SQLITE_OK,
              let handle else {
            throw LexiconTestError.databaseMissing(databaseURL.path)
        }
        defer { sqlite3_close(handle) }
        return try body(handle)
    }

    // MARK: - 临时数据库（用于错误路径测试）

    /// 生成一个结构不对的临时词库文件。
    /// - Parameter schemaVersion: 传入 nil 表示连 metadata 表都不建。
    static func makeTemporaryDatabase(schemaVersion: String?) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appending(path: "egangnal-lexicon-test-\(UUID().uuidString).sqlite")

        let sql: String
        if let schemaVersion {
            sql = """
            CREATE TABLE metadata (key TEXT PRIMARY KEY, value TEXT NOT NULL);
            INSERT INTO metadata (key, value)
            VALUES ('schema_version', '\(schemaVersion)');
            """
        } else {
            sql = "CREATE TABLE unrelated (id INTEGER PRIMARY KEY);"
        }

        var handle: OpaquePointer?
        let flags = SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE
        guard sqlite3_open_v2(url.path, &handle, flags, nil) == SQLITE_OK,
              let handle else {
            throw LexiconTestError.temporaryDatabaseFailed("无法创建文件")
        }
        defer { sqlite3_close(handle) }

        guard sqlite3_exec(handle, sql, nil, nil, nil) == SQLITE_OK else {
            throw LexiconTestError.temporaryDatabaseFailed(String(cString: sqlite3_errmsg(handle)))
        }
        return url
    }
}

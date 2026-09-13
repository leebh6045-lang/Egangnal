//
//  LexiconRepositoryTests.swift
//  EgangnalTests
//

import Foundation
import Testing
@testable import Egangnal

/// 直接针对真实构建产物运行，验证只读查询层的语义与边界。
@MainActor
struct LexiconRepositoryTests {
    /// 与构建报告 `tools/lexicon-builder/output/build-report.json` 的基线一致。
    /// 数字变化说明产物或查询语义被改动，必须查清原因而不是改测试。
    private static let expectedTotalCount = 7116
    private static let expectedLevelCounts: [VocabularyLevel: Int] = [
        .juniorHigh: 1603,
        .seniorHigh: 3677,
        .cet4: 3849,
        .cet6: 5407
    ]

    @Test @MainActor
    func browsingWithoutLevelReturnsBaselineTotal() throws {
        let repository = try LexiconTestSupport.makeRepository()

        let page = try repository.page(matching: LexiconQuery())

        #expect(page.totalCount == Self.expectedTotalCount)
        #expect(page.entries.count == LexiconQuery.pageSize)
        // 7116 ÷ 50 = 142.32，向上取整为 143 页。
        #expect(page.pageCount == 143)
    }

    @Test @MainActor
    func levelFiltersReportBaselineCounts() throws {
        let repository = try LexiconTestSupport.makeRepository()

        for level in VocabularyLevel.allCases {
            let page = try repository.page(matching: LexiconQuery(level: level))
            let expected = try #require(Self.expectedLevelCounts[level])
            #expect(page.totalCount == expected, "等级 \(level.rawValue) 数量不符")
        }
    }

    @Test @MainActor
    func levelFilterReturnsOnlyEntriesOfThatLevel() throws {
        let repository = try LexiconTestSupport.makeRepository()

        for level in VocabularyLevel.allCases {
            let page = try repository.page(matching: LexiconQuery(level: level))
            let offenders = page.entries.filter { !$0.levels.contains(level) }
            #expect(offenders.isEmpty, "等级 \(level.rawValue) 混入了其他等级的词条")
        }
    }

    @Test @MainActor
    func firstPageIsNumberedFromOne() throws {
        let repository = try LexiconTestSupport.makeRepository()

        let page = try repository.page(matching: LexiconQuery())

        #expect(page.firstItemNumber == 1)
        #expect(page.lastItemNumber == 50)
        #expect(page.hasPreviousPage == false)
        #expect(page.hasNextPage == true)
    }

    @Test @MainActor
    func lastPageCarriesRemainderEntries() throws {
        let repository = try LexiconTestSupport.makeRepository()
        let lastIndex = 142

        let page = try repository.page(matching: LexiconQuery(pageIndex: lastIndex))

        // 7116 = 142 × 50 + 16
        #expect(page.entries.count == 16)
        #expect(page.firstItemNumber == 7101)
        #expect(page.lastItemNumber == 7116)
        #expect(page.hasPreviousPage == true)
        #expect(page.hasNextPage == false)
    }

    @Test @MainActor
    func pageBeyondLastPageIsEmptyButKeepsTotal() throws {
        let repository = try LexiconTestSupport.makeRepository()

        let page = try repository.page(matching: LexiconQuery(pageIndex: 9_999))

        #expect(page.isEmpty)
        #expect(page.totalCount == Self.expectedTotalCount)
        #expect(page.firstItemNumber == 0)
    }

    @Test @MainActor
    func negativePageIndexIsClampedToFirstPage() throws {
        let repository = try LexiconTestSupport.makeRepository()

        let page = try repository.page(matching: LexiconQuery(pageIndex: -5))

        #expect(page.pageIndex == 0)
        #expect(page.firstItemNumber == 1)
    }

    @Test @MainActor
    func prefixSearchFindsExpectedWord() throws {
        let repository = try LexiconTestSupport.makeRepository()

        let page = try repository.page(matching: LexiconQuery(keyword: "aban"))

        #expect(page.totalCount >= 1)
        #expect(page.entries.contains { $0.term == "abandon" })
    }

    @Test @MainActor
    func searchIgnoresCaseAndSurroundingWhitespace() throws {
        let repository = try LexiconTestSupport.makeRepository()

        let expected = try repository.page(matching: LexiconQuery(keyword: "apple"))
        let upper = try repository.page(matching: LexiconQuery(keyword: "APPLE"))
        let padded = try repository.page(matching: LexiconQuery(keyword: "  apple  "))

        #expect(expected.totalCount >= 1)
        #expect(upper.entries.map(\.id) == expected.entries.map(\.id))
        #expect(padded.entries.map(\.id) == expected.entries.map(\.id))
    }

    @Test @MainActor
    func fullWordSearchReturnsSingleEntry() throws {
        let repository = try LexiconTestSupport.makeRepository()

        let page = try repository.page(matching: LexiconQuery(keyword: "apple"))

        #expect(page.entries.contains { entry in
            entry.term == "apple" && entry.levels.contains(.juniorHigh)
        })
    }

    @Test @MainActor
    func searchWithoutMatchReturnsEmptyPage() throws {
        let repository = try LexiconTestSupport.makeRepository()

        let page = try repository.page(matching: LexiconQuery(keyword: "zzzzzzzz"))

        #expect(page.isEmpty)
        #expect(page.totalCount == 0)
        // 空结果页数必须是 0，否则界面会显示"第 1 / 1 页"。
        #expect(page.pageCount == 0)
        #expect(page.hasNextPage == false)
    }

    @Test @MainActor
    func levelAndKeywordFiltersCombine() throws {
        let repository = try LexiconTestSupport.makeRepository()

        let page = try repository.page(
            matching: LexiconQuery(keyword: "aban", level: .cet6)
        )

        #expect(page.entries.contains { $0.term == "abandon" })
        #expect(page.entries.allSatisfy { $0.levels.contains(.cet6) })
    }

    @Test @MainActor
    func orderingIsStableAcrossRepeatedQueries() throws {
        let repository = try LexiconTestSupport.makeRepository()
        let query = LexiconQuery(level: .cet6, pageIndex: 3)

        let first = try repository.page(matching: query)
        let second = try repository.page(matching: query)

        #expect(first.entries.map(\.id) == second.entries.map(\.id))
    }

    // MARK: - 不分页入口（等级速测用）

    /// 抽题需要拿到筛选范围内的**全部**词条，不能只拿当前页 50 条。
    @Test @MainActor
    func unpaginatedEntriesReturnTheWholeFilteredRange() throws {
        let repository = try LexiconTestSupport.makeRepository()

        for level in VocabularyLevel.allCases {
            let entries = try repository.entries(matching: LexiconQuery(level: level))
            let expected = try #require(Self.expectedLevelCounts[level])
            #expect(entries.count == expected, "等级 \(level.rawValue) 全量读取数量不符")
            #expect(entries.allSatisfy { $0.levels.contains(level) })
        }

        let all = try repository.entries(matching: LexiconQuery())
        #expect(all.count == Self.expectedTotalCount)
        #expect(Set(all.map(\.id)).count == Self.expectedTotalCount)
    }

    /// 两条读法必须等价：分页翻完的合集要与一次性读取**逐条相同**（含顺序）。
    /// 一旦 WHERE 子句或排序在两条路径上分叉，"列表看到的"和"考到的"就会不一致。
    @Test @MainActor
    func paginatedAndUnpaginatedReadsAgreeEntryByEntry() throws {
        let repository = try LexiconTestSupport.makeRepository()
        let queries = [
            LexiconQuery(level: .cet4),
            LexiconQuery(keyword: "ab"),
            LexiconQuery(keyword: "放弃")
        ]

        for query in queries {
            let unpaginated = try repository.entries(matching: query)

            var paged: [LexiconEntry] = []
            var pageIndex = 0
            while true {
                let page = try repository.page(
                    matching: LexiconQuery(
                        keyword: query.keyword,
                        level: query.level,
                        pageIndex: pageIndex
                    )
                )
                paged.append(contentsOf: page.entries)
                guard page.hasNextPage else { break }
                pageIndex += 1
            }

            #expect(
                unpaginated.map(\.id) == paged.map(\.id),
                "查询 \(query.keyword) 的两条读法结果不一致"
            )
        }
    }

    @Test @MainActor
    func unpaginatedSearchRespectsModeAndReturnsEmptyForNoMatch() throws {
        let repository = try LexiconTestSupport.makeRepository()

        let prefix = try repository.entries(matching: LexiconQuery(keyword: "aban"))
        let chinese = try repository.entries(matching: LexiconQuery(keyword: "放弃"))
        let missing = try repository.entries(matching: LexiconQuery(keyword: "zzzzqqqq"))

        #expect(prefix.contains { $0.term == "abandon" })
        #expect(chinese.contains { $0.term == "abandon" })
        #expect(missing.isEmpty)
    }

    // MARK: - 中文释义检索

    @Test @MainActor
    func chineseKeywordSearchesMeanings() throws {
        let repository = try LexiconTestSupport.makeRepository()

        let page = try repository.page(matching: LexiconQuery(keyword: "放弃"))

        #expect(page.totalCount > 0)
        #expect(page.entries.contains { $0.term == "abandon" })
        #expect(page.entries.allSatisfy { $0.gloss.contains("放弃") })
    }

    @Test @MainActor
    func chineseSearchRequiresEveryToken() throws {
        let repository = try LexiconTestSupport.makeRepository()

        let both = try repository.page(matching: LexiconQuery(keyword: "放弃 抛弃"))
        let single = try repository.page(matching: LexiconQuery(keyword: "抛弃"))

        #expect(both.totalCount > 0)
        // 与关系：多词结果必然是单词结果的子集。
        #expect(both.totalCount <= single.totalCount)
        #expect(both.entries.allSatisfy { entry in
            entry.gloss.contains("放弃") && entry.gloss.contains("抛弃")
        })
    }

    @Test @MainActor
    func chineseSearchCombinesWithLevelFilter() throws {
        let repository = try LexiconTestSupport.makeRepository()

        let page = try repository.page(
            matching: LexiconQuery(keyword: "放弃", level: .juniorHigh)
        )

        #expect(page.entries.allSatisfy { entry in
            entry.gloss.contains("放弃") && entry.levels.contains(.juniorHigh)
        })
    }

    @Test @MainActor
    func chineseSearchWithoutMatchIsEmpty() throws {
        let repository = try LexiconTestSupport.makeRepository()

        let page = try repository.page(matching: LexiconQuery(keyword: "这个词不存在"))

        #expect(page.isEmpty)
        #expect(page.totalCount == 0)
    }

    /// 中文模式同样必须把 `%`、`_` 当作普通字符，而不是 LIKE 通配符。
    @Test @MainActor
    func chineseSearchEscapesLikeWildcards() throws {
        let repository = try LexiconTestSupport.makeRepository()

        let wildcard = try repository.page(matching: LexiconQuery(keyword: "的%"))
        #expect(wildcard.totalCount == 0)

        let underscore = try repository.page(matching: LexiconQuery(keyword: "的_"))
        #expect(underscore.totalCount == 0)

        // 词库里确实有大量含"的"的词条，说明上面为 0 不是因为没数据。
        let plain = try repository.page(matching: LexiconQuery(keyword: "的"))
        #expect(plain.totalCount > 0)
    }

    // MARK: - 浏览洗牌

    /// 默认（不带种子）仍然是词频顺序，搜索与对照依赖它。
    @Test @MainActor
    func browsingWithoutSeedKeepsFrequencyOrder() throws {
        let repository = try LexiconTestSupport.makeRepository()

        let page = try repository.page(matching: LexiconQuery())

        #expect(page.entries.first?.term == "the")
    }

    @Test @MainActor
    func shuffleOrderIsStableForTheSameSeed() throws {
        let repository = try LexiconTestSupport.makeRepository()
        let query = LexiconQuery(pageIndex: 2, shuffleSeed: 4_242)

        let first = try repository.page(matching: query)
        let second = try repository.page(matching: query)

        #expect(first.entries.map(\.id) == second.entries.map(\.id))
    }

    @Test @MainActor
    func differentSeedsProduceDifferentFirstPages() throws {
        let repository = try LexiconTestSupport.makeRepository()

        let first = try repository.page(matching: LexiconQuery(shuffleSeed: 1))
        let second = try repository.page(matching: LexiconQuery(shuffleSeed: 2))

        #expect(first.entries.map(\.id) != second.entries.map(\.id))
    }

    /// 种子分页必须不重不漏：这是"换一批"能正常翻页的前提。
    @Test @MainActor
    func shuffledPaginationCoversEveryEntryExactlyOnce() throws {
        let repository = try LexiconTestSupport.makeRepository()
        var seen = Set<UUID>()
        var duplicates = 0

        for pageIndex in 0..<143 {
            let page = try repository.page(
                matching: LexiconQuery(pageIndex: pageIndex, shuffleSeed: 20_260_911)
            )
            for entry in page.entries where !seen.insert(entry.id).inserted {
                duplicates += 1
            }
        }

        #expect(duplicates == 0, "同一批词不能在不同页之间重复出现")
        #expect(seen.count == Self.expectedTotalCount)
    }

    /// "全部"视图下四级/六级应明显靠前，但不会把其它词彻底挤掉。
    @Test @MainActor
    func allViewFavorsCet4AndCet6Entries() throws {
        let repository = try LexiconTestSupport.makeRepository()
        var priorityCount = 0
        var total = 0

        for pageIndex in 0..<3 {
            let page = try repository.page(
                matching: LexiconQuery(pageIndex: pageIndex, shuffleSeed: 20_260_911)
            )
            for entry in page.entries {
                total += 1
                if entry.levels.contains(.cet4) || entry.levels.contains(.cet6) {
                    priorityCount += 1
                }
            }
        }

        #expect(total == 150)
        #expect(
            priorityCount >= Int(Double(total) * 0.9),
            "前 3 页应几乎全是四六级词，实际 \(priorityCount)/\(total)"
        )
    }

    /// 选定具体等级时不启用四六级加权：那一级里所有词本来就同级。
    @Test @MainActor
    func levelBrowsingDoesNotApplyPriorityWeighting() throws {
        let repository = try LexiconTestSupport.makeRepository()

        let page = try repository.page(
            matching: LexiconQuery(level: .juniorHigh, shuffleSeed: 20_260_911)
        )

        #expect(page.entries.allSatisfy { $0.levels.contains(.juniorHigh) })
    }

    // MARK: - 检索模式判定

    @Test(arguments: [
        ("", LexiconSearchMode.englishPrefix),
        ("apple", .englishPrefix),
        ("aban", .englishPrefix),
        ("New York", .englishPrefix),
        ("放弃", .chineseMeaning),
        ("苹果", .chineseMeaning),
        ("能 力", .chineseMeaning),
        ("日本語", .chineseMeaning),
        ("apple苹果", .chineseMeaning)
    ])
    func searchModeIsDecidedByInputCharacters(
        keyword: String,
        expected: LexiconSearchMode
    ) {
        #expect(LexiconSearchMode.mode(for: keyword) == expected)
    }

    /// 参数绑定必须把用户输入当作普通文本：若拼接成 SQL，下面这些输入会改变语义甚至破坏数据。
    @Test @MainActor
    func specialCharactersAreBoundAsData() throws {
        let repository = try LexiconTestSupport.makeRepository()

        // LIKE 通配符在范围查询里只是普通字符，不应匹配全部词条。
        let percent = try repository.page(matching: LexiconQuery(keyword: "%"))
        #expect(percent.totalCount == 0)
        let underscore = try repository.page(matching: LexiconQuery(keyword: "_"))
        #expect(underscore.totalCount == 0)

        // 注入尝试必须被当作普通关键词，且不能损坏词库。
        let injection = try repository.page(
            matching: LexiconQuery(keyword: "'; DROP TABLE dictionary_entry;--")
        )
        #expect(injection.totalCount == 0)

        let after = try repository.page(matching: LexiconQuery())
        #expect(after.totalCount == Self.expectedTotalCount)
    }

    @Test @MainActor
    func unavailableRepositoryFailsLoudly() {
        let repository = UnavailableLexiconRepository()

        #expect(throws: LexiconRepositoryError.resourceMissing) {
            _ = try repository.page(matching: LexiconQuery())
        }
    }

    @Test @MainActor
    func missingResourceReportsOpenFailure() {
        let url = URL(fileURLWithPath: "/nonexistent/egangnal-lexicon-\(UUID().uuidString).sqlite")

        #expect(throws: LexiconRepositoryError.self) {
            _ = try SQLiteLexiconRepository(databaseURL: url)
        }
    }

    @Test @MainActor
    func unsupportedSchemaVersionIsRejected() throws {
        let url = try LexiconTestSupport.makeTemporaryDatabase(schemaVersion: "999")
        defer { try? FileManager.default.removeItem(at: url) }

        #expect(throws: LexiconRepositoryError.schemaUnsupported(found: "999", expected: "1")) {
            _ = try SQLiteLexiconRepository(databaseURL: url)
        }
    }

    @Test @MainActor
    func missingMetadataTableIsRejected() throws {
        let url = try LexiconTestSupport.makeTemporaryDatabase(schemaVersion: nil)
        defer { try? FileManager.default.removeItem(at: url) }

        #expect(throws: LexiconRepositoryError.schemaMissing) {
            _ = try SQLiteLexiconRepository(databaseURL: url)
        }
    }
}

/// 分页模型的纯边界测试，与数据库无关。
struct LexiconPageTests {
    @Test(arguments: [
        (totalCount: 0, pageCount: 0),
        (totalCount: 1, pageCount: 1),
        (totalCount: 50, pageCount: 1),
        (totalCount: 51, pageCount: 2),
        (totalCount: 100, pageCount: 2),
        (totalCount: 101, pageCount: 3)
    ])
    func pageCountMatchesPageSizeBoundaries(totalCount: Int, pageCount: Int) {
        let page = LexiconPage(
            entries: [],
            totalCount: totalCount,
            pageIndex: 0,
            pageSize: LexiconQuery.pageSize
        )

        #expect(page.pageCount == pageCount)
    }

    @Test func levelsAreSortedByDeclaredOrder() {
        let entry = LexiconEntry(
            id: UUID(),
            term: "abandon",
            phonetic: nil,
            gloss: "vt. 放弃",
            levels: [.cet6, .juniorHigh, .cet4, .seniorHigh]
        )

        #expect(entry.levels == [.cet6, .cet4, .seniorHigh, .juniorHigh])
    }

    @Test func blankPhoneticIsNotDisplayed() {
        #expect(LexiconEntry(
            id: UUID(),
            term: "a",
            phonetic: nil,
            gloss: "art. 一",
            levels: [.juniorHigh]
        ).displayPhonetic == nil)

        #expect(LexiconEntry(
            id: UUID(),
            term: "a",
            phonetic: "",
            gloss: "art. 一",
            levels: [.juniorHigh]
        ).displayPhonetic == nil)

        #expect(LexiconEntry(
            id: UUID(),
            term: "apple",
            phonetic: "'æpl",
            gloss: "n. 苹果",
            levels: [.juniorHigh]
        ).displayPhonetic == "'æpl")
    }
}

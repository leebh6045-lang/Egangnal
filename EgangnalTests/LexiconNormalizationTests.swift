//
//  LexiconNormalizationTests.swift
//  EgangnalTests
//

import Foundation
import Testing
@testable import Egangnal

/// 跨语言规范化校验。
///
/// 词库的 `search_term` 由 Python 构建工具生成，而用户输入的关键词由 Swift 规范化。
/// 两侧规则必须完全一致，否则会出现"搜得到"与"搜不到"的诡异差异。
/// 这里用同一份固定样例，并对全部真实数据做逐条比对。
struct LexiconNormalizationTests {
    @Test func swiftNormalizationMatchesSharedFixtures() throws {
        let url = LexiconTestSupport.normalizationFixturesURL
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw LexiconTestError.fixturesMissing(url.path)
        }

        let fixtures = try JSONDecoder().decode(
            NormalizationFixtureFile.self,
            from: Data(contentsOf: url)
        )
        #expect(fixtures.version == "en-v1")

        let mismatches = fixtures.cases.filter { testCase in
            WordNormalizer.normalizedTerm(testCase.input, in: .english) != testCase.expected
        }
        #expect(
            mismatches.isEmpty,
            "与固定样例不一致：\(mismatches.map { "\($0.input.debugDescription) → 期望 \($0.expected.debugDescription)" })"
        )
    }

    /// 比固定样例更强：直接校验产物中全部 7,116 条词条的查询键。
    @Test func productionSearchTermsMatchSwiftNormalization() throws {
        let pairs = try LexiconTestSupport.termSearchPairs()

        #expect(pairs.count == 7116)

        let mismatches = pairs.filter { pair in
            WordNormalizer.normalizedTerm(pair.term, in: .english) != pair.searchTerm
        }
        #expect(
            mismatches.isEmpty,
            "构建期与运行期规范化不一致：\(mismatches.prefix(5).map(\.term))"
        )
    }

    @Test func normalizationIsIdempotent() {
        let samples = ["Apple", "  New   York  ", "café", "ABANDON", "a"]

        for sample in samples {
            let once = WordNormalizer.normalizedTerm(sample, in: .english)
            let twice = WordNormalizer.normalizedTerm(once, in: .english)
            #expect(once == twice, "规范化不是幂等的：\(sample)")
        }
    }
}

private struct NormalizationFixtureFile: Decodable {
    let version: String
    let cases: [NormalizationFixtureCase]
}

private struct NormalizationFixtureCase: Decodable {
    let input: String
    let expected: String
}

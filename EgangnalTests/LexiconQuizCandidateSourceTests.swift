//
//  LexiconQuizCandidateSourceTests.swift
//  EgangnalTests
//

import Foundation
import Testing
@testable import Egangnal

/// 词库速测的候选来源与范围隔离。
///
/// 这些不变量决定了"从四级发起就只考四级"和"词库范围不碰个人单词本"两件事，
/// 一旦破坏，用户会看到范围与内容不符，或未收藏的词被写进个人数据。
@MainActor
struct LexiconQuizCandidateSourceTests {
    @Test @MainActor
    func targetsFollowTheFilterWhileDistractorsComeFromTheWholeLexicon() throws {
        let cet4 = LexiconEntry(
            id: UUID(),
            term: "abandon",
            phonetic: nil,
            gloss: "vt. 放弃, 抛弃, 遗弃",
            levels: [.cet4]
        )
        let juniorHigh = LexiconEntry(
            id: UUID(),
            term: "apple",
            phonetic: nil,
            gloss: "n. 苹果, 家伙",
            levels: [.juniorHigh]
        )
        let repository = FilteringLexiconRepository(
            entriesByQuery: [.init(level: .cet4): [cet4], .init(): [cet4, juniorHigh]]
        )
        let source = LexiconQuizCandidateSource(lexiconRepository: repository)

        let result = try source.lexiconQuizCandidates(
            in: LexiconQuizScope.level(.cet4)
        )

        // 目标集 = 筛选结果；干扰项池 = 整个词库（含初中的词）。
        #expect(result.targets.map(\.term) == ["abandon"])
        #expect(Set(result.distractors.map(\.term)) == ["abandon", "apple"])
        #expect(repository.requests == [.init(level: .cet4), .init()])
    }

    /// 范围到查询的映射：全部 → 不带任何筛选；某等级 → 只带该等级。
    @Test @MainActor
    func scopeMapsToTheExpectedQuery() throws {
        let abandon = LexiconEntry(
            id: UUID(),
            term: "abandon",
            phonetic: nil,
            gloss: "vt. 放弃, 抛弃",
            levels: [.cet4]
        )
        let repository = FilteringLexiconRepository(
            entriesByQuery: [.init(level: .cet4): [abandon], .init(): [abandon]]
        )
        let source = LexiconQuizCandidateSource(lexiconRepository: repository)

        _ = try source.lexiconQuizCandidates(in: .all)
        _ = try source.lexiconQuizCandidates(in: .level(.cet4))

        // 每次调用都会读两遍：一遍按范围取目标集，一遍取整个词库当干扰项池。
        #expect(repository.requests == [
            .init(), .init(),
            .init(level: .cet4), .init()
        ])
    }

    /// 词库释义是完整形态（中位 27 字、最长 196），必须先派生成短释义再进选项；
    /// 且**必须保留词性前缀**——考词库时选项要能看出 `n.` / `a.` 这类信息。
    @Test @MainActor
    func meaningsKeepThePartOfSpeechAndStayShort() throws {
        let entry = LexiconEntry(
            id: UUID(),
            term: "round",
            phonetic: nil,
            gloss: "n. 圆, 圆形物, 巡回, 循环, 一轮, 一回合, 一局, 范围, 轮唱\n"
                + "a. 圆的, 球形的, 丰满的, 肥胖的\n"
                + "prep. 围着, 附近, 绕过, 在...周围",
            levels: [.cet4]
        )
        let repository = FilteringLexiconRepository(
            entriesByQuery: [.init(level: .cet4): [entry], .init(): [entry]]
        )
        let source = LexiconQuizCandidateSource(lexiconRepository: repository)

        let result = try source.lexiconQuizCandidates(
            in: LexiconQuizScope.level(.cet4)
        )
        let meaning = try #require(result.targets.first?.meaning)

        #expect(meaning == LexiconGlossFormatter.browsingDisplay(from: entry.gloss).text)
        #expect(meaning == "n. 圆, 圆形物…")
        #expect(meaning.hasPrefix("n."), "选项必须带词性")
        #expect(!meaning.contains("\n"))
        #expect(meaning.count <= LexiconGlossFormatter.defaultBrowsingLength + 1)
    }

    /// 真实词库端到端：四级范围的候选确实只含四级词条，且能组出正常的四选一。
    @Test @MainActor
    func realLexiconScopeProducesAQuizzableFourChoiceSession() throws {
        let repository = try LexiconTestSupport.makeRepository()
        let source = LexiconQuizCandidateSource(lexiconRepository: repository)

        let result = try source.lexiconQuizCandidates(
            in: LexiconQuizScope.level(.cet4)
        )

        #expect(result.targets.count == 3_849)
        #expect(result.distractors.count == 7_116)
        #expect(result.targets.allSatisfy { $0.meaning.count <= 13 })

        // 词性覆盖率直接决定"选项里能看到词性"这条需求能兑现多少。
        // 判据与派生规则同源：短释义以 `词性 + .` 开头。27 条无词性前缀的特例是已知的词典事实。
        let withPartOfSpeech = result.targets.filter { candidate in
            Self.startsWithPartOfSpeech(candidate.meaning)
        }
        #expect(
            withPartOfSpeech.count >= result.targets.count - 40,
            "四级词条中带词性前缀的比例过低：\(withPartOfSpeech.count)/\(result.targets.count)"
        )

        var randomGenerator = SystemRandomNumberGenerator()
        let session = try WordQuizEngine.makeSession(
            configuration: WordQuizConfiguration(
                language: .english,
                scope: .lexicon(.level(.cet4)),
                difficulty: .simple
            ),
            targetCandidates: result.targets,
            distractorCandidates: result.distractors,
            using: &randomGenerator
        )

        let selectedIDs = Set(session.selectedCandidates.map(\.id))
        let cet4IDs = Set(result.targets.map(\.id))
        #expect(selectedIDs.isSubset(of: cet4IDs))
        let cet6OnlyIDs = Set(result.distractors.map(\.id)).subtracting(cet4IDs)
        #expect(selectedIDs.isDisjoint(with: cet6OnlyIDs))

        for question in session.questions {
            #expect(question.choiceOptions.count == 4)
            let displayTexts = question.choiceOptions.map {
                WordQuizEngine.displayText(of: $0.meaning)
            }
            #expect(Set(displayTexts).count == 4)
        }
    }

    @Test @MainActor
    func repositoryErrorsPropagateUnchanged() {
        let source = LexiconQuizCandidateSource(
            lexiconRepository: FailingLexiconRepository()
        )

        #expect(throws: FailingLexiconRepository.ExpectedFailure.self) {
            _ = try source.lexiconQuizCandidates(
                in: LexiconQuizScope.all
            )
        }
    }

    /// 与 `LexiconGlossFormatter` 的词性表保持一致的独立判据，避免测试直接复用被测实现。
    private static let partOfSpeechTokens: Set<String> = [
        "n", "v", "vt", "vi", "adj", "adv", "ad", "a",
        "prep", "pron", "conj", "interj", "int", "num",
        "art", "aux", "abbr", "pl", "sing"
    ]

    private static func startsWithPartOfSpeech(_ meaning: String) -> Bool {
        guard let separator = meaning.firstIndex(of: ".") else { return false }
        let token = meaning[meaning.startIndex..<separator]
            .trimmingCharacters(in: .whitespaces)
            .lowercased()
        return partOfSpeechTokens.contains(token)
    }
}

// MARK: - 桩仓储

/// 按查询条件回放的桩仓储；请求列表同时用于断言"查了哪些筛选"。
@MainActor
private final class FilteringLexiconRepository: LexiconRepository {
    private let entriesByQuery: [Request: [LexiconEntry]]
    private(set) var requests: [Request] = []

    struct Request: Hashable {
        var keyword = ""
        var level: VocabularyLevel?

        var searchMode: LexiconSearchMode {
            LexiconQuery(keyword: keyword).searchMode
        }
    }

    init(entriesByQuery: [Request: [LexiconEntry]]) {
        self.entriesByQuery = entriesByQuery
    }

    func page(matching query: LexiconQuery) throws -> LexiconPage {
        throw TestFailure.unexpectedCall
    }

    func entries(matching query: LexiconQuery) throws -> [LexiconEntry] {
        let request = Request(keyword: query.keyword, level: query.level)
        requests.append(request)
        return entriesByQuery[request] ?? []
    }
}

@MainActor
private final class FailingLexiconRepository: LexiconRepository {
    enum ExpectedFailure: Error {
        case failed
    }

    func page(matching query: LexiconQuery) throws -> LexiconPage {
        throw ExpectedFailure.failed
    }

    func entries(matching query: LexiconQuery) throws -> [LexiconEntry] {
        throw ExpectedFailure.failed
    }
}

private enum TestFailure: Error {
    case unexpectedCall
}

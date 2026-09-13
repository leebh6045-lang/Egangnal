//
//  LexiconGlossFormatterTests.swift
//  EgangnalTests
//

import Foundation
import Testing
@testable import Egangnal

/// 短释义派生规则的固定样例。
///
/// 样例直接取自真实产物的最长词条与无词性前缀的特例，
/// 规则变化时必须同步更新这里并提升 `LexiconGlossFormatter.version`。
struct LexiconGlossFormatterTests {
    @Test(arguments: [
        // 常见形态：首行"词性 + 多个义项"，取第一个义项
        ("vt. 放弃, 抛弃, 遗弃, 使屈从, 沉溺, 放纵\nn. 放任, 无拘束, 狂热", "放弃"),
        ("n. 苹果, 家伙\n[医] 苹果", "苹果"),
        ("a. 不明确的, 模棱两可的\n[法] 意思含糊的, 模棱两可的", "不明确的"),
        ("n. 圆, 圆形物, 巡回, 循环, 一轮, 一回合, 一局, 范围, 轮唱\na. 圆的", "圆"),
        ("n. 滑, 滑行, 事故, 溜, 差错, 滑台", "滑"),
        ("n. 跑, 赛跑, 奔跑, 连续\nrun的过去式和过去分词", "跑"),

        // 四字符词性前缀（ECDICT 用 prep. 这类写法）
        ("prep. 围着, 附近, 绕过, 在...周围", "围着"),
        ("adv. 围绕着, 在周围, 迂回地", "围绕着"),

        // 用分号分隔义项
        ("n. 甲；乙；丙", "甲"),

        // 句末标点收敛
        ("n. 苹果。", "苹果"),

        // 无词性前缀的特例：退回第一行，不剥离
        ("第一个字母 A; 一个; 第一的\nart. [计] 累加器, 加法器, 地址", "第一个字母 A"),
        ("be的单数第一人称\n[计] 存取管理程序, 寻址方式, 地址标记", "be的单数第一人称"),

        // 只有领域标注的条目：没有合格行时保留原文
        ("[计] 设置; DOS内部命令", "[计] 设置"),

        // 超长截断（12 字符 + 省略号）
        ("n. 一个非常非常非常长的释义内容", "一个非常非常非常长的释义…"),

        // 空输入
        ("", ""),
        ("   \n   ", "")
    ])
    func shortGlossMatchesExpectedSamples(input: String, expected: String) {
        #expect(LexiconGlossFormatter.shortGloss(from: input) == expected)
    }

    /// `a.` 必须被识别为形容词前缀。漏掉它会把大量形容词误判成"没有词性"，
    /// 这正是勘察阶段 Python 正则曾经犯过的错误。
    @Test func singleLetterAdjectivePrefixIsStripped() {
        #expect(LexiconGlossFormatter.shortGloss(from: "a. 能干的, 能够的") == "能干的")
        #expect(LexiconGlossFormatter.shortGloss(from: "ad. 副词用法, 其他") == "副词用法")
    }

    /// 句中普通句点不能被误判为词性前缀。
    @Test func overEagerPrefixStrippingIsAvoided() {
        let gloss = LexiconGlossFormatter.shortGloss(
            from: "这是一个句子. 后面还有内容"
        )

        #expect(gloss.hasPrefix("这是一个句子"))
    }

    @Test func maximumLengthIsRespected() {
        #expect(
            LexiconGlossFormatter.shortGloss(from: "n. 苹果, 家伙", maximumLength: 1) == "苹…"
        )
        #expect(
            LexiconGlossFormatter.shortGloss(from: "n. 苹果, 家伙", maximumLength: 20) == "苹果"
        )
    }

    /// 真实数据里最长的词条也必须产出一个可放进按钮的短释义。
    @Test func longestRealEntryStaysShort() {
        let round = "n. 圆, 圆形物, 巡回, 循环, 一轮, 一回合, 一局, 范围, 轮唱\n"
            + "a. 圆的, 球形的, 丰满的, 肥胖的, 完全的, 大概的, 完美的, 圆润的\n"
            + "prep. 围着, 附近, 绕过, 在...周围\n"
            + "adv. 围绕着, 在周围, 迂回地, 挨个, 朝反方向\n"
            + "vt. 弄圆, 使成圆形, 绕行, 完成, 围捕, 把...四舍五入\n"
            + "vi. 变圆, 发胖, 环行, 拐弯, 进展"

        let gloss = LexiconGlossFormatter.shortGloss(from: round)

        #expect(gloss == "圆")
        #expect(gloss.count <= LexiconGlossFormatter.defaultMaximumLength + 1)
    }

    // MARK: - 浏览列表的显示释义

    @Test(arguments: [
        // 保留词性前缀，按完整义项累加，超长补省略号
        (
            "vt. 放弃, 抛弃, 遗弃, 使屈从, 沉溺, 放纵\nn. 放任, 无拘束, 狂热",
            "vt. 放弃, 抛弃…",
            true
        ),
        ("n. 苹果, 家伙\n[医] 苹果", "n. 苹果, 家伙…", true),
        ("a. 不明确的, 模棱两可的\n[法] 意思含糊的", "a. 不明确的…", true),
        (
            "n. 圆, 圆形物, 巡回, 循环, 一轮, 一回合\na. 圆的, 球形的",
            "n. 圆, 圆形物…",
            true
        ),
        // 一行就说完，没有更多内容时不加省略号
        ("n. 苹果, 家伙", "n. 苹果, 家伙", false),
        // 无词性前缀时保留原文标点；截断点落在分隔符上时去掉尾随标点再补省略号
        ("第一个字母 A; 一个; 第一的", "第一个字母 A; 一个…", true),
        // 空输入
        ("", "", false)
    ])
    func browsingDisplayKeepsPartOfSpeechAndCountsTruncation(
        input: String,
        expectedText: String,
        expectedTruncated: Bool
    ) {
        let display = LexiconGlossFormatter.browsingDisplay(from: input)

        #expect(display.text == expectedText)
        #expect(display.isTruncated == expectedTruncated)
    }

    /// 省略号是"可以悬停看更多"的唯一提示，不能漏。
    @Test func truncatedBrowsingDisplayAlwaysEndsWithEllipsis() {
        let samples = [
            "vt. 放弃, 抛弃, 遗弃, 使屈从, 沉溺, 放纵\nn. 放任",
            "n. 苹果, 家伙\n[医] 苹果",
            "第一个字母 A; 一个; 第一的; 第二的; 第三的; 第四的; 第五的"
        ]

        for sample in samples {
            let display = LexiconGlossFormatter.browsingDisplay(from: sample)
            if display.isTruncated {
                #expect(display.text.hasSuffix("…"), "缺少省略号：\(sample)")
            }
        }
    }

    @Test func browsingDisplayRespectsMaximumLength() {
        let long = "vt. 放弃, 抛弃, 遗弃, 使屈从, 沉溺, 放纵, 放任, 无拘束, 狂热"

        let display = LexiconGlossFormatter.browsingDisplay(from: long, maximumLength: 8)

        // 至少保留第一个义项，并带上省略号。
        #expect(display.text.count <= 9)
        #expect(display.text.hasSuffix("…"))
        #expect(display.isTruncated)
    }

    // MARK: - 与单词刷选项的一致性（全库校验）

    /// 单词刷按 `WordQuizEngine.displayText` 判断"两个选项看起来是否一样"，界面直接渲染
    /// 释义字段。两者必须对全部 7,116 条词条给出同一段文字，否则引擎检测到的冲突
    /// 与用户看到的文本会各说各话，冲突检测就白做了。
    @Test @MainActor
    func browsingDisplayMatchesTheQuizDisplayTextForEveryEntry() throws {
        let repository = try LexiconTestSupport.makeRepository()
        let entries = try allEntries(in: repository)

        var mismatches: [String] = []
        for entry in entries {
            let browsing = LexiconGlossFormatter.browsingDisplay(from: entry.gloss).text
            if WordQuizEngine.displayText(of: browsing) != browsing {
                mismatches.append("\(entry.term): \(browsing)")
            }
        }

        #expect(entries.count == 7_116)
        // 顺带锁定分页不重不漏，否则下面的基线统计会虚高。
        #expect(Set(entries.map(\.id)).count == 7_116)
        #expect(mismatches.isEmpty, "这些词条的显示文本会被引擎二次改写：\(mismatches.prefix(5))")
    }

    /// 显示文本冲突是真实存在的，冲突规模与"被长度上限切掉多少"直接相关，因此这里一并固定。
    ///
    /// 注意区分三个不同口径，它们相差近十倍，混淆会得出错误结论：
    /// - 显示文本触到 12 字上限（长度 = 13，即 12 字 + 省略号）→ **684 条**，本用例统计的就是它；
    /// - 单行释义被上限切掉（排除多行造成的省略号）→ 111 条；
    /// - `isTruncated` 标志为真（含义是"还有更多内容可看"，多行释义也算）→ 6,271 条。
    @Test @MainActor
    func browsingDisplayCollisionScaleStaysWithinTheRecordedBaseline() throws {
        let repository = try LexiconTestSupport.makeRepository()
        let entries = try allEntries(in: repository)

        var termsByText: [String: [String]] = [:]
        var cappedCount = 0
        for entry in entries {
            let display = LexiconGlossFormatter.browsingDisplay(from: entry.gloss)
            // 达到上限时文本是"12 字 + 省略号"，长度恰好比上限多 1。
            if display.text.count == LexiconGlossFormatter.defaultBrowsingLength + 1 {
                cappedCount += 1
            }
            guard !display.text.isEmpty else { continue }
            termsByText[display.text, default: []].append(entry.term)
        }
        let collidingGroups = termsByText.filter { $0.value.count > 1 }

        // 基线（2026-09-13）：93 组、189 条词；被长度上限截断 684 条。
        #expect(cappedCount == 684)
        #expect(collidingGroups.count == 93)
        #expect(collidingGroups.values.reduce(0) { $0 + $1.count } == 189)

        // 至少要有真实存在的对照组，否则这条测试会在规则退化时失去意义。
        #expect(collidingGroups["n. 飞机…"]?.sorted() == ["aeroplane", "airplane"])
    }

    /// 逐页取完整个词库。分页是仓储唯一的读取入口，因此这里顺带验证翻页不重不漏。
    @MainActor
    private func allEntries(in repository: SQLiteLexiconRepository) throws -> [LexiconEntry] {
        var collected: [LexiconEntry] = []
        var pageIndex = 0
        while true {
            let page = try repository.page(
                matching: LexiconQuery(pageIndex: pageIndex)
            )
            guard !page.entries.isEmpty else { break }
            collected.append(contentsOf: page.entries)
            guard page.hasNextPage else { break }
            pageIndex += 1
        }
        return collected
    }
}

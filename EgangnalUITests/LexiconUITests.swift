//
//  LexiconUITests.swift
//  EgangnalUITests
//

import AppKit
import XCTest

/// 词库页面的界面验收。
///
/// 直接针对随包发布的真实词库运行（7,116 条），因此断言里的数字与
/// `tools/lexicon-builder/output/build-report.json` 的基线一致。
final class LexiconUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testBrowsesLexiconWithBaselineCountsAndLevelFilter() throws {
        let app = makeApplication(
            additionalArguments: ["--ui-testing-workspace-lexicon"]
        )
        app.launch()
        app.activate()

        XCTAssertTrue(
            app.staticTexts["lexicon.title"].waitForExistence(timeout: 5),
            "进入学习资料应显示词库页面"
        )
        XCTAssertEqual(app.staticTexts["lexicon.title"].label, "英语集词阁")

        let resultCount = app.staticTexts["lexicon.resultCount"]
        XCTAssertTrue(resultCount.waitForExistence(timeout: 5))
        XCTAssertTrue(
            text(of: resultCount).contains("7,116"),
            "默认应显示全部 7,116 条，实际为 \(text(of: resultCount))"
        )

        // 每页 50 条，7116 ÷ 50 向上取整为 143 页。
        let status = app.staticTexts["lexicon.pagination.status"]
        XCTAssertTrue(status.waitForExistence(timeout: 5))
        XCTAssertTrue(
            text(of: status).contains("143"),
            "分页状态应显示 143 页，实际为 \(text(of: status))"
        )
        XCTAssertTrue(
            text(of: status).contains("1–50"),
            "第一页应显示 1–50 条，实际为 \(text(of: status))"
        )

        XCTAssertTrue(firstEntry(in: app).waitForExistence(timeout: 5), "应渲染词块")

        // 切换到四级：3,849 条。
        click(app.buttons["lexicon.filter.cet4"], in: app)
        XCTAssertTrue(
            waitForLabel(resultCount, containing: "3,849", timeout: 5),
            "四级应显示 3,849 条，实际为 \(text(of: resultCount))"
        )

        // 回到全部。
        click(app.buttons["lexicon.filter.all"], in: app)
        XCTAssertTrue(
            waitForLabel(resultCount, containing: "7,116", timeout: 5),
            "回到全部应恢复 7,116 条"
        )
    }

    @MainActor
    func testSearchMatchesEnglishPrefixAndChineseMeaning() throws {
        let app = makeApplication(
            additionalArguments: ["--ui-testing-workspace-lexicon"]
        )
        app.launch()
        app.activate()

        let resultCount = app.staticTexts["lexicon.resultCount"]
        XCTAssertTrue(resultCount.waitForExistence(timeout: 5))

        // 英文前缀：aban → abandon。
        let search = app.descendants(matching: .any)["lexicon.search"]
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        enter("aban", into: search, in: app)
        XCTAssertTrue(
            word("abandon", in: app).waitForExistence(timeout: 5),
            "英文前缀搜索应命中 abandon"
        )

        // 中文释义：放弃 → 同样命中 abandon。
        clearSearch(in: app, search: search)
        enter("放弃", into: search, in: app)
        XCTAssertTrue(
            word("abandon", in: app).waitForExistence(timeout: 5),
            "中文释义检索应命中 abandon"
        )

        // 无结果时给出空状态，而不是空白页。
        clearSearch(in: app, search: search)
        enter("zzzzzzzz", into: search, in: app)
        XCTAssertTrue(
            app.descendants(matching: .any)["lexicon.empty"].waitForExistence(timeout: 5),
            "无结果时应显示空状态"
        )
    }

    @MainActor
    func testMaskingAndPaginationStayConsistent() throws {
        let app = makeApplication(
            additionalArguments: ["--ui-testing-workspace-lexicon"]
        )
        app.launch()
        app.activate()

        let firstWord = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier ENDSWITH %@", ".word"))
            .firstMatch
        XCTAssertTrue(firstWord.waitForExistence(timeout: 5), "应渲染词块中的单词字段")

        // 点击单词应切换为遮盖状态，且不改变布局。
        click(firstWord, in: app)
        XCTAssertEqual(firstWord.label, "单词已隐藏", "再次点击前单词应保持隐藏")
        click(firstWord, in: app)
        XCTAssertNotEqual(firstWord.label, "单词已隐藏", "再次点击应恢复显示")

        // 遮盖后右下角出现清除按钮。
        click(firstWord, in: app)
        let reset = app.buttons["lexicon.mask.reset"]
        XCTAssertTrue(reset.waitForExistence(timeout: 3), "存在遮盖时应显示清除按钮")
        click(reset, in: app)
        XCTAssertTrue(
            reset.waitForNonExistence(timeout: 3),
            "清除后按钮应消失，说明遮盖状态已清空"
        )

        // 翻页后页码与区间正确。
        let status = app.staticTexts["lexicon.pagination.status"]
        XCTAssertTrue(status.waitForExistence(timeout: 5))
        click(app.buttons["lexicon.pagination.next"], in: app)
        XCTAssertTrue(
            waitForLabel(status, containing: "2 / 143", timeout: 5),
            "翻页后应显示第 2 页，实际为 \(text(of: status))"
        )
        XCTAssertTrue(text(of: status).contains("51–100"), "第二页应显示 51–100 条")

        click(app.buttons["lexicon.pagination.previous"], in: app)
        XCTAssertTrue(
            waitForLabel(status, containing: "1 / 143", timeout: 5),
            "返回后应回到第 1 页"
        )
    }

    @MainActor
    func testCollectButtonAppearsOnHoverAndMarksWordAsCollected() throws {
        let app = makeApplication(
            additionalArguments: ["--ui-testing-workspace-lexicon"]
        )
        app.launch()
        app.activate()

        // 先搜到一个具体词，避免依赖默认排序。
        let search = app.descendants(matching: .any)["lexicon.search"]
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        enter("abandon", into: search, in: app)

        let word = word("abandon", in: app)
        XCTAssertTrue(word.waitForExistence(timeout: 5), "应命中 abandon")

        let collect = app.buttons
            .matching(NSPredicate(format: "identifier ENDSWITH %@", ".collect"))
            .firstMatch
        // 未悬停时按钮不显示（也不进入辅助功能树），这正是需要验证的“悬停才显形”。
        XCTAssertFalse(collect.exists, "未悬停时不应显示收录按钮")

        word.hover()
        XCTAssertTrue(
            collect.waitForExistence(timeout: 3),
            "悬停后应显示收录按钮"
        )
        XCTAssertEqual(collect.label, "加入单词本")

        click(collect, in: app)

        XCTAssertTrue(
            waitForLabel(collect, containing: "取消收藏", timeout: 5),
            "收录后按钮应变为可取消收藏的状态，实际为 \(collect.label)"
        )

        // 提示条给出明确反馈。
        let notice = app.staticTexts["lexicon.notice"]
        XCTAssertTrue(notice.waitForExistence(timeout: 3), "收录后应显示反馈提示")
        XCTAssertTrue(
            text(of: notice).contains("加入单词本"),
            "提示应说明已加入单词本，实际为 \(text(of: notice))"
        )

        // 再点一次取消收藏：按钮回到「加入单词本」。
        click(collect, in: app)
        XCTAssertTrue(
            waitForLabel(collect, containing: "加入单词本", timeout: 5),
            "取消收藏后按钮应回到可收藏状态，实际为 \(collect.label)"
        )
    }

    @MainActor
    func testReshuffleButtonChangesTheVisibleWords() throws {
        let app = makeApplication(
            additionalArguments: ["--ui-testing-workspace-lexicon"]
        )
        app.launch()
        app.activate()

        let words = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier ENDSWITH %@", ".word"))
        XCTAssertTrue(
            app.staticTexts["lexicon.title"].waitForExistence(timeout: 5)
        )
        XCTAssertTrue(firstEntry(in: app).waitForExistence(timeout: 5))

        let before = words.allElementsBoundByIndex.map(\.label)
        XCTAssertFalse(before.isEmpty, "第一页应渲染出单词")

        click(app.buttons["lexicon.reshuffle"], in: app)

        // 洗牌是随机的，理论上存在极小概率抽到同一批；这里按“在合理时间内变为不同”判断。
        let deadline = Date().addingTimeInterval(5)
        var after = words.allElementsBoundByIndex.map(\.label)
        while after == before, Date() < deadline {
            _ = app.staticTexts["lexicon.title"].waitForExistence(timeout: 0.2)
            after = words.allElementsBoundByIndex.map(\.label)
        }

        XCTAssertNotEqual(before, after, "「换一批」后第一页内容应该变化")

        // 搜索时顺序由词频决定，换一批没有意义，按钮应隐藏。
        let search = app.descendants(matching: .any)["lexicon.search"]
        enter("abandon", into: search, in: app)
        XCTAssertTrue(
            app.buttons["lexicon.reshuffle"].waitForNonExistence(timeout: 3),
            "搜索状态下不应显示换一批"
        )
    }

    // MARK: - 辅助

    @MainActor
    private func makeApplication(
        additionalArguments: [String] = []
    ) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments.append("--ui-testing")
        app.launchArguments.append(contentsOf: additionalArguments)
        return app
    }

    /// 单词字段的可访问标签就是词形本身，用它定位比猜测元素类型更稳。
    @MainActor
    private func word(_ term: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any)
            .matching(
                NSPredicate(
                    format: "identifier ENDSWITH %@ AND label == %@",
                    ".word",
                    term
                )
            )
            .firstMatch
    }

    @MainActor
    private func firstEntry(in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH %@", "lexicon.entry."))
            .firstMatch
    }

    @MainActor
    private func click(_ element: XCUIElement, in app: XCUIApplication) {
        app.activate()
        XCTAssertTrue(element.waitForExistence(timeout: 5))
        element.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).click()
    }

    /// 用剪贴板粘贴输入：`typeText` 在 macOS 上会插入多余空格，导致关键词不可控。
    @MainActor
    private func enter(_ text: String, into element: XCUIElement, in app: XCUIApplication) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        click(element, in: app)
        element.typeKey("v", modifierFlags: .command)
    }

    @MainActor
    private func clearSearch(in app: XCUIApplication, search: XCUIElement) {
        click(search, in: app)
        search.typeKey("a", modifierFlags: .command)
        search.typeKey(.delete, modifierFlags: [])
    }

    /// SwiftUI 的 StaticText 常把内容放在 `value`，`label` 为空，因此两者都读。
    @MainActor
    private func text(of element: XCUIElement) -> String {
        if let value = element.value as? String, !value.isEmpty {
            return value
        }
        return element.label
    }

    @MainActor
    private func waitForLabel(
        _ element: XCUIElement,
        containing text: String,
        timeout: TimeInterval
    ) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if self.text(of: element).contains(text) {
                return true
            }
            _ = element.waitForExistence(timeout: 0.2)
        }
        return self.text(of: element).contains(text)
    }
}

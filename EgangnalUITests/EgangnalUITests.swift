//
//  EgangnalUITests.swift
//  EgangnalUITests
//

import AppKit
import XCTest

final class EgangnalUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testNavigatesBetweenDashboardAndLanguageSpaces() throws {
        let app = makeApplication()
        app.launch()
        app.activate()

        XCTAssertTrue(
            app.staticTexts["dashboard.title"].waitForExistence(timeout: 3),
            "应用应从总览工作台启动"
        )

        let japaneseButton = app.buttons["dashboard.open.japanese"]
        XCTAssertTrue(japaneseButton.waitForExistence(timeout: 3))
        XCTAssertFalse(
            app.staticTexts["0.0 小时"].exists,
            "首页入口不应显示累计学习时长"
        )
        click(japaneseButton, in: app)

        XCTAssertTrue(
            app.staticTexts["wordBook.japanese.title"].waitForExistence(timeout: 3),
            "点击日语入口后应直接进入该语言上次使用的功能"
        )
        XCTAssertTrue(
            app.descendants(matching: .any)["workspace.navigation"]
                .waitForExistence(timeout: 2),
            "从首页进入语言空间后顶部功能栏应短暂自动显示"
        )
        XCTAssertTrue(
            app.descendants(matching: .any)["workspace.navigation"]
                .waitForNonExistence(timeout: 4),
            "入口提示结束后顶部功能栏应自动收回"
        )
        revealWorkspaceNavigation(in: app)
        let studyTime = app.descendants(matching: .any)["workspace.navigation.studyTime"]
        XCTAssertTrue(studyTime.waitForExistence(timeout: 3), "累计学习时长应保留在悬浮栏中")

        click(app.buttons["wordBook.back"], in: app)
        click(app.buttons["dashboard.open.english"], in: app)
        XCTAssertTrue(
            app.staticTexts["wordBook.english.title"].waitForExistence(timeout: 3),
            "点击英语入口后应直接进入英语上次使用的功能"
        )

        click(app.buttons["wordBook.back"], in: app)
        click(app.buttons["dashboard.open.japanese"], in: app)
        XCTAssertTrue(
            app.staticTexts["wordBook.japanese.title"].waitForExistence(timeout: 3),
            "再次进入日语时应恢复日语上次功能"
        )

        let backButton = app.buttons["wordBook.back"]
        XCTAssertTrue(backButton.waitForExistence(timeout: 3))
        click(backButton, in: app)

        let englishButton = app.buttons["dashboard.open.english"]
        XCTAssertTrue(englishButton.waitForExistence(timeout: 3))
        click(englishButton, in: app)

        XCTAssertTrue(app.staticTexts["wordBook.english.title"].exists)
    }

    @MainActor
    func testLanguageLauncherRestoresLastWorkspaceFeature() throws {
        let app = makeApplication(
            additionalArguments: ["--ui-testing-workspace-word-book"]
        )
        app.launch()
        app.activate()

        XCTAssertTrue(
            app.staticTexts["wordBook.english.title"].waitForExistence(timeout: 3)
        )
        click(app.buttons["wordBook.back"], in: app)
        click(app.buttons["dashboard.open.english"], in: app)
        XCTAssertTrue(
            app.staticTexts["wordBook.english.title"].waitForExistence(timeout: 3),
            "英语入口应恢复测试预置的单词本功能"
        )

        revealWorkspaceNavigation(in: app)
        click(app.buttons["workspace.navigation.feature.documents"], in: app)
        XCTAssertTrue(
            app.descendants(matching: .any)["workspace.documents.placeholder"]
                .waitForExistence(timeout: 3)
        )
        click(app.buttons["workspace.documents.back"], in: app)
        click(app.buttons["dashboard.open.english"], in: app)
        XCTAssertTrue(
            app.descendants(matching: .any)["workspace.documents.placeholder"]
                .waitForExistence(timeout: 3),
            "返回首页后再次进入英语应恢复上次使用的学习资料功能"
        )
    }

    @MainActor
    func testOpensWordQuizFromDashboardWorkspaceEntry() throws {
        let app = makeApplication(
            additionalArguments: ["--ui-testing-compact-window"]
        )
        app.launch()
        app.activate()

        for space in ["english", "japanese"] {
            let launcher = app.buttons["dashboard.open.\(space)"]
            XCTAssertTrue(launcher.waitForExistence(timeout: 3))
            click(launcher, in: app)

            // 模拟用户阅读页面后再移动到顶部栏，防止入口提示被提前收回。
            RunLoop.current.run(until: Date().addingTimeInterval(1.2))
            let wordQuiz = app.buttons["workspace.navigation.feature.wordQuiz"]
            XCTAssertTrue(
                wordQuiz.exists,
                "从首页进入 1.2 秒后，顶部栏仍应保持显示并可打开单词刷"
            )
            XCTAssertTrue(
                wordQuiz.isHittable,
                "单词刷按钮可见但无法点击，按钮位置：\(wordQuiz.frame)"
            )
            wordQuiz.hover()
            RunLoop.current.run(until: Date().addingTimeInterval(0.2))
            click(wordQuiz, in: app)
            XCTAssertTrue(
                app.staticTexts["wordQuiz.\(space).title"]
                    .waitForExistence(timeout: 3),
                "点击顶部栏单词刷后必须进入对应语言的功能页面"
            )
            XCTAssertTrue(
                app.radioGroups["wordQuiz.range"].waitForExistence(timeout: 3),
                "单词刷设置区域必须完成加载"
            )
            click(app.buttons["wordQuiz.back"], in: app)
            XCTAssertTrue(
                app.staticTexts["dashboard.title"].waitForExistence(timeout: 3)
            )
        }
    }

    @MainActor
    func testWorkspaceFeatureShortcutsUseNavigationCoordinator() throws {
        let app = makeApplication(
            additionalArguments: [
                "--ui-testing-word-quiz-fixtures",
                "--ui-testing-workspace-word-quiz"
            ]
        )
        app.launch()
        app.activate()

        app.typeKey("1", modifierFlags: .command)
        XCTAssertTrue(app.staticTexts["wordBook.english.title"].waitForExistence(timeout: 3))

        app.typeKey("2", modifierFlags: .command)
        XCTAssertTrue(app.staticTexts["wordQuiz.english.title"].waitForExistence(timeout: 3))
    }

    @MainActor
    func testPrimaryContentUsesSharedLeadingEdge() throws {
        let app = makeApplication(
            additionalArguments: ["--ui-testing-compact-window"]
        )
        app.launch()
        app.activate()

        let brandSubtitle = app.staticTexts["dashboard.brand.subtitle"]
        let firstLauncher = app.buttons["dashboard.open.japanese"]
        let launcherGroup = app.descendants(matching: .any)["dashboard.languageLauncher"]
        let englishLauncher = app.buttons["dashboard.open.english"]
        XCTAssertTrue(brandSubtitle.waitForExistence(timeout: 3))
        XCTAssertTrue(firstLauncher.exists)
        XCTAssertTrue(launcherGroup.exists)
        XCTAssertTrue(englishLauncher.exists)
        // macOS 可能把容器的布局槽扩展到按钮语义 frame，视觉边缘由截图和卡片自身布局保证。
        XCTAssertLessThanOrEqual(
            abs(brandSubtitle.frame.minX - launcherGroup.frame.minX),
            48,
            "品牌与语言入口应处于同一左侧内容列"
        )
        keepScreenshot(of: app, named: "Dashboard Aligned Without Decorative Icons")

        click(englishLauncher, in: app)
        let workspaceBack = app.buttons["wordBook.back"]
        let workspaceTitle = app.staticTexts["wordBook.english.title"]
        XCTAssertTrue(workspaceBack.waitForExistence(timeout: 3))
        XCTAssertTrue(workspaceTitle.exists)
        keepScreenshot(of: app, named: "Workspace Aligned Without Decorative Icons")

        let wordBookTitle = workspaceTitle
        let allWordsTitle = app.staticTexts["全部单词"]
        XCTAssertTrue(wordBookTitle.waitForExistence(timeout: 3))
        XCTAssertTrue(allWordsTitle.exists)
        let wordBookBack = app.buttons["wordBook.back"]
        XCTAssertTrue(wordBookBack.exists)
        XCTAssertEqual(
            wordBookBack.frame.minX,
            allWordsTitle.frame.minX,
            accuracy: 2,
            "单词本返回箭头应与正文共享左侧基线"
        )
        keepScreenshot(of: app, named: "Word Book Aligned Header")

        revealWorkspaceNavigation(in: app)
        XCTAssertTrue(app.buttons["workspace.navigation.feature.wordBook"].exists)
        click(wordBookBack, in: app)
        XCTAssertTrue(app.staticTexts["dashboard.title"].waitForExistence(timeout: 3))
    }

    @MainActor
    func testOpensWordBookAndEnablesEditingOnlyInDateMode() throws {
        let app = makeApplication()
        app.launch()
        app.activate()

        let japaneseButton = app.buttons["dashboard.open.japanese"]
        XCTAssertTrue(japaneseButton.waitForExistence(timeout: 3))
        click(japaneseButton, in: app)

        XCTAssertTrue(
            app.staticTexts["wordBook.japanese.title"].waitForExistence(timeout: 3)
        )
        XCTAssertTrue(
            app.buttons["wordBook.back"].exists,
            "统一工作区仍应保留功能页原有的左上返回箭头"
        )
        let guideButton = app.buttons["wordBook.guide.toggle"]
        XCTAssertTrue(guideButton.exists)
        click(guideButton, in: app)
        XCTAssertTrue(
            app.descendants(matching: .any)["wordBook.guide.content"]
                .waitForExistence(timeout: 3),
            "点击标题旁问号后应显示两行使用引导"
        )
        click(guideButton, in: app)
        XCTAssertTrue(app.buttons["wordBook.toolbar.toggle"].exists)
        XCTAssertEqual(
            app.buttons["wordBook.toolbar.toggle"].value as? String,
            "已收起"
        )
        XCTAssertFalse(app.buttons["wordBook.import"].exists)
        XCTAssertFalse(app.buttons["wordBook.export"].exists)

        click(app.buttons["wordBook.toolbar.toggle"], in: app)
        XCTAssertTrue(app.buttons["wordBook.import"].exists)
        XCTAssertTrue(app.buttons["wordBook.export"].exists)
        XCTAssertFalse(
            app.buttons["wordBook.edit.toggle"].exists,
            "默认分页模式必须保持只读"
        )

        // macOS 会把 SwiftUI 分段选择器暴露为 RadioGroup，而不是 SegmentedControl。
        let modePicker = app.radioGroups["wordBook.mode"]
        XCTAssertTrue(modePicker.waitForExistence(timeout: 3))
        let dateMode = modePicker.radioButtons["按日期"]
        XCTAssertTrue(dateMode.exists)
        click(dateMode, in: app)

        XCTAssertTrue(app.buttons["wordBook.edit.toggle"].waitForExistence(timeout: 3))
        click(app.buttons["wordBook.edit.toggle"], in: app)
        XCTAssertTrue(app.buttons["wordBook.add"].waitForExistence(timeout: 3))

        // 编辑能力不仅要出现，还要真正完成新增和修改，并保持在未归档日期页。
        click(app.buttons["wordBook.add"], in: app)
        let termField = app.descendants(matching: .any)["wordBook.editor.term"]
        let meaningField = app.descendants(matching: .any)["wordBook.editor.meaning"]
        XCTAssertTrue(termField.waitForExistence(timeout: 3))
        XCTAssertTrue(meaningField.exists)
        click(termField, in: app)
        pasteText("ui-added-word", into: termField)
        click(meaningField, in: app)
        pasteText("自动化新增", into: meaningField)
        click(app.buttons["wordBook.editor.save"], in: app)
        XCTAssertTrue(app.buttons["ui-added-word"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["自动化新增"].exists)

        let editAddedWord = app.buttons["编辑 ui-added-word"]
        XCTAssertTrue(editAddedWord.waitForExistence(timeout: 3))
        click(editAddedWord, in: app)
        XCTAssertTrue(meaningField.waitForExistence(timeout: 3))
        click(meaningField, in: app)
        meaningField.typeKey("a", modifierFlags: .command)
        pasteText("自动化更新", into: meaningField)
        click(app.buttons["wordBook.editor.save"], in: app)
        XCTAssertTrue(app.buttons["自动化更新"].waitForExistence(timeout: 3))

        click(app.buttons["wordBook.toolbar.toggle"], in: app)
        XCTAssertFalse(app.buttons["wordBook.add"].exists)
        click(app.buttons["wordBook.toolbar.toggle"], in: app)
        XCTAssertTrue(app.buttons["wordBook.edit.toggle"].waitForExistence(timeout: 3))
        XCTAssertFalse(
            app.buttons["wordBook.add"].exists,
            "收起功能栏后必须退出编辑模式"
        )

        let maskToggle = app.buttons["wordBook.mask.toggle"]
        XCTAssertTrue(maskToggle.exists)
        XCTAssertEqual(maskToggle.value as? String, "全部显示")
        click(maskToggle, in: app)
        XCTAssertEqual(maskToggle.value as? String, "单词已隐藏")
        click(maskToggle, in: app)
        XCTAssertEqual(maskToggle.value as? String, "释义已隐藏")

        click(app.buttons["wordBook.mask.reset"], in: app)
        XCTAssertEqual(maskToggle.value as? String, "全部显示")
    }

    @MainActor
    func testWordBookGuideAndMaskInteractions() throws {
        let app = makeApplication(
            additionalArguments: [
                "--ui-testing-word-book-fixtures",
                "--ui-testing-compact-window",
                "--ui-testing-light-theme"
            ]
        )
        app.launch()
        app.activate()

        let compactWindow = app.windows.firstMatch
        XCTAssertTrue(compactWindow.waitForExistence(timeout: 3))
        waitForFrameSize(
            CGSize(width: 820, height: 560),
            of: compactWindow,
            timeout: 3
        )
        XCTAssertEqual(compactWindow.frame.width, 820, accuracy: 4)
        XCTAssertEqual(compactWindow.frame.height, 560, accuracy: 4)

        click(app.buttons["dashboard.open.english"], in: app)

        let guideButton = app.buttons["wordBook.guide.toggle"]
        XCTAssertTrue(guideButton.waitForExistence(timeout: 3))
        XCTAssertEqual(guideButton.value as? String, "已收起")
        click(guideButton, in: app)
        XCTAssertEqual(guideButton.value as? String, "已展开")
        let guideContent = app.descendants(matching: .any)["wordBook.guide.content"]
        XCTAssertTrue(guideContent.waitForExistence(timeout: 3))
        XCTAssertGreaterThanOrEqual(
            guideContent.frame.minX,
            guideButton.frame.maxX - 2,
            "引导气泡应从问号按钮右侧展开"
        )
        let guideAttachment = XCTAttachment(screenshot: app.screenshot())
        guideAttachment.name = "Word Book Guide"
        guideAttachment.lifetime = .keepAlways
        add(guideAttachment)
        click(guideButton, in: app)
        XCTAssertEqual(guideButton.value as? String, "已收起")
        XCTAssertFalse(
            app.descendants(matching: .any)["wordBook.guide.content"].exists
        )

        let apple = app.buttons["apple"]
        let appleMeaning = app.buttons["苹果"]
        let banana = app.buttons["banana"]
        let bananaMeaning = app.buttons["香蕉"]
        XCTAssertTrue(apple.waitForExistence(timeout: 3))
        XCTAssertTrue(appleMeaning.exists)
        XCTAssertTrue(banana.exists)
        XCTAssertTrue(bananaMeaning.exists)

        XCTAssertEqual(apple.frame.minY, banana.frame.minY, accuracy: 2)
        XCTAssertLessThan(apple.frame.minX, appleMeaning.frame.minX)
        XCTAssertLessThan(appleMeaning.frame.minX, banana.frame.minX)
        XCTAssertLessThan(banana.frame.minX, bananaMeaning.frame.minX)
        let visibleFrames = [
            apple.frame,
            appleMeaning.frame,
            banana.frame,
            bananaMeaning.frame
        ]

        let longWord = app.buttons[
            "pneumonoultramicroscopicsilicovolcanoconiosis"
        ]
        let longMeaning = app.buttons["由超长词条触发的自动换行验证文本"]
        XCTAssertTrue(longWord.exists)
        XCTAssertTrue(longMeaning.exists)
        XCTAssertLessThanOrEqual(longWord.frame.maxX, longMeaning.frame.minX)
        XCTAssertGreaterThan(longWord.frame.height, apple.frame.height)

        click(apple, in: app)
        let hiddenWord = app.buttons["单词已隐藏"].firstMatch
        XCTAssertTrue(hiddenWord.waitForExistence(timeout: 3))
        assertFrames(
            [
                hiddenWord.frame,
                app.buttons["苹果"].frame,
                app.buttons["banana"].frame,
                app.buttons["香蕉"].frame
            ],
            equal: visibleFrames
        )
        click(hiddenWord, in: app)
        XCTAssertTrue(app.buttons["apple"].waitForExistence(timeout: 3))

        click(appleMeaning, in: app)
        let hiddenMeaning = app.buttons["释义已隐藏"].firstMatch
        XCTAssertTrue(hiddenMeaning.waitForExistence(timeout: 3))
        click(hiddenMeaning, in: app)
        XCTAssertTrue(app.buttons["苹果"].waitForExistence(timeout: 3))

        let maskToggle = app.buttons["wordBook.mask.toggle"]
        click(maskToggle, in: app)
        XCTAssertEqual(maskToggle.value as? String, "单词已隐藏")
        XCTAssertEqual(
            app.buttons.matching(NSPredicate(format: "label == %@", "单词已隐藏")).count,
            5
        )
        let maskingAttachment = XCTAttachment(screenshot: app.screenshot())
        maskingAttachment.name = "Word Book Rounded Masks"
        maskingAttachment.lifetime = .keepAlways
        add(maskingAttachment)

        click(app.buttons["wordBook.mask.reset"], in: app)
        XCTAssertEqual(maskToggle.value as? String, "全部显示")
        XCTAssertTrue(app.buttons["apple"].exists)
    }

    @MainActor
    func testWordBookPaginatesTwentyEntriesAndResetsMasking() throws {
        let app = makeApplication(
            additionalArguments: [
                "--ui-testing-word-book-pagination-fixtures",
                "--ui-testing-compact-window",
                "--ui-testing-workspace-word-book"
            ]
        )
        app.launch()
        app.activate()

        let pageStatus = app.staticTexts["wordBook.page.status"]
        let nextPage = app.buttons["wordBook.page.next"]
        let previousPage = app.buttons["wordBook.page.previous"]
        XCTAssertTrue(pageStatus.waitForExistence(timeout: 3))
        waitForValue("第 1 / 2 页", of: pageStatus, timeout: 3)
        XCTAssertFalse(previousPage.isEnabled)
        XCTAssertTrue(nextPage.isEnabled)
        XCTAssertTrue(app.buttons["pagination-word-01"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.buttons["pagination-word-21"].exists)

        let maskToggle = app.buttons["wordBook.mask.toggle"]
        click(maskToggle, in: app)
        XCTAssertEqual(maskToggle.value as? String, "单词已隐藏")
        click(nextPage, in: app)

        waitForValue("第 2 / 2 页", of: pageStatus, timeout: 3)
        XCTAssertTrue(previousPage.isEnabled)
        XCTAssertFalse(nextPage.isEnabled)
        waitForValue("全部显示", of: maskToggle, timeout: 3)
        XCTAssertFalse(app.buttons["pagination-word-01"].exists)
        XCTAssertTrue(app.buttons["pagination-word-21"].waitForExistence(timeout: 3))

        click(previousPage, in: app)
        waitForValue("第 1 / 2 页", of: pageStatus, timeout: 3)
        XCTAssertTrue(app.buttons["pagination-word-01"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.buttons["pagination-word-21"].exists)
    }

    @MainActor
    func testOpensSettingsAndTogglesPersonalization() throws {
        let app = makeApplication()
        app.launch()
        app.activate()

        let settingsButton = app.buttons["dashboard.settings"]
        let appearanceButton = app.buttons["dashboard.appearanceToggle"]
        XCTAssertTrue(settingsButton.waitForExistence(timeout: 3))
        XCTAssertTrue(appearanceButton.exists)
        XCTAssertLessThan(settingsButton.frame.minX, appearanceButton.frame.minX)
        XCTAssertFalse(app.buttons["profile.editNickname"].exists)

        click(settingsButton, in: app)
        XCTAssertTrue(app.staticTexts["settings.title"].waitForExistence(timeout: 3))

        let artworkToggle = app.switches["settings.personalization.cardArtwork"]
        let gridToggle = app.switches["settings.personalization.gridBackground"]
        let soundPicker = app.radioGroups["settings.wordQuiz.soundEffect"]
        let soundPreview = app.buttons["settings.wordQuiz.soundPreview"]
        let updateButton = app.buttons["settings.appUpdate.check"]
        XCTAssertTrue(artworkToggle.exists)
        XCTAssertTrue(gridToggle.exists)
        XCTAssertTrue(soundPicker.exists)
        XCTAssertTrue(soundPreview.exists)
        XCTAssertTrue(updateButton.exists)
        XCTAssertFalse(updateButton.isEnabled)
        XCTAssertFalse(soundPreview.isEnabled)
        click(artworkToggle, in: app)
        click(gridToggle, in: app)
        click(soundPicker.radioButtons["音效 1"], in: app)
        XCTAssertTrue(soundPreview.isEnabled)
        click(soundPreview, in: app)

        click(app.buttons["settings.back"], in: app)
        XCTAssertTrue(app.staticTexts["dashboard.title"].waitForExistence(timeout: 3))
    }

    @MainActor
    func testWorkspaceShellOverlayKeepsContentStableAndOpensDocuments() throws {
        let app = makeApplication(
            additionalArguments: [
                "--ui-testing-word-book-fixtures",
                "--ui-testing-compact-window",
                "--ui-testing-workspace-word-book"
            ]
        )
        app.launch()
        app.activate()

        let wordBookTitle = app.staticTexts["wordBook.english.title"]
        let guideToggle = app.buttons["wordBook.guide.toggle"]
        let toolbarToggle = app.buttons["wordBook.toolbar.toggle"]
        let maskReset = app.buttons["wordBook.mask.reset"]
        let wordBookBack = app.buttons["wordBook.back"]
        XCTAssertTrue(wordBookTitle.waitForExistence(timeout: 3))
        XCTAssertTrue(guideToggle.exists)
        XCTAssertTrue(toolbarToggle.exists)
        XCTAssertTrue(maskReset.exists)
        XCTAssertTrue(wordBookBack.exists)
        XCTAssertFalse(
            app.descendants(matching: .any)["workspace.navigation"].exists,
            "顶部悬浮栏初始状态应保持隐藏"
        )

        let window = app.windows.firstMatch
        for verticalOffset in [0.05, 0.95] {
            window.coordinate(
                withNormalizedOffset: CGVector(dx: 0.08, dy: verticalOffset)
            ).hover()
            RunLoop.current.run(until: Date().addingTimeInterval(0.35))
            XCTAssertFalse(
                app.descendants(matching: .any)["workspace.navigation"].exists,
                "窗口左侧顶部区域不能触发居中的悬浮栏"
            )
        }

        waitForStableFrame(of: wordBookTitle, timeout: 2)
        let contentFramesBeforeNavigation = [
            wordBookBack.frame,
            wordBookTitle.frame,
            guideToggle.frame,
            maskReset.frame,
            toolbarToggle.frame
        ]

        revealWorkspaceNavigation(in: app)
        let navigation = app.descendants(matching: .any)["workspace.navigation"]
        let wordBookFeature = app.buttons["workspace.navigation.feature.wordBook"]
        let wordQuizFeature = app.buttons["workspace.navigation.feature.wordQuiz"]
        let documentsFeature = app.buttons["workspace.navigation.feature.documents"]
        XCTAssertTrue(navigation.exists)
        XCTAssertTrue(wordBookFeature.exists)
        XCTAssertTrue(wordQuizFeature.exists)
        XCTAssertTrue(documentsFeature.exists)
        let studyTime = app.descendants(matching: .any)[
            "workspace.navigation.studyTime"
        ]
        XCTAssertFalse(
            app.buttons["workspace.navigation.dashboard"].exists,
            "返回首页只能使用功能页左上箭头，悬浮栏不应重复提供入口"
        )
        XCTAssertTrue(studyTime.exists)
        waitForStableFrame(of: wordQuizFeature, timeout: 2)

        assertFrames(
            [
                wordBookBack.frame,
                wordBookTitle.frame,
                guideToggle.frame,
                maskReset.frame,
                toolbarToggle.frame
            ],
            equal: contentFramesBeforeNavigation
        )
        let featureBarFrame = [
            wordBookFeature.frame,
            wordQuizFeature.frame,
            documentsFeature.frame
        ].reduce(CGRect.null) { $0.union($1) }
        XCTAssertEqual(
            featureBarFrame.midX,
            app.windows.firstMatch.frame.midX,
            accuracy: 2,
            "功能选择栏必须相对整个窗口水平居中"
        )
        XCTAssertGreaterThanOrEqual(
            studyTime.frame.minX,
            featureBarFrame.maxX - 1,
            "学习时长应位于功能栏右侧，不与功能按钮重叠"
        )
        XCTAssertLessThanOrEqual(
            studyTime.frame.minX - featureBarFrame.maxX,
            24,
            "学习时长应贴近功能栏右侧"
        )
        keepScreenshot(of: app, named: "Workspace Navigation Compact Overlay")

        app.windows.firstMatch.coordinate(
            withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)
        ).hover()
        XCTAssertTrue(
            app.descendants(matching: .any)["workspace.navigation"]
                .waitForNonExistence(timeout: 2),
            "指针离开后顶部悬浮栏应按延迟规则隐藏"
        )
        assertFrames(
            [
                wordBookBack.frame,
                wordBookTitle.frame,
                guideToggle.frame,
                maskReset.frame,
                toolbarToggle.frame
            ],
            equal: contentFramesBeforeNavigation
        )

        revealWorkspaceNavigation(in: app)
        let documents = documentsFeature
        XCTAssertTrue(documents.waitForExistence(timeout: 3))
        click(documents, in: app)

        let placeholder = app.descendants(matching: .any)[
            "workspace.documents.placeholder"
        ]
        XCTAssertTrue(placeholder.waitForExistence(timeout: 3))
        XCTAssertEqual(placeholder.label, "注意，功能监修中")
        let documentsBack = app.buttons["workspace.documents.back"]
        XCTAssertTrue(documentsBack.exists)
        XCTAssertFalse(app.buttons["workspace.navigation.dashboard"].exists)
        click(documentsBack, in: app)
        XCTAssertTrue(app.staticTexts["dashboard.title"].waitForExistence(timeout: 3))
    }

    @MainActor
    func testWorkspaceNavigationConfirmsBeforeLeavingAnsweredQuiz() throws {
        let app = makeApplication(
            additionalArguments: [
                "--ui-testing-word-quiz-fixtures",
                "--ui-testing-workspace-word-quiz",
                "--ui-testing-compact-window"
            ]
        )
        app.launch()
        app.activate()

        XCTAssertTrue(
            app.staticTexts["wordQuiz.english.title"].waitForExistence(timeout: 3),
            "测试启动参数应直接进入统一英语单词刷工作区"
        )
        let rangePicker = app.radioGroups["wordQuiz.range"]
        XCTAssertTrue(rangePicker.waitForExistence(timeout: 3))
        click(rangePicker.radioButtons["日期"], in: app)
        let start = app.buttons["wordQuiz.start"]
        XCTAssertTrue(start.isEnabled)
        click(start, in: app)

        let term = app.staticTexts["wordQuiz.question.term"]
        XCTAssertTrue(term.waitForExistence(timeout: 3))
        let correctMeanings = [
            "language": "语言",
            "time": "时间",
            "book": "书"
        ]
        let correctMeaning = try XCTUnwrap(correctMeanings[term.label])
        let options = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "wordQuiz.choice.option.")
        )
        let wrongOption = (0..<options.count)
            .map { options.element(boundBy: $0) }
            .first { !$0.label.contains(correctMeaning) }
        click(try XCTUnwrap(wrongOption), in: app)
        XCTAssertTrue(app.staticTexts["wordQuiz.feedback"].exists)

        revealWorkspaceNavigation(in: app)
        let documents = app.buttons["workspace.navigation.feature.documents"]
        XCTAssertTrue(documents.exists)
        click(documents, in: app)

        let continueButton = app.sheets.firstMatch.buttons["继续答题"]
        XCTAssertTrue(
            continueButton.waitForExistence(timeout: 3),
            "已作答的单词刷通过顶部栏离开时必须先请求确认"
        )
        XCTAssertFalse(
            app.descendants(matching: .any)["workspace.documents.placeholder"].exists
        )
        click(continueButton, in: app)
        XCTAssertTrue(app.staticTexts["wordQuiz.question.term"].exists)
    }

    @MainActor
    func testWordQuizWorkspaceBackReturnsDashboardWhenIdle() throws {
        let app = makeApplication(
            additionalArguments: [
                "--ui-testing-word-quiz-fixtures",
                "--ui-testing-workspace-word-quiz",
                "--ui-testing-compact-window"
            ]
        )
        app.launch()
        app.activate()

        let title = app.staticTexts["wordQuiz.english.title"]
        XCTAssertTrue(title.waitForExistence(timeout: 3))
        let backButton = app.buttons["wordQuiz.back"]
        XCTAssertTrue(backButton.exists)
        XCTAssertFalse(app.descendants(matching: .any)["workspace.navigation"].exists)

        click(backButton, in: app)
        XCTAssertTrue(
            app.staticTexts["dashboard.title"].waitForExistence(timeout: 3),
            "空闲态单词刷的左上返回箭头应直接回到首页"
        )
    }

    @MainActor
    func testWordQuizCompactLayoutAndIncorrectRetryFlow() throws {
        let app = makeApplication(
            additionalArguments: [
                "--ui-testing-word-quiz-fixtures",
                "--ui-testing-compact-window",
                "--ui-testing-light-theme",
                "--ui-testing-workspace-word-quiz"
            ]
        )
        app.launch()
        app.activate()

        XCTAssertTrue(
            app.staticTexts["wordQuiz.english.title"].waitForExistence(timeout: 3)
        )
        let idleWatermark = app.descendants(matching: .any)["wordQuiz.idle.watermark"]
        XCTAssertTrue(idleWatermark.waitForExistence(timeout: 3))
        XCTAssertEqual(idleWatermark.label, "I know you‘re ready")
        let rangePicker = app.radioGroups["wordQuiz.range"]
        let difficultyPicker = app.radioGroups["wordQuiz.difficulty"]
        XCTAssertTrue(rangePicker.waitForExistence(timeout: 3))
        XCTAssertTrue(difficultyPicker.exists)
        assertWordQuizIdleVisibleContentIsCentered(in: app)
        keepScreenshot(of: app, named: "Word Quiz Compact Idle Centered")
        click(rangePicker.radioButtons["日期"], in: app)
        XCTAssertTrue(
            app.descendants(matching: .any)["wordQuiz.date"]
                .waitForExistence(timeout: 3)
        )

        let start = app.buttons["wordQuiz.start"]
        XCTAssertTrue(start.isEnabled)
        XCTAssertEqual(start.label, "Let's go")
        let settingsFramesBeforeStart = [
            rangePicker.frame,
            difficultyPicker.frame,
            start.frame
        ]
        click(start, in: app)
        XCTAssertFalse(idleWatermark.exists, "开始答题后应移除空闲水印")
        XCTAssertFalse(start.isEnabled, "答题期间设置和开始按钮应锁定")
        assertFrames(
            [rangePicker.frame, difficultyPicker.frame, start.frame],
            equal: settingsFramesBeforeStart
        )
        assertWordQuizVisibleContentIsCentered(in: app)
        keepScreenshot(of: app, named: "Word Quiz Compact Active Stable")

        let correctMeanings = [
            "language": "语言",
            "time": "时间",
            "book": "书"
        ]
        var answeredCount = 0
        while !app.descendants(matching: .any)["wordQuiz.result"].exists,
              answeredCount < 3 {
            let term = app.staticTexts["wordQuiz.question.term"]
            XCTAssertTrue(term.waitForExistence(timeout: 3))
            let correctMeaning = try XCTUnwrap(correctMeanings[term.label])
            let options = app.buttons.matching(
                NSPredicate(format: "identifier BEGINSWITH %@", "wordQuiz.choice.option.")
            )
            XCTAssertEqual(options.count, 4)
            let termLabel = term.label
            let termFrameBeforeAnswer = term.frame
            let optionFramesBeforeAnswer = (0..<options.count).map {
                options.element(boundBy: $0).frame
            }

            if answeredCount == 0 {
                // 首题固定答错，确保结算后的错题再战路径可验证。
                let wrongOption = (0..<options.count)
                    .map { options.element(boundBy: $0) }
                    .first { !$0.label.contains(correctMeaning) }
                click(try XCTUnwrap(wrongOption), in: app)

                let back = app.buttons["wordQuiz.back"]
                click(back, in: app)
                let continueButton = app.sheets.firstMatch.buttons["继续答题"]
                XCTAssertTrue(continueButton.waitForExistence(timeout: 3))
                click(continueButton, in: app)
                XCTAssertTrue(app.staticTexts["wordQuiz.feedback"].exists)
            } else {
                let correctOption = (0..<options.count)
                    .map { options.element(boundBy: $0) }
                    .first { $0.label.contains(correctMeaning) }
                click(try XCTUnwrap(correctOption), in: app)
            }

            if answeredCount == 0 {
                let rowPositions = Set(optionFramesBeforeAnswer.map { Int($0.minY.rounded()) })
                XCTAssertEqual(rowPositions.count, 2, "最小窗口应采用两行两列选项布局")
            }

            XCTAssertTrue(app.staticTexts["wordQuiz.feedback"].exists)
            XCTAssertEqual(term.frame, termFrameBeforeAnswer, "反馈出现后单词位置不能跳动")
            assertFrames(
                (0..<options.count).map { options.element(boundBy: $0).frame },
                equal: optionFramesBeforeAnswer
            )

            if answeredCount < 2 {
                waitForLabelToChange(
                    from: termLabel,
                    of: app.staticTexts["wordQuiz.question.term"],
                    timeout: answeredCount == 0 ? 5 : 3
                )
            } else {
                XCTAssertTrue(
                    app.descendants(matching: .any)["wordQuiz.result"]
                        .waitForExistence(timeout: 3)
                )
            }
            answeredCount += 1
        }

        XCTAssertTrue(
            app.descendants(matching: .any)["wordQuiz.result"]
                .waitForExistence(timeout: 3)
        )
        keepScreenshot(of: app, named: "Word Quiz Compact Result")

        click(app.buttons["wordQuiz.result.retry"], in: app)
        let retryTerm = app.staticTexts["wordQuiz.question.term"]
        XCTAssertTrue(retryTerm.waitForExistence(timeout: 3))
        let retryMeaning = try XCTUnwrap(correctMeanings[retryTerm.label])
        let retryOptions = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "wordQuiz.choice.option.")
        )
        let correctRetryOption = (0..<retryOptions.count)
            .map { retryOptions.element(boundBy: $0) }
            .first { $0.label.contains(retryMeaning) }
        click(try XCTUnwrap(correctRetryOption), in: app)
        XCTAssertTrue(app.staticTexts["wordQuiz.feedback"].waitForExistence(timeout: 1))
        XCTAssertTrue(
            app.descendants(matching: .any)["wordQuiz.result"]
                .waitForExistence(timeout: 3)
        )

        XCTAssertFalse(app.buttons["wordQuiz.result.retry"].exists)
        click(app.buttons["wordQuiz.result.return"], in: app)
        XCTAssertFalse(app.staticTexts["wordQuiz.question.term"].exists)
        XCTAssertTrue(app.buttons["wordQuiz.start"].isEnabled)
        XCTAssertTrue(idleWatermark.waitForExistence(timeout: 3))
        assertFrames(
            [rangePicker.frame, difficultyPicker.frame, start.frame],
            equal: settingsFramesBeforeStart
        )
        assertWordQuizIdleVisibleContentIsCentered(in: app)
    }

    @MainActor
    func testWordQuizDeepModeMovesFromChoicesToSpellingAndResult() throws {
        let app = makeApplication(
            additionalArguments: [
                "--ui-testing-word-quiz-fixtures",
                "--ui-testing-light-theme",
                "--ui-testing-workspace-word-quiz"
            ]
        )
        app.launch()
        app.activate()

        let idleWatermark = app.descendants(matching: .any)["wordQuiz.idle.watermark"]
        XCTAssertTrue(idleWatermark.waitForExistence(timeout: 3))
        assertWordQuizIdleVisibleContentIsCentered(in: app)

        let rangePicker = app.radioGroups["wordQuiz.range"]
        let difficultyPicker = app.radioGroups["wordQuiz.difficulty"]
        XCTAssertTrue(rangePicker.waitForExistence(timeout: 3))
        XCTAssertTrue(difficultyPicker.exists)
        click(rangePicker.radioButtons["日期"], in: app)
        click(difficultyPicker.radioButtons["深度"], in: app)
        let start = app.buttons["wordQuiz.start"]
        let settingsFramesBeforeStart = [
            rangePicker.frame,
            difficultyPicker.frame,
            start.frame
        ]
        click(start, in: app)
        assertFrames(
            [rangePicker.frame, difficultyPicker.frame, start.frame],
            equal: settingsFramesBeforeStart
        )
        assertWordQuizVisibleContentIsCentered(in: app)

        let correctMeanings = [
            "language": "语言",
            "time": "时间",
            "book": "书"
        ]
        for index in 0..<3 {
            let term = app.staticTexts["wordQuiz.question.term"]
            XCTAssertTrue(term.waitForExistence(timeout: 3))
            let termLabel = term.label
            let correctMeaning = try XCTUnwrap(correctMeanings[term.label])
            let options = app.buttons.matching(
                NSPredicate(format: "identifier BEGINSWITH %@", "wordQuiz.choice.option.")
            )
            let correctOption = (0..<options.count)
                .map { options.element(boundBy: $0) }
                .first { $0.label.contains(correctMeaning) }
            click(try XCTUnwrap(correctOption), in: app)
            if index == 0 {
                keepScreenshot(of: app, named: "Word Quiz Correct Ring In Progress")
            }
            XCTAssertTrue(app.staticTexts["wordQuiz.feedback"].waitForExistence(timeout: 1))
            if index < 2 {
                waitForLabelToChange(
                    from: termLabel,
                    of: app.staticTexts["wordQuiz.question.term"],
                    timeout: 3
                )
            } else {
                XCTAssertTrue(
                    app.textFields["wordQuiz.spelling.input"]
                        .waitForExistence(timeout: 3)
                )
            }
        }

        let correctSpellings = [
            "语言": "language",
            "时间": "time",
            "书": "book"
        ]
        for index in 0..<3 {
            let meaning = app.staticTexts["wordQuiz.question.meaning"]
            let input = app.textFields["wordQuiz.spelling.input"]
            XCTAssertTrue(meaning.waitForExistence(timeout: 3))
            XCTAssertTrue(input.exists)
            let meaningLabel = meaning.label
            let meaningFrameBeforeAnswer = meaning.frame
            let inputFrameBeforeAnswer = input.frame
            let correctSpelling = try XCTUnwrap(correctSpellings[meaning.label])
            click(input, in: app)
            if index == 0 {
                let splitIndex = correctSpelling.index(
                    correctSpelling.startIndex,
                    offsetBy: correctSpelling.count / 2
                )
                let prefix = String(correctSpelling[..<splitIndex])
                let suffix = String(correctSpelling[splitIndex...])
                input.typeText(prefix)
                XCTAssertTrue(
                    NSPredicate(format: "hasKeyboardFocus == true")
                        .evaluate(with: input),
                    "第一段输入后拼写框必须继续持有键盘焦点"
                )
                // 不重新点击，验证 SwiftUI 同步状态后原生输入焦点仍然保留。
                input.typeText(suffix)
            } else {
                input.typeText(correctSpelling)
            }
            XCTAssertTrue(
                NSPredicate(format: "hasKeyboardFocus == true")
                    .evaluate(with: input),
                "连续输入期间拼写框不能失去键盘焦点"
            )
            let submitButton = app.buttons["wordQuiz.spelling.submit"]
            click(submitButton, in: app)
            let feedback = app.descendants(matching: .any)["wordQuiz.feedback"]
            XCTAssertTrue(feedback.waitForExistence(timeout: 1))
            XCTAssertEqual(feedback.label, "回答正确")
            if index == 0 {
                XCTAssertEqual(
                    meaning.frame,
                    meaningFrameBeforeAnswer,
                    "反馈出现后词义位置不能跳动"
                )
                XCTAssertEqual(
                    input.frame,
                    inputFrameBeforeAnswer,
                    "反馈出现后拼写输入框位置不能跳动"
                )
                keepScreenshot(of: app, named: "Word Quiz Spelling Feedback")
            }
            if index < 2 {
                waitForLabelToChange(
                    from: meaningLabel,
                    of: app.staticTexts["wordQuiz.question.meaning"],
                    timeout: 3
                )
            }
        }

        let score = app.staticTexts["wordQuiz.result.score"]
        XCTAssertTrue(score.waitForExistence(timeout: 3))
        XCTAssertEqual(score.label, "回答正确：6 / 6")
        XCTAssertFalse(app.buttons["wordQuiz.result.retry"].exists)
    }

    @MainActor
    func testSettingsLayoutAtDefaultWindowSize() throws {
        let app = makeApplication(
            additionalArguments: ["--ui-testing-settings"]
        )
        app.launch()
        app.activate()

        assertSettingsLayout(
            in: app,
            expectedWindowSize: CGSize(width: 1080, height: 700),
            screenshotName: "Settings 1080x700"
        )
    }

    @MainActor
    func testSettingsLayoutAtCompactWindowSize() throws {
        let app = makeApplication(
            additionalArguments: [
                "--ui-testing-settings",
                "--ui-testing-compact-window",
                "--ui-testing-light-theme"
            ]
        )
        app.launch()
        app.activate()

        assertSettingsLayout(
            in: app,
            expectedWindowSize: CGSize(width: 820, height: 560),
            screenshotName: "Settings 820x560 Light"
        )
    }

    @MainActor
    func testTogglesCalendarAndChangesMonth() throws {
        let app = makeApplication()
        app.launch()
        app.activate()

        XCTAssertFalse(app.staticTexts["累计学习时长"].exists)
        XCTAssertFalse(app.staticTexts["基础语法"].exists)
        XCTAssertFalse(app.staticTexts["学习资料"].exists)

        let dateButton = app.buttons["dashboard.date.toggle"]
        XCTAssertTrue(dateButton.waitForExistence(timeout: 3))
        click(dateButton, in: app)

        let monthHeader = app.buttons["dashboard.calendar.header"]
        XCTAssertTrue(monthHeader.waitForExistence(timeout: 3))
        let initialTitle = monthHeader.label
        XCTAssertFalse(initialTitle.contains(","))

        let nextButton = app.buttons["dashboard.calendar.nextMonth"]
        let previousButton = app.buttons["dashboard.calendar.previousMonth"]
        let monthButton = nextButton.isEnabled ? nextButton : previousButton
        XCTAssertTrue(monthButton.isEnabled)
        click(monthButton, in: app)
        XCTAssertNotEqual(monthHeader.label, initialTitle)

        let collapseButton = app.buttons["dashboard.calendar.collapse"]
        XCTAssertTrue(collapseButton.waitForExistence(timeout: 3))
        click(collapseButton, in: app)
        XCTAssertTrue(dateButton.waitForExistence(timeout: 3))
    }

    @MainActor
    func testTogglesIndependentAppearance() throws {
        let app = makeApplication()
        app.launch()
        app.activate()

        let appearanceButton = app.buttons["dashboard.appearanceToggle"]
        XCTAssertTrue(appearanceButton.waitForExistence(timeout: 3))
        XCTAssertEqual(appearanceButton.value as? String, "深色主题")

        click(appearanceButton, in: app)
        XCTAssertEqual(appearanceButton.value as? String, "浅色主题")

        click(app.buttons["dashboard.open.japanese"], in: app)
        XCTAssertTrue(
            app.staticTexts["wordBook.japanese.title"].waitForExistence(timeout: 3),
            "主题切换后仍应正常进入语言功能"
        )
        click(app.buttons["wordBook.back"], in: app)
        XCTAssertEqual(
            app.buttons["dashboard.appearanceToggle"].value as? String,
            "浅色主题",
            "页面路由变化不应重置应用主题"
        )
    }

    @MainActor
    func testExpandsAndCollapsesBrandWordmark() throws {
        let app = makeApplication()
        app.launch()
        app.activate()

        let brandButton = app.buttons["dashboard.brand.toggle"]
        XCTAssertTrue(brandButton.waitForExistence(timeout: 3))
        XCTAssertEqual(brandButton.value as? String, "Egangnal")
        let stableFrames = [
            app.staticTexts["dashboard.title"].frame,
            app.buttons["dashboard.open.japanese"].frame,
            app.buttons["dashboard.settings"].frame,
            app.otherElements["dashboard.calendarPanel"].frame,
            app.buttons["dashboard.appearanceToggle"].frame
        ]

        click(brandButton, in: app)
        waitForValue("For Language Study", of: brandButton, timeout: 3)
        assertFrames(stableFrames, unchangedIn: app)
        let expandedAttachment = XCTAttachment(screenshot: app.screenshot())
        expandedAttachment.name = "Brand Expanded"
        expandedAttachment.lifetime = .keepAlways
        add(expandedAttachment)

        // 展开后按钮会移动到 Language 的实际位置，第二次点击应从新位置收起。
        click(brandButton, in: app)
        waitForValue("Egangnal", of: brandButton, timeout: 3)
        assertFrames(stableFrames, unchangedIn: app)
        XCTAssertTrue(app.buttons["dashboard.appearanceToggle"].isEnabled)
    }

    @MainActor
    func testLaunchPerformance() throws {
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            let app = makeApplication()
            app.launch()
            app.activate()
        }
    }

    @MainActor
    func testDashboardLayoutAtExpandedCalendar() throws {
        let app = makeApplication(
            additionalArguments: ["--ui-testing-compact-window"]
        )
        app.launch()
        app.activate()

        let window = app.windows.firstMatch
        XCTAssertTrue(window.waitForExistence(timeout: 3))
        waitForFrameSize(CGSize(width: 820, height: 560), of: window, timeout: 3)

        XCTAssertFalse(app.buttons["profile.editNickname"].exists)
        XCTAssertTrue(app.buttons["dashboard.open.japanese"].exists)
        XCTAssertTrue(app.buttons["dashboard.open.english"].exists)
        XCTAssertTrue(app.buttons["dashboard.date.toggle"].exists)
        XCTAssertTrue(app.buttons["dashboard.appearanceToggle"].exists)
        XCTAssertTrue(app.buttons["dashboard.settings"].exists)
        XCTAssertTrue(app.buttons["window.close"].exists)
        XCTAssertTrue(app.buttons["window.minimize"].exists)
        XCTAssertTrue(app.buttons["window.zoom"].exists)

        let japaneseCard = app.buttons["dashboard.open.japanese"]
        let englishCard = app.buttons["dashboard.open.english"]
        let brandButton = app.buttons["dashboard.brand.toggle"]
        let calendarPanel = app.otherElements["dashboard.calendarPanel"]
        XCTAssertTrue(brandButton.waitForExistence(timeout: 3))
        XCTAssertTrue(calendarPanel.waitForExistence(timeout: 3))
        XCTAssertEqual(
            brandButton.frame.minY,
            calendarPanel.frame.minY,
            accuracy: 2,
            "品牌名称顶部应与日历顶部对齐"
        )
        XCTAssertGreaterThan(
            calendarPanel.frame.minY - window.frame.minY,
            56,
            "品牌和日历需要保留舒适的顶部留白"
        )
        XCTAssertLessThan(calendarPanel.frame.minY, japaneseCard.frame.minY)
        XCTAssertLessThan(
            englishCard.frame.minX,
            japaneseCard.frame.minX,
            "首页语言入口应保持英语在左、日语在右"
        )
        XCTAssertLessThan(
            englishCard.frame.midX,
            calendarPanel.frame.minX,
            "英语入口与日历应分处左右两列"
        )
        XCTAssertLessThan(japaneseCard.frame.width / japaneseCard.frame.height, 2.1)
        XCTAssertLessThan(englishCard.frame.width / englishCard.frame.height, 2.1)

        let collapsedCardFrames = [japaneseCard.frame, englishCard.frame]

        click(app.buttons["dashboard.date.toggle"], in: app)
        XCTAssertTrue(
            app.buttons["dashboard.calendar.collapse"].waitForExistence(timeout: 3)
        )
        waitForStableFrame(of: calendarPanel, timeout: 1)
        assertFrames(
            [japaneseCard.frame, englishCard.frame],
            equal: collapsedCardFrames
        )
        XCTAssertLessThan(englishCard.frame.midX, calendarPanel.frame.minX)
        XCTAssertTrue(app.buttons["dashboard.calendar.collapse"].exists)
        XCTAssertFalse(
            app.buttons["dashboard.calendar.collapse"].frame.intersects(
                app.buttons["dashboard.appearanceToggle"].frame
            ),
            "展开挂历不能遮挡主题切换按钮"
        )

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Dashboard Expanded Calendar"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    private func makeApplication(
        additionalArguments: [String] = []
    ) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments.append("--ui-testing")
        app.launchArguments.append(contentsOf: additionalArguments)
        return app
    }

    @MainActor
    private func click(_ element: XCUIElement, in app: XCUIApplication) {
        app.activate()
        XCTAssertTrue(element.exists)
        element.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).click()
    }

    @MainActor
    private func revealWorkspaceNavigation(in app: XCUIApplication) {
        let window = app.windows.firstMatch
        XCTAssertTrue(window.exists)
        let featureButton = app.buttons["workspace.navigation.feature.wordBook"]
        // 不同 macOS/Xcode 版本可能采用相反的纵向坐标原点，依次探测中心顶部候选点。
        for verticalOffset in [0.05, 0.95] {
            window.coordinate(
                withNormalizedOffset: CGVector(dx: 0.5, dy: verticalOffset)
            ).hover()
            RunLoop.current.run(until: Date().addingTimeInterval(0.35))
            if featureButton.exists { return }
        }
    }

    @MainActor
    private func pasteText(_ text: String, into element: XCUIElement) {
        let pasteboard = NSPasteboard.general
        let savedItems: [NSPasteboardItem] = pasteboard.pasteboardItems?.map { sourceItem in
            let copiedItem = NSPasteboardItem()
            for type in sourceItem.types {
                if let data = sourceItem.data(forType: type) {
                    copiedItem.setData(data, forType: type)
                }
            }
            return copiedItem
        } ?? []

        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        element.typeKey("v", modifierFlags: .command)

        pasteboard.clearContents()
        pasteboard.writeObjects(savedItems)
    }

    @MainActor
    private func keepScreenshot(of app: XCUIApplication, named name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    private func waitForFrameSize(
        _ expectedSize: CGSize,
        of element: XCUIElement,
        timeout: TimeInterval
    ) {
        let deadline = Date().addingTimeInterval(timeout)

        // 窗口恢复和测试尺寸设置均为异步操作，先等待稳定再读取坐标。
        while Date() < deadline {
            let frame = element.frame
            if abs(frame.width - expectedSize.width) <= 4,
               abs(frame.height - expectedSize.height) <= 4 {
                return
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.05))
        }

        XCTFail(
            "窗口应在 \(timeout) 秒内调整为 "
                + "\(Int(expectedSize.width))×\(Int(expectedSize.height))"
        )
    }

    @MainActor
    private func waitForStableFrame(
        of element: XCUIElement,
        timeout: TimeInterval
    ) {
        let deadline = Date().addingTimeInterval(timeout)
        var previousFrame = CGRect.null
        var stableReadCount = 0

        while Date() < deadline {
            let frame = element.frame
            if framesAreEqual(frame, previousFrame, accuracy: 1) {
                stableReadCount += 1
                if stableReadCount >= 3 {
                    return
                }
            } else {
                previousFrame = frame
                stableReadCount = 0
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.05))
        }

        XCTFail("控件应在 \(timeout) 秒内完成布局动画")
    }

    private func framesAreEqual(
        _ lhs: CGRect,
        _ rhs: CGRect,
        accuracy: CGFloat
    ) -> Bool {
        abs(lhs.minX - rhs.minX) <= accuracy
            && abs(lhs.minY - rhs.minY) <= accuracy
            && abs(lhs.width - rhs.width) <= accuracy
            && abs(lhs.height - rhs.height) <= accuracy
    }

    @MainActor
    private func waitForValue(
        _ value: String,
        of element: XCUIElement,
        timeout: TimeInterval
    ) {
        let predicate = NSPredicate(format: "value == %@", value)
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        XCTAssertEqual(
            XCTWaiter.wait(for: [expectation], timeout: timeout),
            .completed,
            "控件应在限定时间内切换为 \(value)"
        )
    }

    @MainActor
    private func waitForLabel(
        _ label: String,
        of element: XCUIElement,
        timeout: TimeInterval
    ) {
        let predicate = NSPredicate(format: "label == %@", label)
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        XCTAssertEqual(
            XCTWaiter.wait(for: [expectation], timeout: timeout),
            .completed,
            "控件应在限定时间内显示 \(label)"
        )
    }

    @MainActor
    private func waitForLabelToChange(
        from previousLabel: String,
        of element: XCUIElement,
        timeout: TimeInterval
    ) {
        let predicate = NSPredicate(format: "exists == true AND label != %@", previousLabel)
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        XCTAssertEqual(
            XCTWaiter.wait(for: [expectation], timeout: timeout),
            .completed,
            "答题反馈结束后应自动进入下一题"
        )
    }

    @MainActor
    private func assertSettingsLayout(
        in app: XCUIApplication,
        expectedWindowSize: CGSize,
        screenshotName: String
    ) {
        let window = app.windows.firstMatch
        XCTAssertTrue(window.waitForExistence(timeout: 3))
        waitForFrameSize(expectedWindowSize, of: window, timeout: 3)

        let title = app.staticTexts["settings.title"]
        let path = app.staticTexts["settings.exportDirectory.path"]
        let chooseDirectory = app.buttons["settings.exportDirectory.choose"]
        let artworkToggle = app.switches["settings.personalization.cardArtwork"]
        let gridToggle = app.switches["settings.personalization.gridBackground"]
        let controls = [title, path, chooseDirectory, artworkToggle, gridToggle]

        XCTAssertTrue(title.waitForExistence(timeout: 3))
        for control in controls {
            XCTAssertTrue(control.exists)
            XCTAssertTrue(
                window.frame.contains(control.frame),
                "设置控件不能超出窗口可见范围"
            )
        }
        XCTAssertFalse(path.frame.intersects(chooseDirectory.frame))
        XCTAssertLessThan(artworkToggle.frame.minY, gridToggle.frame.minY)

        keepScreenshot(of: app, named: screenshotName)
    }

    @MainActor
    private func assertFrames(_ expected: [CGRect], unchangedIn app: XCUIApplication) {
        let actual = [
            app.staticTexts["dashboard.title"].frame,
            app.buttons["dashboard.open.japanese"].frame,
            app.buttons["dashboard.settings"].frame,
            app.otherElements["dashboard.calendarPanel"].frame,
            app.buttons["dashboard.appearanceToggle"].frame
        ]

        XCTAssertEqual(actual.count, expected.count)
        for (actualFrame, expectedFrame) in zip(actual, expected) {
            XCTAssertEqual(actualFrame.minX, expectedFrame.minX, accuracy: 1)
            XCTAssertEqual(actualFrame.minY, expectedFrame.minY, accuracy: 1)
            XCTAssertEqual(actualFrame.width, expectedFrame.width, accuracy: 1)
            XCTAssertEqual(actualFrame.height, expectedFrame.height, accuracy: 1)
        }
    }

    private func assertFrames(
        _ actual: [CGRect],
        equal expected: [CGRect],
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertEqual(actual.count, expected.count, file: file, line: line)
        for (actualFrame, expectedFrame) in zip(actual, expected) {
            XCTAssertEqual(actualFrame.minX, expectedFrame.minX, accuracy: 1, file: file, line: line)
            XCTAssertEqual(actualFrame.minY, expectedFrame.minY, accuracy: 1, file: file, line: line)
            XCTAssertEqual(actualFrame.width, expectedFrame.width, accuracy: 1, file: file, line: line)
            XCTAssertEqual(actualFrame.height, expectedFrame.height, accuracy: 1, file: file, line: line)
        }
    }

    @MainActor
    private func assertNoIntersections(
        between contentElements: [XCUIElement],
        and overlayElements: [XCUIElement],
        message: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        for contentElement in contentElements {
            for overlayElement in overlayElements {
                XCTAssertFalse(
                    contentElement.frame.intersects(overlayElement.frame),
                    "\(message)：\(contentElement.identifier) 与 \(overlayElement.identifier)",
                    file: file,
                    line: line
                )
            }
        }
    }

    @MainActor
    private func assertWorkspaceCardGrid(
        documents: XCUIElement,
        wordBook: XCUIElement,
        wordQuiz: XCUIElement,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertEqual(documents.frame.minY, wordBook.frame.minY, accuracy: 2, file: file, line: line)
        XCTAssertEqual(documents.frame.width, wordBook.frame.width, accuracy: 2, file: file, line: line)
        XCTAssertEqual(documents.frame.height, wordBook.frame.height, accuracy: 2, file: file, line: line)
        XCTAssertEqual(documents.frame.minX, wordQuiz.frame.minX, accuracy: 2, file: file, line: line)
        XCTAssertEqual(documents.frame.width, wordQuiz.frame.width, accuracy: 2, file: file, line: line)
        XCTAssertEqual(documents.frame.height, wordQuiz.frame.height, accuracy: 2, file: file, line: line)
        XCTAssertGreaterThan(wordBook.frame.minX, documents.frame.minX, file: file, line: line)
        XCTAssertGreaterThanOrEqual(
            wordQuiz.frame.minY,
            documents.frame.maxY + AppThemeTestValues.panelSpacing - 2,
            file: file,
            line: line
        )
    }

    @MainActor
    private func assertWordQuizVisibleContentIsCentered(
        in app: XCUIApplication,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let options = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "wordQuiz.choice.option.")
        )
        let visibleFrames = (0..<options.count).map {
            options.element(boundBy: $0).frame
        } + [
            app.radioGroups["wordQuiz.range"].frame,
            app.radioGroups["wordQuiz.difficulty"].frame,
            app.buttons["wordQuiz.start"].frame
        ]
        let minX = visibleFrames.map(\.minX).min() ?? 0
        let maxX = visibleFrames.map(\.maxX).max() ?? 0
        XCTAssertEqual(
            (minX + maxX) / 2,
            app.windows.firstMatch.frame.midX,
            accuracy: 4,
            file: file,
            line: line
        )
    }

    @MainActor
    private func assertWordQuizIdleVisibleContentIsCentered(
        in app: XCUIApplication,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let visibleFrames = [
            app.descendants(matching: .any)["wordQuiz.idle.watermark"].frame,
            app.radioGroups["wordQuiz.range"].frame,
            app.radioGroups["wordQuiz.difficulty"].frame,
            app.buttons["wordQuiz.start"].frame
        ]
        let minX = visibleFrames.map(\.minX).min() ?? 0
        let maxX = visibleFrames.map(\.maxX).max() ?? 0
        XCTAssertEqual(
            (minX + maxX) / 2,
            app.windows.firstMatch.frame.midX,
            accuracy: 4,
            file: file,
            line: line
        )
    }
}

private enum AppThemeTestValues {
    static let panelSpacing: CGFloat = 20
}

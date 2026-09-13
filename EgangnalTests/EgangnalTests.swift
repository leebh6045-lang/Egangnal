//
//  EgangnalTests.swift
//  EgangnalTests
//

import Testing
import AppKit
import Foundation
import SwiftData
import SwiftUI
import UniformTypeIdentifiers
@testable import Egangnal

struct EgangnalTests {
    @Test @MainActor func appBundleContainsSafeSparkleDefaults() {
        let bundle = Bundle.main
        let publicKey = bundle.object(forInfoDictionaryKey: "SUPublicEDKey") as? String
        let feedURL = bundle.object(forInfoDictionaryKey: "SUFeedURL") as? String
        let automaticChecks = bundle.object(
            forInfoDictionaryKey: "SUEnableAutomaticChecks"
        ) as? Bool
        let installerLauncherService = bundle.object(
            forInfoDictionaryKey: "SUEnableInstallerLauncherService"
        ) as? Bool

        #expect(publicKey == "BXWE8ZviCuYL73IeyYlrK+X1v3YGWK8MnlM/GTL+nOQ=")
        #expect(feedURL == "")
        #expect(automaticChecks == false)
        #expect(installerLauncherService == true)

        // 发布地址尚未填写时更新器必须保持禁用，不能向占位地址发起请求。
        let controller = AppUpdateController(bundle: bundle)
        #expect(!controller.isConfigured)
        #expect(!controller.canCheckForUpdates)
    }

    @Test func calendarMonthBuildsStableMondayFirstGrid() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        calendar.firstWeekday = 2

        let february = CalendarMonth(year: 2024, month: 2)
        let grid = february.dayGrid(using: calendar)

        #expect(february.numberOfDays(using: calendar) == 29)
        #expect(grid.count == 42)
        #expect(grid[0] == nil)
        #expect(grid[3] == 1)
        #expect(grid[31] == 29)
    }

    @Test func calendarMonthDoesNotCrossYearBoundary() {
        let january = CalendarMonth(year: 2026, month: 1)
        let december = CalendarMonth(year: 2026, month: 12)

        #expect(january.moving(by: -1) == nil)
        #expect(january.moving(by: 1) == CalendarMonth(year: 2026, month: 2))
        #expect(december.moving(by: 1) == nil)
        #expect(december.moving(by: -1) == CalendarMonth(year: 2026, month: 11))
    }

    @Test func calendarMonthCalculatesCommonMonthLengths() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!

        let samples = [
            (CalendarMonth(year: 2023, month: 2), 28),
            (CalendarMonth(year: 2024, month: 2), 29),
            (CalendarMonth(year: 2026, month: 4), 30),
            (CalendarMonth(year: 2026, month: 8), 31)
        ]

        for (month, expectedDays) in samples {
            #expect(month.numberOfDays(using: calendar) == expectedDays)
        }
    }

    @Test func studyDateKeyRejectsNonexistentCalendarDates() {
        #expect(StudyDateKey(rawValue: "2026-02-29") == nil)
        #expect(StudyDateKey(rawValue: "2024-02-29") != nil)
        #expect(StudyDateKey(rawValue: "2026-04-31") == nil)
    }

    @Test func dailyStudyFeedbackCombinesLanguageSpacesAtTheThreshold() {
        let dateKey = StudyDateKey(year: 2026, month: 8, day: 19)
        let japanese = DailyStudyActivitySnapshot(
            dateKey: dateKey,
            space: .japanese,
            studiedSeconds: 600,
            hasEntered: true
        )
        let english = DailyStudyActivitySnapshot(
            dateKey: dateKey,
            space: .english,
            studiedSeconds: 300,
            hasEntered: true
        )

        #expect(DailyStudyFeedbackStatus.make(from: []) == .none)
        #expect(DailyStudyFeedbackStatus.make(from: [japanese]) == .visited)
        #expect(
            DailyStudyFeedbackStatus.make(from: [japanese, english]) == .completed
        )
    }

    @Test func calendarActivityOnlyConnectsSameWeekAndSameStatus() {
        let statuses: [DailyStudyFeedbackStatus] = [
            .completed, .completed, .visited, .visited,
            .none, .none, .completed, .completed,
            .completed, .visited
        ]

        #expect(CalendarActivityLayout.connectsLeading(at: 1, statuses: statuses))
        #expect(!CalendarActivityLayout.connectsLeading(at: 2, statuses: statuses))
        #expect(CalendarActivityLayout.connectsTrailing(at: 2, statuses: statuses))
        #expect(!CalendarActivityLayout.connectsTrailing(at: 6, statuses: statuses))
        #expect(!CalendarActivityLayout.connectsLeading(at: 7, statuses: statuses))
        #expect(!CalendarActivityLayout.connectsTrailing(at: 8, statuses: statuses))
    }

    @Test func languageSpacesAreStableAndIndependent() {
        #expect(LanguageSpace.allCases == [.japanese, .english])
        #expect(LanguageSpace.japanese.title == "日语")
        #expect(LanguageSpace.english.title == "英语")
        #expect(LanguageSpace.japanese.companion == .english)
        #expect(LanguageSpace.english.companion == .japanese)
    }

    @Test func languageSpacesUseTheSameBlueAccent() {
        let lightPalette = AppAppearance.light.palette
        let darkPalette = AppAppearance.dark.palette

        #expect(lightPalette.japaneseAccent == lightPalette.englishAccent)
        #expect(darkPalette.japaneseAccent == darkPalette.englishAccent)
    }

    @Test func wordBookShuffleIsStableForOneSeedAndChangesWithAnother() {
        let entries = (1...40).map { makeShuffleEntry(index: $0) }

        let first = WordBookPaging.shuffled(entries, seed: 4_242)
        let repeated = WordBookPaging.shuffled(entries, seed: 4_242)
        let other = WordBookPaging.shuffled(entries, seed: 9_999)

        #expect(first.map(\.id) == repeated.map(\.id), "同一种子必须得到同一批顺序")
        #expect(first.map(\.id) != other.map(\.id), "换种子必须换一批顺序")
    }

    /// 洗牌只改顺序，不能丢词或重复。
    @Test func wordBookShuffleKeepsEveryEntryExactlyOnce() {
        let entries = (1...40).map { makeShuffleEntry(index: $0) }

        let shuffled = WordBookPaging.shuffled(entries, seed: 20_260_911)

        #expect(shuffled.count == entries.count)
        #expect(Set(shuffled.map(\.id)) == Set(entries.map(\.id)))
        // 分页之后仍然不重不漏。
        let firstPage = WordBookPaging.items(in: shuffled, page: 0)
        let secondPage = WordBookPaging.items(in: shuffled, page: 1)
        #expect(Set(firstPage.map(\.id)).isDisjoint(with: Set(secondPage.map(\.id))))
    }

    @Test func wordBookShuffleHandlesEmptyInput() {
        #expect(WordBookPaging.shuffled([], seed: 1).isEmpty)
        #expect(WordBookPaging.shuffled([makeShuffleEntry(index: 1)], seed: 1).count == 1)
    }

    @Test func workspaceFeaturesHaveStableNavigationOrderAndTitles() {
        #expect(WorkspaceFeature.allCases == [.wordBook, .lexicon, .wordQuiz])
        #expect(
            WorkspaceFeature.allCases.map(\.rawValue)
                == ["wordBook", "lexicon", "wordQuiz"]
        )
        #expect(WorkspaceFeature.wordBook.title == "单词本")
        #expect(WorkspaceFeature.wordQuiz.title == "单词刷")
        #expect(WorkspaceFeature.lexicon.title == "词库")
    }

    @Test @MainActor func workspaceNavigationDefaultsBothLanguagesToWordBook() {
        let store = WorkspaceNavigationStore(
            preferences: TestWorkspaceNavigationPreferences()
        )

        #expect(store.lastFeature(for: .japanese) == .wordBook)
        #expect(store.lastFeature(for: .english) == .wordBook)
    }

    @Test @MainActor func workspaceNavigationPersistsLanguagesIndependently() {
        let preferences = TestWorkspaceNavigationPreferences()
        let store = WorkspaceNavigationStore(preferences: preferences)

        store.setLastFeature(.wordQuiz, for: .japanese)
        store.setLastFeature(.lexicon, for: .english)

        let restored = WorkspaceNavigationStore(preferences: preferences)
        #expect(restored.lastFeature(for: .japanese) == .wordQuiz)
        #expect(restored.lastFeature(for: .english) == .lexicon)
        #expect(
            preferences.values[
                WorkspaceNavigationStore.StorageKey.lastFeature(for: .japanese)
            ] == WorkspaceFeature.wordQuiz.rawValue
        )
        #expect(
            preferences.values[
                WorkspaceNavigationStore.StorageKey.lastFeature(for: .english)
            ] == WorkspaceFeature.lexicon.rawValue
        )
    }

    @Test @MainActor func workspaceNavigationRejectsUnknownStoredFeature() {
        let preferences = TestWorkspaceNavigationPreferences(values: [
            WorkspaceNavigationStore.StorageKey.lastFeature(for: .japanese): "removed",
            WorkspaceNavigationStore.StorageKey.lastFeature(for: .english):
                WorkspaceFeature.wordQuiz.rawValue
        ])
        let store = WorkspaceNavigationStore(preferences: preferences)

        #expect(store.lastFeature(for: .japanese) == .wordBook)
        #expect(store.lastFeature(for: .english) == .wordQuiz)
    }

    @Test @MainActor func workspaceNavigationTracksInMemorySelectionWithoutPreferences() {
        let store = WorkspaceNavigationStore(preferences: nil)

        store.setLastFeature(.wordQuiz, for: .english)

        #expect(store.lastFeature(for: .english) == .wordQuiz)
        #expect(store.lastFeature(for: .japanese) == .wordBook)
    }

    @Test func wordQuizPageCopyMatchesLanguageSpace() {
        let english = WordQuizPageCopy.make(for: .english)
        #expect(english.idleWatermarkTopLine == "I know")
        #expect(english.idleWatermarkBottomLine == "you‘re ready")
        #expect(english.startButtonTitle == "Let's go")

        let japanese = WordQuizPageCopy.make(for: .japanese)
        #expect(japanese.idleWatermarkTopLine == "準備が")
        #expect(japanese.idleWatermarkBottomLine == "できましたか")
        #expect(japanese.startButtonTitle == "始めます")
    }

    @Test func wordQuizSuccessRingOnlyMarksASelectedCorrectOption() {
        let correctOptionID = UUID()
        let incorrectOptionID = UUID()
        let questionID = WordQuizQuestionID(
            candidateID: correctOptionID,
            kind: .meaningChoice
        )
        let correctResponse = WordQuizAnswerResult(
            questionID: questionID,
            answer: .choice(optionID: correctOptionID),
            isCorrect: true,
            correctAnswer: "正确词义"
        )
        let incorrectResponse = WordQuizAnswerResult(
            questionID: questionID,
            answer: .choice(optionID: incorrectOptionID),
            isCorrect: false,
            correctAnswer: "正确词义"
        )

        #expect(WordQuizChoiceFeedbackPolicy.showsSuccessRing(
            response: correctResponse,
            optionID: correctOptionID,
            correctOptionID: correctOptionID
        ))
        #expect(!WordQuizChoiceFeedbackPolicy.showsSuccessRing(
            response: correctResponse,
            optionID: incorrectOptionID,
            correctOptionID: correctOptionID
        ))
        #expect(!WordQuizChoiceFeedbackPolicy.showsSuccessRing(
            response: incorrectResponse,
            optionID: correctOptionID,
            correctOptionID: correctOptionID
        ))
    }

    @Test @MainActor func wordQuizSoundEffectsMapToBundledResources() throws {
        #expect(WordQuizSoundEffect.off.resource == nil)
        #expect(WordQuizSoundEffect.sound1.resource == WordQuizSoundResource(
            name: "WordQuizClick1",
            fileExtension: "wav"
        ))
        #expect(WordQuizSoundEffect.sound2.resource == WordQuizSoundResource(
            name: "WordQuizClick2",
            fileExtension: "mp3"
        ))

        for effect in [WordQuizSoundEffect.sound1, .sound2] {
            let resource = try #require(effect.resource)
            #expect(
                AVAudioWordQuizSoundPlayer.resourceURL(
                    for: resource,
                    in: .main
                ) != nil
            )
        }

        let player = AVAudioWordQuizSoundPlayer(bundle: .main)
        #expect(player.isAvailable(.sound1))
        #expect(player.isAvailable(.sound2))
    }

    @Test func wordQuizLayoutUsesStableWidthBasedAnswerCompensation() {
        let fourChoiceWidth = (AppTheme.wordQuizChoiceWidth * 4)
            + (AppTheme.wordQuizChoiceSpacing * 3)
        let wideAnswerWidth = fourChoiceWidth + 52
        #expect(
            WordQuizLayout.preferredAnswerContentWidth(for: wideAnswerWidth)
                == fourChoiceWidth
        )
        #expect(WordQuizLayout.answerContentOffset(for: wideAnswerWidth) == -26)

        let compactChoiceWidth = (AppTheme.wordQuizCompactChoiceWidth * 2)
            + AppTheme.wordQuizChoiceSpacing
        let compactAnswerWidth = compactChoiceWidth + 40
        #expect(
            WordQuizLayout.preferredAnswerContentWidth(for: compactAnswerWidth)
                == compactChoiceWidth
        )
        #expect(WordQuizLayout.answerContentOffset(for: compactAnswerWidth) == -20)
        #expect(WordQuizLayout.answerContentOffset(for: 200) == 0)
    }

    @Test func wordBookPagingHandlesPageBoundaries() {
        let samples = [
            (count: 0, pages: 0),
            (count: 1, pages: 1),
            (count: 20, pages: 1),
            (count: 21, pages: 2),
            (count: 40, pages: 2),
            (count: 41, pages: 3)
        ]

        for sample in samples {
            let entries = (0..<sample.count).map {
                makePresentationEntry(index: $0)
            }
            #expect(
                WordBookPaging.pageCount(itemCount: sample.count) == sample.pages
            )
            #expect(
                WordBookPaging.items(in: entries, page: 0).count
                    == min(sample.count, WordBookPaging.pageSize)
            )
            #expect(WordBookPaging.clampedPage(-1, itemCount: sample.count) == 0)
            #expect(
                WordBookPaging.clampedPage(999, itemCount: sample.count)
                    == max(sample.pages - 1, 0)
            )

            for page in 1..<max(sample.pages, 1) {
                let expectedCount = min(
                    WordBookPaging.pageSize,
                    sample.count - page * WordBookPaging.pageSize
                )
                #expect(WordBookPaging.items(in: entries, page: page).count == expectedCount)
            }
            let pagedEntries = (0..<sample.pages).flatMap {
                WordBookPaging.items(in: entries, page: $0)
            }
            #expect(pagedEntries == entries)
            #expect(WordBookPaging.items(in: entries, page: 999).isEmpty == (sample.count == 0))
        }
    }

    @Test func wordBookDatesAreUniqueAndSortedDescending() throws {
        let oldest = try #require(VocabularyDocumentDate(year: 2026, month: 8, day: 8))
        let middle = try #require(VocabularyDocumentDate(year: 2026, month: 8, day: 9))
        let newest = try #require(VocabularyDocumentDate(year: 2026, month: 8, day: 10))
        let entries = [
            makePresentationEntry(index: 0, dates: [oldest, newest, middle, newest]),
            makePresentationEntry(index: 1, dates: [middle]),
            makePresentationEntry(index: 2)
        ]

        #expect(WordBookPaging.dates(in: entries) == [newest, middle, oldest])
        // 手动新增词条没有日期，不应凭空生成日期分组。
        #expect(WordBookPaging.dates(in: [makePresentationEntry(index: 3)]).isEmpty)
    }

    @Test func wordBookFileTypeUsesMarkdownExtension() {
        #expect(WordBookFileType.markdown.preferredFilenameExtension == "md")
        #expect(WordBookFileType.markdown.conforms(to: .plainText))
    }

    @Test func wordBookMaskModeUsesExpectedCycle() {
        #expect(WordBookMaskMode.normal.next == .hideWords)
        #expect(WordBookMaskMode.hideWords.next == .hideMeanings)
        #expect(WordBookMaskMode.hideMeanings.next == .hideWords)
    }

    @Test func wordBookMaskStateSupportsIndividualAndGlobalReveal() {
        let firstID = UUID()
        let secondID = UUID()
        var state = WordBookMaskState()

        state.toggleWord(firstID)
        state.toggleMeaning(secondID)
        #expect(!state.isWordVisible(firstID))
        #expect(!state.isMeaningVisible(secondID))

        state.cycleMode()
        #expect(state.mode == .hideWords)
        #expect(!state.isWordVisible(firstID))
        #expect(!state.isWordVisible(secondID))
        #expect(state.isMeaningVisible(firstID))
        state.toggleWord(firstID)
        #expect(state.isWordVisible(firstID))

        state.cycleMode()
        #expect(state.mode == .hideMeanings)
        #expect(state.isWordVisible(firstID))
        #expect(!state.isMeaningVisible(firstID))
        state.toggleMeaning(firstID)
        #expect(state.isMeaningVisible(firstID))

        state.reset()
        #expect(state.mode == .normal)
        #expect(state.isWordVisible(firstID))
        #expect(state.isMeaningVisible(firstID))
    }

    @Test func routesExposeUniqueAccessibilityIdentifiers() {
        let routes: [AppRoute] = [
            .dashboard,
            .settings,
            .workspace(.japanese, .wordBook),
            .workspace(.japanese, .wordQuiz),
            .workspace(.japanese, .lexicon),
            .workspace(.english, .wordBook),
            .workspace(.english, .wordQuiz),
            .workspace(.english, .lexicon)
        ]

        #expect(Set(routes.map(\.accessibilityIdentifier)).count == routes.count)
        #expect(AppRoute.dashboard.learningSpace == nil)
        #expect(AppRoute.settings.learningSpace == nil)
        #expect(AppRoute.workspace(.english, .lexicon).learningSpace == .english)
        #expect(AppRoute.workspace(.japanese, .wordQuiz).isWordQuiz)
        #expect(!AppRoute.workspace(.japanese, .wordBook).isWordQuiz)
    }

    @Test func rootPageTransitionIdentityKeepsWorkspaceChromeStable() {
        #expect(AppRoute.dashboard.rootPageIdentity == .dashboard)
        #expect(AppRoute.settings.rootPageIdentity == .settings)
        #expect(
            AppRoute.workspace(.english, .wordBook).rootPageIdentity
                == AppRoute.workspace(.english, .wordQuiz).rootPageIdentity
        )
        #expect(
            AppRoute.workspace(.english, .lexicon).rootPageIdentity
                != AppRoute.workspace(.japanese, .lexicon).rootPageIdentity
        )
    }

    @Test @MainActor func workspaceExitCoordinatorRunsOrInterceptsNavigation() {
        let coordinator = WorkspaceExitCoordinator()
        var navigationCount = 0
        var interceptedAction: (() -> Void)?

        coordinator.perform {
            navigationCount += 1
        }
        #expect(navigationCount == 1)

        let interceptorID = coordinator.install { action in
            interceptedAction = action
        }
        coordinator.perform {
            navigationCount += 1
        }
        #expect(navigationCount == 1)

        interceptedAction?()
        #expect(navigationCount == 2)

        coordinator.remove(id: interceptorID)
        coordinator.perform {
            navigationCount += 1
        }
        #expect(navigationCount == 3)
    }

    @Test func brandWordmarkUsesStableReversibleGlyphMapping() {
        let glyphs = BrandWordmarkModel.glyphs

        #expect(BrandWordmarkModel.sourceWord == "Egangnal")
        #expect(BrandWordmarkModel.targetWord == "Language")
        #expect(glyphs.count == 8)
        #expect(Set(glyphs.map(\.id)).count == glyphs.count)
        #expect(Set(glyphs.map(\.targetIndex)) == Set(0..<glyphs.count))

        let shapeChanges = glyphs.filter(\.changesIntoU)
        #expect(shapeChanges.count == 1)
        #expect(shapeChanges.first?.sourceIndex == 3)
        #expect(shapeChanges.first?.source == "n")
        #expect(shapeChanges.first?.target == "u")
    }

    @Test func themeRippleRadiusReachesEveryCorner() {
        let size = CGSize(width: 1080, height: 700)
        let origin = CGPoint(x: 1034, y: 654)
        let radius = ThemeRippleGeometry.requiredRadius(in: size, from: origin)
        let corners = [
            CGPoint(x: 0, y: 0),
            CGPoint(x: size.width, y: 0),
            CGPoint(x: 0, y: size.height),
            CGPoint(x: size.width, y: size.height)
        ]

        for corner in corners {
            #expect(hypot(corner.x - origin.x, corner.y - origin.y) <= radius + 0.001)
        }
        #expect(abs(radius - hypot(origin.x, origin.y)) < 0.001)
    }

    @Test func themeRippleConvertsOriginIntoFullWindowCoordinates() {
        let origin = ThemeRippleGeometry.windowOrigin(
            contentOrigin: CGPoint(x: 1034, y: 626),
            contentSize: CGSize(width: 1080, height: 672),
            windowSize: CGSize(width: 1080, height: 700)
        )

        #expect(origin == CGPoint(x: 1034, y: 654))
    }

    @Test func themeRippleProgressIsClampedToRevealBounds() {
        let size = CGSize(width: 100, height: 100)
        let origin = CGPoint(x: 50, y: 50)
        let radius = ThemeRippleGeometry.requiredRadius(in: size, from: origin)

        #expect(ThemeRippleGeometry.clampedProgress(-0.4) == 0)
        #expect(ThemeRippleGeometry.clampedProgress(1.4) == 1)
        #expect(ThemeRippleGeometry.revealRadius(in: size, from: origin, progress: 0) == 0)
        #expect(ThemeRippleGeometry.revealRadius(in: size, from: origin, progress: 1) == radius)
    }

    @Test @MainActor func themeRippleRendersNewSoftEdgeAndOldRegions() throws {
        let size = CGSize(width: 200, height: 200)
        let snapshot = NSImage(size: size, flipped: false) { rect in
            NSColor.white.setFill()
            NSBezierPath(rect: rect).fill()
            return true
        }
        let content = ZStack {
            Color.black
            ThemeRippleOverlay(
                snapshot: snapshot,
                origin: CGPoint(x: 100, y: 100),
                progress: 0.35,
                size: size
            )
        }
        .frame(width: size.width, height: size.height)
        let renderer = ImageRenderer(content: content)
        renderer.scale = 1

        let renderedImage = try #require(renderer.nsImage)
        let imageData = try #require(renderedImage.tiffRepresentation)
        let representation = try #require(NSBitmapImageRep(data: imageData))
        let center = try #require(representation.colorAt(x: 100, y: 100))
        let softEdge = try #require(representation.colorAt(x: 20, y: 100))
        let outside = try #require(representation.colorAt(x: 0, y: 100))

        // 中间态必须同时保留新主题、渐变软边和旧主题区域。
        #expect(center.brightnessComponent < 0.1)
        #expect(softEdge.brightnessComponent > 0.15)
        #expect(softEdge.brightnessComponent < 0.85)
        #expect(outside.brightnessComponent > 0.9)
    }

    @Test @MainActor func appearanceUpdateKeepsWindowLayoutStable() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1080, height: 700),
            styleMask: [.titled, .resizable],
            backing: .buffered,
            defer: false
        )
        let configurationView = WindowConfigurationView(appearance: .light)
        window.contentView?.addSubview(configurationView)
        let initialLayoutRect = window.contentLayoutRect
        let initialContentBounds = window.contentView?.bounds

        configurationView.updateAppearance(.dark)

        #expect(window.appearance?.name == .aqua)
        #expect(window.contentLayoutRect == initialLayoutRect)
        #expect(window.contentView?.bounds == initialContentBounds)
        #expect(window.styleMask.contains(.fullSizeContentView))
    }

    @Test @MainActor func appearanceStoreRestoresAndPersistsSelection() {
        let preferences = TestAppearancePreferences(
            values: [AppearanceStore.storageKey: AppAppearance.light.rawValue]
        )
        let store = AppearanceStore(preferences: preferences)

        #expect(store.mode == .light)

        store.toggle()

        #expect(store.mode == .dark)
        #expect(preferences.values[AppearanceStore.storageKey] == AppAppearance.dark.rawValue)
        #expect(AppearanceStore(preferences: preferences).mode == .dark)
    }

    @Test @MainActor func appearanceStoreUsesDeterministicFallback() {
        let preferences = TestAppearancePreferences(
            values: [AppearanceStore.storageKey: "system"]
        )

        #expect(AppearanceStore(preferences: preferences).mode == .dark)
        #expect(AppearanceStore(preferences: nil, defaultMode: .light).mode == .light)
    }

    @Test @MainActor func appSettingsUseEnabledDefaultsAndPersistChanges() {
        let preferences = TestAppSettingsPreferences()
        let service = TestExportDirectoryService()
        let store = AppSettingsStore(
            preferences: preferences,
            exportDirectoryService: service
        )

        #expect(store.showsLanguageCardArtwork)
        #expect(store.showsGridBackground)
        #expect(store.wordQuizSoundEffect == .off)
        #expect(!store.hasExportDirectory)

        store.setLanguageCardArtwork(false)
        store.setGridBackground(false)
        store.setWordQuizSoundEffect(.sound2)

        let restored = AppSettingsStore(
            preferences: preferences,
            exportDirectoryService: service
        )
        #expect(!restored.showsLanguageCardArtwork)
        #expect(!restored.showsGridBackground)
        #expect(restored.wordQuizSoundEffect == .sound2)
        #expect(restored.personalization == AppPersonalization(
            showsLanguageCardArtwork: false,
            showsGridBackground: false
        ))
    }

    @Test @MainActor func appSettingsRejectUnknownWordQuizSoundEffect() {
        let preferences = TestAppSettingsPreferences()
        preferences.set(
            "removed-sound",
            forKey: AppSettingsStore.StorageKey.wordQuizSoundEffect
        )

        let store = AppSettingsStore(
            preferences: preferences,
            exportDirectoryService: TestExportDirectoryService()
        )

        #expect(store.wordQuizSoundEffect == .off)
    }

    @Test @MainActor func appSettingsExportUsesBookmarkAndFallsBackWhenUnavailable() throws {
        let preferences = TestAppSettingsPreferences()
        let service = TestExportDirectoryService()
        let store = AppSettingsStore(
            preferences: preferences,
            exportDirectoryService: service
        )
        try store.selectExportDirectory(
            URL(fileURLWithPath: "/tmp/egangnal-export", isDirectory: true)
        )

        #expect(store.hasExportDirectory)
        #expect(store.exportDirectoryPath == "/tmp/egangnal-export")

        service.exportResult = .unavailable
        #expect(try store.exportToPreferredDirectory(
            data: Data("template".utf8),
            preferredFilename: "template.md"
        ) == nil)

        let exportedURL = URL(
            fileURLWithPath: "/tmp/egangnal-export-renamed/template.md"
        )
        service.exportResult = .exported(
            url: exportedURL,
            refreshedBookmarkData: Data([9, 9, 9])
        )
        #expect(try store.exportToPreferredDirectory(
            data: Data("template".utf8),
            preferredFilename: "template.md"
        ) == exportedURL)
        #expect(
            preferences.data(forKey: AppSettingsStore.StorageKey.exportDirectoryBookmark)
                == Data([9, 9, 9])
        )
        #expect(store.exportDirectoryPath == "/tmp/egangnal-export-renamed")
        #expect(
            preferences.string(forKey: AppSettingsStore.StorageKey.exportDirectoryPath)
                == "/tmp/egangnal-export-renamed"
        )

        let previousExportCount = service.exportCallCount
        store.clearExportDirectory()
        #expect(!store.hasExportDirectory)
        #expect(try store.exportToPreferredDirectory(
            data: Data(),
            preferredFilename: "template.md"
        ) == nil)
        #expect(service.exportCallCount == previousExportCount)
    }

    @Test @MainActor func appSettingsIgnoreIncompleteExportDirectoryState() throws {
        let preferences = TestAppSettingsPreferences()
        preferences.set(
            Data([1, 2, 3]),
            forKey: AppSettingsStore.StorageKey.exportDirectoryBookmark
        )
        let service = TestExportDirectoryService()
        let store = AppSettingsStore(
            preferences: preferences,
            exportDirectoryService: service
        )

        #expect(!store.hasExportDirectory)
        #expect(store.exportDirectoryPath == nil)
        #expect(try store.exportToPreferredDirectory(
            data: Data(),
            preferredFilename: "template.md"
        ) == nil)
        #expect(service.exportCallCount == 0)
    }

    @Test @MainActor func exportDirectoryCreatesNonOverwritingFilename() throws {
        let fileManager = FileManager.default
        let directory = fileManager.temporaryDirectory.appendingPathComponent(
            "EgangnalExportTests-\(UUID().uuidString)",
            isDirectory: true
        )
        try fileManager.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        defer { try? fileManager.removeItem(at: directory) }

        let existingURL = directory.appendingPathComponent("template.md")
        try Data().write(to: existingURL)

        let destination = try SecurityScopedExportDirectoryService.availableDestination(
            in: directory,
            preferredFilename: "template.md",
            fileManager: fileManager
        )
        #expect(destination.lastPathComponent == "template-2.md")
    }

    @Test func exportDirectoryDisplayPathHasStableTrailingSlashRule() {
        #expect(ExportDirectoryPath.displayPath(
            for: URL(fileURLWithPath: "/tmp/egangnal-export/", isDirectory: true)
        ) == "/tmp/egangnal-export")
        #expect(ExportDirectoryPath.displayPath(
            for: URL(fileURLWithPath: "/", isDirectory: true)
        ) == "/")
    }

    @Test @MainActor func profileStoreNormalizesAndSavesNickname() {
        let repository = TestProfileRepository()
        let store = ProfileStore(repository: repository)

        #expect(store.saveNickname("  小林  "))
        #expect(store.nickname == "小林")
        #expect(repository.savedNickname == "小林")
        #expect(store.message == nil)
    }

    @Test @MainActor func profileStoreRejectsInvalidNickname() {
        let repository = TestProfileRepository()
        let store = ProfileStore(repository: repository)

        #expect(!store.saveNickname("   "))
        #expect(store.nickname == ProfileStore.defaultNickname)
        #expect(repository.savedNickname == nil)
        #expect(store.message == "昵称不能为空。")
    }

    @Test @MainActor func profileStoreKeepsPreviousValueWhenSaveFails() {
        let repository = TestProfileRepository(
            storedNickname: "原昵称",
            shouldFailSaving: true
        )
        let store = ProfileStore(repository: repository)

        #expect(!store.saveNickname("新昵称"))
        #expect(store.nickname == "原昵称")
        #expect(store.message == "昵称保存失败，请稍后再试。")
    }

    @Test @MainActor func swiftDataRepositoryUsesOnlyPrimaryProfile() throws {
        let schema = Schema([UserProfile.self])
        let configuration = ModelConfiguration(
            "ProfileRepositoryTests",
            schema: schema,
            isStoredInMemoryOnly: true
        )
        let container = try ModelContainer(
            for: schema,
            configurations: [configuration]
        )
        let setupContext = ModelContext(container)
        setupContext.insert(
            UserProfile(identifier: "secondary", nickname: "其他资料")
        )
        try setupContext.save()

        let repository = SwiftDataProfileRepository(modelContainer: container)
        #expect(try repository.loadNickname() == nil)

        try repository.saveNickname("小林")

        let reloadedRepository = SwiftDataProfileRepository(modelContainer: container)
        #expect(try reloadedRepository.loadNickname() == "小林")
    }

    @Test func wordBookTemplateUsesExactMarkdownProtocol() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let date = try #require(
            calendar.date(from: DateComponents(year: 2026, month: 8, day: 10))
        )
        let expectedEntries = Array(
            repeating: "｜｜      ",
            count: 20
        ).joined(separator: "\n")
        let expected = "2026年08月10日\n\n\n(请在双竖线左侧直接填写单词，右侧填写中文意思；每行填写一条，完成后保存并导入单词本。)\n\n\n\(expectedEntries)\n"

        #expect(WordBookTemplateGenerator.makeTemplate(for: date, calendar: calendar) == expected)
        #expect(WordBookTemplateGenerator.makeTemplateData(for: date, calendar: calendar) == Data(expected.utf8))
        let separatorParts = WordBookTemplateGenerator.entrySeparator.components(separatedBy: "｜｜")
        #expect(separatorParts.count == 2)
        #expect(separatorParts[0].isEmpty)
        #expect(separatorParts[1].count == 6)

        var buddhistCalendar = Calendar(identifier: .buddhist)
        buddhistCalendar.timeZone = calendar.timeZone
        #expect(
            WordBookTemplateGenerator.makeTemplate(for: date, calendar: buddhistCalendar)
                == expected
        )
    }

    @Test func wordBookParserSkipsTemplateInstructionAndAcceptsNewSeparator() throws {
        let text = "2026年08月10日\n\n\n(请在双竖线左侧直接填写单词，右侧填写中文意思；每行填写一条，完成后保存并导入单词本。)\n\n\nlanguage｜｜      语言\n"
        let document = try WordBookMarkdownParser.parse(Data(text.utf8))

        #expect(document.words == [
            ParsedWord(term: "language", meaning: "语言", lineNumber: 1)
        ])
    }

    @Test func wordBookParserSkipsUnusedTemplateRows() throws {
        let text = "2026年08月10日\n\n\n(请在双竖线左侧直接填写单词，右侧填写中文意思；每行填写一条，完成后保存并导入单词本。)\n\n\nlanguage｜｜      语言\nstudy｜｜      学习\nremember｜｜      记住\n｜｜      \n｜｜      \n"
        let document = try WordBookMarkdownParser.parse(Data(text.utf8))

        #expect(document.words.map(\.lineNumber) == [1, 2, 3])
        #expect(document.words.map(\.term) == ["language", "study", "remember"])
    }

    @Test func wordBookParserAcceptsBOMAndWindowsLineEndings() throws {
        let text = "\u{FEFF}2026年08月10日\r\n\r\n\r\nlanguage   ｜｜   语言\r\nstudy   ｜｜   学习\r\n"
        let document = try WordBookMarkdownParser.parse(Data(text.utf8))

        #expect(document.sourceDate == VocabularyDocumentDate(year: 2026, month: 8, day: 10))
        #expect(document.words == [
            ParsedWord(term: "language", meaning: "语言", lineNumber: 1),
            ParsedWord(term: "study", meaning: "学习", lineNumber: 2)
        ])
    }

    @Test func wordBookParserAcceptsLegacySixSpaceSeparator() throws {
        let text = "2026年08月10日\n\n\n(请在每行双竖线左侧填写单词，右侧填写中文意思；每行填写一条，完成后保存并导入单词本。)\n\n\nlegacy      ｜｜      旧格式\n"
        let document = try WordBookMarkdownParser.parse(Data(text.utf8))

        #expect(document.words == [
            ParsedWord(term: "legacy", meaning: "旧格式", lineNumber: 1)
        ])
    }

    @Test func wordBookParserRejectsInvalidDateAndSeparator() {
        assertWordBookParseError(
            text: "2026年02月30日\n\n\nword   ｜｜   单词\n",
            expected: .invalidDate(line: "2026年02月30日")
        )
        assertWordBookParseError(
            text: "2026年08月10日\n\n\nword   ||   单词\n",
            expected: .invalidEntry(lineNumber: 1)
        )
        assertWordBookParseError(
            text: "2026年08月10日\n\nword   ｜｜   单词\n",
            expected: .missingRequiredBlankLines
        )
    }

    @Test func wordBookParserRejectsBlankTemplateAndEmptyFields() {
        assertWordBookParseError(
            text: "2026年08月10日\n\n\n｜｜      \n",
            expected: .noEntries
        )
        assertWordBookParseError(
            text: "2026年08月10日\n\n\nword｜｜      \n",
            expected: .emptyMeaning(lineNumber: 1)
        )
        assertWordBookParseError(
            text: "2026年08月10日\n\n\n",
            expected: .noEntries
        )
    }

    @Test func wordNormalizerKeepsLanguageSpecificRules() {
        #expect(
            WordNormalizer.normalizedTerm("  LangUAge\tStudy  ", in: .english)
                == "language study"
        )
        #expect(
            WordNormalizer.normalizedTerm("  ＡＢＣ　日本語  ", in: .japanese)
                == "ＡＢＣ 日本語"
        )
    }

    @Test @MainActor func wordBookRepositoryKeepsFirstMeaningAndDerivesFrequency() throws {
        let container = try makeWordBookContainer()
        let repository = SwiftDataWordBookRepository(modelContainer: container)
        let firstDate = try #require(VocabularyDocumentDate(year: 2026, month: 8, day: 10))
        let earlierDocumentDate = try #require(VocabularyDocumentDate(year: 2026, month: 8, day: 9))

        let firstResult = try repository.importDocument(
            ParsedWordDocument(
                sourceDate: firstDate,
                words: [
                    ParsedWord(term: "Language", meaning: "语言", lineNumber: 4),
                    ParsedWord(term: " language ", meaning: "语言能力", lineNumber: 5)
                ]
            ),
            into: .english,
            sourceFilename: "first.md",
            importedAt: Date(timeIntervalSince1970: 100)
        )
        let secondResult = try repository.importDocument(
            ParsedWordDocument(
                sourceDate: earlierDocumentDate,
                words: [
                    ParsedWord(term: "LANGUAGE", meaning: "语言学", lineNumber: 4)
                ]
            ),
            into: .english,
            sourceFilename: "second.md",
            importedAt: Date(timeIntervalSince1970: 200)
        )

        #expect(firstResult == WordBookImportResult(
            insertedEntryCount: 1,
            insertedOccurrenceCount: 1,
            skippedDuplicateCount: 1
        ))
        #expect(secondResult.insertedEntryCount == 0)
        #expect(secondResult.insertedOccurrenceCount == 1)

        let entry = try #require(repository.entries(in: .english).first)
        #expect(try repository.entries(in: .english).count == 1)
        #expect(entry.term == "Language")
        #expect(entry.meaning == "语言")
        #expect(entry.occurrenceDates == [earlierDocumentDate, firstDate])
        #expect(entry.isHighFrequency)
    }

    @Test @MainActor func wordBookRepositoryMakesSameDateReimportIdempotent() throws {
        let container = try makeWordBookContainer()
        let repository = SwiftDataWordBookRepository(modelContainer: container)
        let sourceDate = try #require(VocabularyDocumentDate(year: 2026, month: 8, day: 10))
        let document = ParsedWordDocument(
            sourceDate: sourceDate,
            words: [ParsedWord(term: "study", meaning: "学习", lineNumber: 4)]
        )

        _ = try repository.importDocument(
            document,
            into: .english,
            sourceFilename: "first.md",
            importedAt: Date(timeIntervalSince1970: 100)
        )
        let duplicateResult = try repository.importDocument(
            document,
            into: .english,
            sourceFilename: "again.md",
            importedAt: Date(timeIntervalSince1970: 200)
        )

        #expect(duplicateResult == WordBookImportResult(
            insertedEntryCount: 0,
            insertedOccurrenceCount: 0,
            skippedDuplicateCount: 1
        ))
        let context = ModelContext(container)
        #expect(try context.fetchCount(FetchDescriptor<WordEntry>()) == 1)
        #expect(try context.fetchCount(FetchDescriptor<WordOccurrence>()) == 1)
        #expect(try context.fetchCount(FetchDescriptor<WordImportBatch>()) == 1)
    }

    @Test @MainActor func wordBookRepositoryRollsBackWholeInvalidImport() throws {
        let container = try makeWordBookContainer()
        let repository = SwiftDataWordBookRepository(modelContainer: container)
        let sourceDate = try #require(VocabularyDocumentDate(year: 2026, month: 8, day: 10))
        let document = ParsedWordDocument(
            sourceDate: sourceDate,
            words: [
                ParsedWord(term: "valid", meaning: "有效", lineNumber: 4),
                ParsedWord(term: "invalid", meaning: "   ", lineNumber: 5)
            ]
        )

        do {
            _ = try repository.importDocument(
                document,
                into: .english,
                sourceFilename: "invalid.md",
                importedAt: Date(timeIntervalSince1970: 100)
            )
            Issue.record("包含空释义的导入应当失败。")
        } catch let error as WordBookRepositoryError {
            #expect(error == .emptyMeaning)
        }

        let context = ModelContext(container)
        #expect(try context.fetchCount(FetchDescriptor<WordEntry>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<WordOccurrence>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<WordImportBatch>()) == 0)
    }

    @Test @MainActor func wordBookRepositoryKeepsLanguageSpacesIndependent() throws {
        let container = try makeWordBookContainer()
        let repository = SwiftDataWordBookRepository(modelContainer: container)
        let sourceDate = try #require(VocabularyDocumentDate(year: 2026, month: 8, day: 10))
        let document = ParsedWordDocument(
            sourceDate: sourceDate,
            words: [ParsedWord(term: "study", meaning: "学习", lineNumber: 4)]
        )

        _ = try repository.importDocument(
            document,
            into: .english,
            sourceFilename: "english.md",
            importedAt: Date(timeIntervalSince1970: 100)
        )
        _ = try repository.importDocument(
            document,
            into: .japanese,
            sourceFilename: "japanese.md",
            importedAt: Date(timeIntervalSince1970: 200)
        )

        #expect(try repository.entries(in: .english).count == 1)
        #expect(try repository.entries(in: .japanese).count == 1)
        #expect(try repository.entries(in: .english).first?.occurrenceDates == [sourceDate])
        #expect(try repository.entries(in: .japanese).first?.occurrenceDates == [sourceDate])
    }

    @Test @MainActor func wordBookManualEntryHasNoDateAndSupportsExplicitEditing() throws {
        let container = try makeWordBookContainer()
        let repository = SwiftDataWordBookRepository(modelContainer: container)
        let entryID = try repository.addManualEntry(
            term: "  unfiled  ",
            meaning: "  未归档  ",
            in: .english
        )

        var entry = try #require(repository.entries(in: .english).first)
        #expect(entry.id == entryID)
        #expect(entry.source == .manual)
        #expect(entry.occurrenceDates.isEmpty)
        #expect(!entry.isHighFrequency)

        try repository.updateEntry(
            id: entryID,
            term: "unfiled word",
            meaning: "未归档单词",
            in: .english
        )
        entry = try #require(repository.entries(in: .english).first)
        #expect(entry.term == "unfiled word")
        #expect(entry.meaning == "未归档单词")

        let reloadedRepository = SwiftDataWordBookRepository(modelContainer: container)
        #expect(try reloadedRepository.entries(in: .english).first == entry)

        try reloadedRepository.deleteEntry(id: entryID, in: .english)
        #expect(try reloadedRepository.entries(in: .english).isEmpty)
    }

    @Test @MainActor func wordBookRepositoryDeletesImportedEntriesAndEmptyBatches() throws {
        let container = try makeWordBookContainer()
        let repository = SwiftDataWordBookRepository(modelContainer: container)
        let sourceDate = try #require(VocabularyDocumentDate(year: 2026, month: 8, day: 10))
        let document = ParsedWordDocument(
            sourceDate: sourceDate,
            words: [
                ParsedWord(term: "one", meaning: "一", lineNumber: 4),
                ParsedWord(term: "two", meaning: "二", lineNumber: 5)
            ]
        )
        _ = try repository.importDocument(
            document,
            into: .english,
            sourceFilename: "numbers.md",
            importedAt: Date(timeIntervalSince1970: 100)
        )

        let entries = try repository.entries(in: .english)
        try repository.deleteEntry(id: try #require(entries.first?.id), in: .english)

        let contextAfterFirstDelete = ModelContext(container)
        #expect(try contextAfterFirstDelete.fetchCount(FetchDescriptor<WordEntry>()) == 1)
        #expect(try contextAfterFirstDelete.fetchCount(FetchDescriptor<WordOccurrence>()) == 1)
        #expect(try contextAfterFirstDelete.fetchCount(FetchDescriptor<WordImportBatch>()) == 1)

        let remainingEntry = try #require(try repository.entries(in: .english).first)
        try repository.deleteEntry(id: remainingEntry.id, in: .english)

        let contextAfterSecondDelete = ModelContext(container)
        #expect(try contextAfterSecondDelete.fetchCount(FetchDescriptor<WordEntry>()) == 0)
        #expect(try contextAfterSecondDelete.fetchCount(FetchDescriptor<WordOccurrence>()) == 0)
        #expect(try contextAfterSecondDelete.fetchCount(FetchDescriptor<WordImportBatch>()) == 0)
    }

    @Test @MainActor func unavailableWordBookRepositoryRejectsWrites() {
        let repository = UnavailableWordBookRepository()
        #expect(throws: WordBookRepositoryError.storageUnavailable) {
            _ = try repository.addManualEntry(term: "word", meaning: "意思", in: .english)
        }
    }

    @Test @MainActor func wordBookDataSurvivesPersistentContainerReopen() throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "EgangnalWordBookTests-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let storeURL = directory.appending(path: "WordBook.store")
        let sourceDate = try #require(VocabularyDocumentDate(year: 2026, month: 8, day: 10))
        do {
            let container = try makePersistentWordBookContainer(at: storeURL)
            let repository = SwiftDataWordBookRepository(modelContainer: container)
            _ = try repository.importDocument(
                ParsedWordDocument(
                    sourceDate: sourceDate,
                    words: [ParsedWord(term: "persist", meaning: "持久化", lineNumber: 4)]
                ),
                into: .english,
                sourceFilename: "persistent.md",
                importedAt: Date(timeIntervalSince1970: 100)
            )
        }

        do {
            let reopenedContainer = try makePersistentWordBookContainer(at: storeURL)
            let reopenedRepository = SwiftDataWordBookRepository(
                modelContainer: reopenedContainer
            )
            let entry = try #require(reopenedRepository.entries(in: .english).first)
            #expect(entry.term == "persist")
            #expect(entry.meaning == "持久化")
            #expect(entry.occurrenceDates == [sourceDate])

            let context = ModelContext(reopenedContainer)
            #expect(try context.fetchCount(FetchDescriptor<WordImportBatch>()) == 1)
            #expect(try context.fetchCount(FetchDescriptor<WordOccurrence>()) == 1)
        }
    }

    @Test @MainActor func studyTimeAccumulatesLanguageSpacesIndependently() {
        let clock = TestStudyTimeClock()
        let repository = TestStudyTimeRepository()
        let controller = StudyTimeController(repository: repository, clock: clock)

        #expect(controller.show(.japanese))
        clock.advance(by: 3_600)
        #expect(controller.show(.english))
        clock.advance(by: 1_800)
        _ = controller.leaveSpace()

        #expect(controller.totalSeconds(for: .japanese) == 3_600)
        #expect(controller.totalSeconds(for: .english) == 1_800)
        #expect(repository.totalSeconds(for: .japanese) == 3_600)
        #expect(repository.totalSeconds(for: .english) == 1_800)
    }

    @Test @MainActor func studyTimeMarksEntryEvenWithoutElapsedSeconds() {
        let dateProvider = TestStudyTimeDateProvider(date: makeUTCDate(2026, 8, 19, 9))
        let dateKey = StudyDateKey(year: 2026, month: 8, day: 19)
        let repository = TestStudyTimeRepository()
        let controller = StudyTimeController(
            repository: repository,
            clock: TestStudyTimeClock(),
            dateProvider: dateProvider,
            calendar: makeUTCCalendar()
        )

        #expect(controller.show(.japanese))
        _ = controller.leaveSpace()

        #expect(controller.dailyFeedbackStatus(for: dateKey) == .visited)
        #expect(repository.dailyActivity(on: dateKey, for: .japanese)?.studiedSeconds == 0)
    }

    @Test @MainActor func studyTimeDailyFeedbackSplitsAcrossMidnight() {
        let clock = TestStudyTimeClock()
        let dateProvider = TestStudyTimeDateProvider(
            date: makeUTCDate(2026, 8, 19, 23, 55)
        )
        let repository = TestStudyTimeRepository()
        let controller = StudyTimeController(
            repository: repository,
            clock: clock,
            dateProvider: dateProvider,
            calendar: makeUTCCalendar()
        )
        let firstDay = StudyDateKey(year: 2026, month: 8, day: 19)
        let secondDay = StudyDateKey(year: 2026, month: 8, day: 20)

        #expect(controller.show(.english))
        clock.advance(by: 900)
        dateProvider.advance(by: 900)
        _ = controller.leaveSpace()

        #expect(
            repository.dailyActivity(on: firstDay, for: .english)?.studiedSeconds == 300
        )
        #expect(
            repository.dailyActivity(on: secondDay, for: .english)?.studiedSeconds == 600
        )
        #expect(controller.dailyFeedbackStatus(for: firstDay) == .visited)
        #expect(controller.dailyFeedbackStatus(for: secondDay) == .visited)
    }

    @Test @MainActor func studyTimeDoesNotDoubleCountRepeatedActivation() {
        let clock = TestStudyTimeClock()
        let controller = StudyTimeController(
            repository: TestStudyTimeRepository(),
            clock: clock
        )

        #expect(controller.show(.japanese))
        clock.advance(by: 10)
        #expect(controller.show(.japanese))
        clock.advance(by: 5)
        _ = controller.leaveSpace()

        #expect(controller.totalSeconds(for: .japanese) == 15)
    }

    @Test @MainActor func studyTimePausesWhenApplicationIsInactive() {
        let clock = TestStudyTimeClock()
        let controller = StudyTimeController(
            repository: TestStudyTimeRepository(),
            clock: clock
        )

        #expect(controller.show(.english))
        clock.advance(by: 10)
        controller.applicationWillResignActive()
        clock.advance(by: 100)
        controller.applicationDidBecomeActive()
        clock.advance(by: 5)
        _ = controller.leaveSpace()

        #expect(controller.totalSeconds(for: .english) == 15)
    }

    @Test @MainActor func studyTimeRetryKeepsPauseBoundaryWithoutCountingBackground() {
        let clock = TestStudyTimeClock()
        let repository = TestStudyTimeRepository()
        let controller = StudyTimeController(repository: repository, clock: clock)

        #expect(controller.show(.japanese))
        clock.advance(by: 10)
        repository.failNextSave = true
        controller.applicationWillResignActive()
        #expect(controller.activeSpace == nil)
        #expect(controller.hasUnsavedChanges)

        clock.advance(by: 100)
        repository.failNextSave = false
        controller.applicationDidBecomeActive()
        clock.advance(by: 5)
        _ = controller.leaveSpace()

        #expect(controller.totalSeconds(for: .japanese) == 15)
        #expect(!controller.hasUnsavedChanges)
    }

    @Test @MainActor func studyTimeDisplayUsesRoundedHoursAndExpectedTiers() {
        #expect(StudyTimeDisplayTier(hours: 0) == .default)
        #expect(StudyTimeDisplayTier(hours: 50) == .default)
        #expect(StudyTimeDisplayTier(hours: 50.1) == .blue)
        #expect(StudyTimeDisplayTier(hours: 100) == .blue)
        #expect(StudyTimeDisplayTier(hours: 100.1) == .purple)
        #expect(StudyTimeDisplayTier(hours: 300) == .purple)
        #expect(StudyTimeDisplayTier(hours: 300.1) == .orange)

        let repository = TestStudyTimeRepository(
            totals: [.japanese: 50.04 * 3_600]
        )
        let controller = StudyTimeController(
            repository: repository,
            clock: TestStudyTimeClock()
        )
        #expect(controller.displayedHours(for: .japanese) == 50.0)
        #expect(controller.displayTier(for: .japanese) == .default)
    }

    @Test @MainActor func studyTimeDisplayIncludesUncommittedActiveElapsedTime() {
        let clock = TestStudyTimeClock()
        let repository = TestStudyTimeRepository()
        let controller = StudyTimeController(repository: repository, clock: clock)

        #expect(controller.show(.japanese))
        clock.advance(by: 360)

        #expect(controller.displayedHours(for: .japanese) == 0.1)
        #expect(repository.totalSeconds(for: .japanese) == 0)
    }

    @Test @MainActor func swiftDataStudyTimeSurvivesRepositoryReopen() throws {
        let schema = Schema([StudyTimeRecord.self, DailyStudyActivity.self])
        let configuration = ModelConfiguration(
            "StudyTimeRepositoryTests",
            schema: schema,
            isStoredInMemoryOnly: true,
            cloudKitDatabase: .none
        )
        let container = try ModelContainer(
            for: schema,
            configurations: [configuration]
        )

        let repository = SwiftDataStudyTimeRepository(modelContainer: container)
        let initial = try repository.loadAll()
        #expect(initial[.japanese]?.totalSeconds == 0)
        #expect(initial[.english]?.totalSeconds == 0)
        try repository.saveTotalSeconds(123.45, for: .japanese, at: .now)

        let reopenedRepository = SwiftDataStudyTimeRepository(modelContainer: container)
        let reloaded = try reopenedRepository.loadAll()
        #expect(reloaded[.japanese]?.totalSeconds == 123.45)
        #expect(reloaded[.english]?.totalSeconds == 0)
    }
}

/// 洗牌测试必须用确定性 UUID：随机 UUID 会让结果无法复现。
private func makeShuffleEntry(index: Int) -> WordBookEntrySnapshot {
    WordBookEntrySnapshot(
        id: UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", index))!,
        term: "word-\(index)",
        meaning: "释义-\(index)",
        source: .manual,
        occurrenceDates: []
    )
}

private func makePresentationEntry(
    index: Int,
    dates: [VocabularyDocumentDate] = []
) -> WordBookEntrySnapshot {
    WordBookEntrySnapshot(
        id: UUID(),
        term: "word-\(index)",
        meaning: "释义-\(index)",
        source: dates.isEmpty ? .manual : .markdownImport,
        occurrenceDates: dates
    )
}

private func assertWordBookParseError(
    text: String,
    expected: WordBookMarkdownError,
    sourceLocation: SourceLocation = #_sourceLocation
) {
    do {
        _ = try WordBookMarkdownParser.parse(Data(text.utf8))
        Issue.record("预期解析失败，但文档被接受。", sourceLocation: sourceLocation)
    } catch let error as WordBookMarkdownError {
        #expect(error == expected, sourceLocation: sourceLocation)
    } catch {
        Issue.record("出现了错误类型之外的异常：\(error)", sourceLocation: sourceLocation)
    }
}

@MainActor
private func makeWordBookContainer() throws -> ModelContainer {
    let schema = wordBookSchema()
    let configuration = ModelConfiguration(
        "WordBookRepositoryTests-\(UUID().uuidString)",
        schema: schema,
        isStoredInMemoryOnly: true
    )
    return try ModelContainer(for: schema, configurations: [configuration])
}

@MainActor
private func makePersistentWordBookContainer(at url: URL) throws -> ModelContainer {
    let schema = wordBookSchema()
    let configuration = ModelConfiguration(
        "WordBookPersistentTests",
        schema: schema,
        url: url,
        cloudKitDatabase: .none
    )
    return try ModelContainer(for: schema, configurations: [configuration])
}

private func wordBookSchema() -> Schema {
    Schema([
        WordEntry.self,
        WordImportBatch.self,
        WordOccurrence.self
    ])
}

@MainActor
private final class TestProfileRepository: ProfileRepository {
    private let storedNickname: String?
    private let shouldFailSaving: Bool

    private(set) var savedNickname: String?

    init(
        storedNickname: String? = nil,
        shouldFailSaving: Bool = false
    ) {
        self.storedNickname = storedNickname
        self.shouldFailSaving = shouldFailSaving
    }

    func loadNickname() throws -> String? {
        storedNickname
    }

    func saveNickname(_ nickname: String) throws {
        if shouldFailSaving {
            throw TestProfileRepositoryError.saveFailed
        }
        savedNickname = nickname
    }
}

private enum TestProfileRepositoryError: Error {
    case saveFailed
}

@MainActor
private final class TestStudyTimeClock: StudyTimeClock {
    private(set) var currentTime: TimeInterval = 0

    func now() -> TimeInterval {
        currentTime
    }

    func advance(by seconds: TimeInterval) {
        currentTime += seconds
    }
}

@MainActor
private final class TestStudyTimeDateProvider: StudyTimeDateProvider {
    private(set) var currentDate: Date

    init(date: Date) {
        currentDate = date
    }

    func now() -> Date { currentDate }

    func advance(by seconds: TimeInterval) {
        currentDate = currentDate.addingTimeInterval(seconds)
    }
}

private func makeUTCCalendar() -> Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    calendar.firstWeekday = 2
    return calendar
}

private func makeUTCDate(
    _ year: Int,
    _ month: Int,
    _ day: Int,
    _ hour: Int,
    _ minute: Int = 0
) -> Date {
    makeUTCCalendar().date(
        from: DateComponents(
            year: year,
            month: month,
            day: day,
            hour: hour,
            minute: minute
        )
    )!
}

@MainActor
private final class TestStudyTimeRepository: StudyTimeRepository {
    private var totals: [LanguageSpace: Double]
    private var dailyActivities: [String: DailyStudyActivitySnapshot]
    var failNextSave = false

    init(
        totals: [LanguageSpace: Double] = [:],
        dailyActivities: [DailyStudyActivitySnapshot] = []
    ) {
        self.totals = Dictionary(
            uniqueKeysWithValues: LanguageSpace.allCases.map {
                ($0, totals[$0] ?? 0)
            }
        )
        self.dailyActivities = Dictionary(
            uniqueKeysWithValues: dailyActivities.map {
                ("\($0.dateKey.rawValue)|\($0.space.rawValue)", $0)
            }
        )
    }

    func loadAll() throws -> [LanguageSpace: StudyTimeSnapshot] {
        Dictionary(
            uniqueKeysWithValues: totals.map {
                ($0.key, StudyTimeSnapshot(totalSeconds: $0.value))
            }
        )
    }

    func saveTotalSeconds(
        _ totalSeconds: Double,
        for space: LanguageSpace,
        at date: Date
    ) throws {
        if failNextSave {
            failNextSave = false
            throw TestStudyTimeRepositoryError.saveFailed
        }
        totals[space] = totalSeconds
    }

    func loadDailyActivities() throws -> [DailyStudyActivitySnapshot] {
        Array(dailyActivities.values)
    }

    func markEntered(
        on dateKey: StudyDateKey,
        for space: LanguageSpace,
        at date: Date
    ) throws {
        if failNextSave {
            failNextSave = false
            throw TestStudyTimeRepositoryError.saveFailed
        }
        let identity = "\(dateKey.rawValue)|\(space.rawValue)"
        if let current = dailyActivities[identity] {
            dailyActivities[identity] = DailyStudyActivitySnapshot(
                dateKey: current.dateKey,
                space: current.space,
                studiedSeconds: current.studiedSeconds,
                hasEntered: true
            )
        } else {
            dailyActivities[identity] = DailyStudyActivitySnapshot(
                dateKey: dateKey,
                space: space,
                studiedSeconds: 0,
                hasEntered: true
            )
        }
    }

    func saveStudyTime(
        _ totalSeconds: Double,
        for space: LanguageSpace,
        dailyIncrements: [DailyStudyActivityIncrement],
        at date: Date
    ) throws {
        if failNextSave {
            failNextSave = false
            throw TestStudyTimeRepositoryError.saveFailed
        }
        totals[space] = totalSeconds
        for increment in dailyIncrements where increment.seconds > 0 {
            let identity = "\(increment.dateKey.rawValue)|\(space.rawValue)"
            let current = dailyActivities[identity]
            dailyActivities[identity] = DailyStudyActivitySnapshot(
                dateKey: increment.dateKey,
                space: space,
                studiedSeconds: (current?.studiedSeconds ?? 0) + increment.seconds,
                hasEntered: true
            )
        }
    }

    func dailyActivity(
        on dateKey: StudyDateKey,
        for space: LanguageSpace
    ) -> DailyStudyActivitySnapshot? {
        dailyActivities["\(dateKey.rawValue)|\(space.rawValue)"]
    }

    func totalSeconds(for space: LanguageSpace) -> Double {
        totals[space] ?? 0
    }
}

private enum TestStudyTimeRepositoryError: Error {
    case saveFailed
}

private final class TestAppearancePreferences: AppearancePreferences {
    private(set) var values: [String: String]

    init(values: [String: String] = [:]) {
        self.values = values
    }

    func string(forKey defaultName: String) -> String? {
        values[defaultName]
    }

    func set(_ value: Any?, forKey defaultName: String) {
        values[defaultName] = value as? String
    }
}

private final class TestWorkspaceNavigationPreferences: WorkspaceNavigationPreferences {
    private(set) var values: [String: String]

    init(values: [String: String] = [:]) {
        self.values = values
    }

    func string(forKey defaultName: String) -> String? {
        values[defaultName]
    }

    func set(_ value: Any?, forKey defaultName: String) {
        values[defaultName] = value as? String
    }
}

private final class TestAppSettingsPreferences: AppSettingsPreferences {
    private var values: [String: Any] = [:]

    func object(forKey defaultName: String) -> Any? {
        values[defaultName]
    }

    func data(forKey defaultName: String) -> Data? {
        values[defaultName] as? Data
    }

    func string(forKey defaultName: String) -> String? {
        values[defaultName] as? String
    }

    func set(_ value: Any?, forKey defaultName: String) {
        values[defaultName] = value
    }

    func removeObject(forKey defaultName: String) {
        values.removeValue(forKey: defaultName)
    }
}

@MainActor
private final class TestExportDirectoryService: ExportDirectoryService {
    var exportResult: PreferredDirectoryExportResult = .unavailable
    private(set) var exportCallCount = 0

    func makeSelection(for directoryURL: URL) throws -> ExportDirectorySelection {
        ExportDirectorySelection(
            bookmarkData: Data([1, 2, 3]),
            displayPath: directoryURL.path
        )
    }

    func export(
        data: Data,
        preferredFilename: String,
        using bookmarkData: Data
    ) throws -> PreferredDirectoryExportResult {
        exportCallCount += 1
        return exportResult
    }
}

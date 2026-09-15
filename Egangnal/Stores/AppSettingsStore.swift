//
//  AppSettingsStore.swift
//  Egangnal
//

import Foundation
import Observation

protocol AppSettingsPreferences: AnyObject {
    func object(forKey defaultName: String) -> Any?
    func data(forKey defaultName: String) -> Data?
    func string(forKey defaultName: String) -> String?
    func set(_ value: Any?, forKey defaultName: String)
    func removeObject(forKey defaultName: String)
}

extension UserDefaults: AppSettingsPreferences {}

@MainActor
@Observable
final class AppSettingsStore {
    enum StorageKey {
        static let languageCardArtwork = "settings.languageCardArtwork"
        static let dashboardBackgroundPattern = "settings.dashboardBackgroundPattern"
        static let wordBookBackgroundPattern = "settings.background.wordBook"
        static let lexiconBackgroundPattern = "settings.background.lexicon"
        static let wordQuizBackgroundPattern = "settings.background.wordQuiz"
        static let wordBookLayout = "settings.wordBookLayout"
        static let lexiconLayout = "settings.lexiconLayout"
        static let wordBookRuledLineStyle = "settings.ruledLineStyle.wordBook"
        static let lexiconRuledLineStyle = "settings.ruledLineStyle.lexicon"
        static let wordBookLamp = "settings.wordBookLamp"
        static let lexiconGuideWords = "settings.lexiconGuideWords"
        static let lexiconStamp = "settings.lexiconStamp"
        static let wordQuizSoundEffect = "settings.wordQuizSoundEffect"
        static let exportDirectoryBookmark = "settings.exportDirectoryBookmark"
        static let exportDirectoryPath = "settings.exportDirectoryPath"

        // 以下旧键只在对应新键缺失时读取一次，任何路径都不能再写入。
        /// 1.0.4 及更早版本的全局网格开关。
        static let legacyGridBackground = "settings.gridBackground"
        /// 阶段 7 未发布中间版本的单词本图案（网格 / 点阵）。
        static let legacyWordBookBackgroundPattern = "settings.wordBookBackgroundPattern"
        /// 阶段 7 未发布中间版本里所有功能页共用的背景。
        static let legacyFeatureBackgroundPattern = "settings.featureBackgroundPattern"
        /// 阶段 7 未发布中间版本里单词本与集词阁共用的横格线样式。
        static let legacyRuledLineStyle = "settings.ruledLineStyle"
    }

    private let preferences: (any AppSettingsPreferences)?
    private let exportDirectoryService: any ExportDirectoryService
    private var exportDirectoryBookmark: Data?

    private(set) var showsLanguageCardArtwork: Bool
    private(set) var dashboardBackgroundPattern: PageBackgroundPattern
    private(set) var wordBook: WordBookPersonalization
    private(set) var lexicon: LexiconPersonalization
    private(set) var wordQuiz: WordQuizPersonalization
    private(set) var wordQuizSoundEffect: WordQuizSoundEffect
    private(set) var exportDirectoryPath: String?

    init(
        preferences: (any AppSettingsPreferences)? = UserDefaults.standard,
        exportDirectoryService: any ExportDirectoryService = SecurityScopedExportDirectoryService()
    ) {
        self.preferences = preferences
        self.exportDirectoryService = exportDirectoryService
        showsLanguageCardArtwork = Self.storedBoolean(
            forKey: StorageKey.languageCardArtwork,
            preferences: preferences,
            defaultValue: true
        )
        dashboardBackgroundPattern = Self.storedBackgroundPattern(
            forKey: StorageKey.dashboardBackgroundPattern,
            interimKey: nil,
            legacyPatternKey: nil,
            preferences: preferences
        )
        // 排版与线条偏好用稳定字符串保存；读到未知值时回到默认样式，不让旧版本的值卡住启动。
        // 氛围元素默认关闭：它们是可选的沉浸装饰，不能在升级后突然出现在用户面前。
        wordBook = WordBookPersonalization(
            layout: Self.storedChoice(
                forKey: StorageKey.wordBookLayout,
                preferences: preferences,
                defaultValue: .standard
            ),
            ruledLineStyle: Self.storedRuledLineStyle(
                forKey: StorageKey.wordBookRuledLineStyle,
                preferences: preferences
            ),
            backgroundPattern: Self.storedBackgroundPattern(
                forKey: StorageKey.wordBookBackgroundPattern,
                interimKey: StorageKey.legacyFeatureBackgroundPattern,
                legacyPatternKey: StorageKey.legacyWordBookBackgroundPattern,
                preferences: preferences
            ),
            showsLamp: Self.storedBoolean(
                forKey: StorageKey.wordBookLamp,
                preferences: preferences,
                defaultValue: false
            )
        )
        lexicon = LexiconPersonalization(
            layout: Self.storedChoice(
                forKey: StorageKey.lexiconLayout,
                preferences: preferences,
                defaultValue: .standard
            ),
            ruledLineStyle: Self.storedRuledLineStyle(
                forKey: StorageKey.lexiconRuledLineStyle,
                preferences: preferences
            ),
            backgroundPattern: Self.storedBackgroundPattern(
                forKey: StorageKey.lexiconBackgroundPattern,
                interimKey: StorageKey.legacyFeatureBackgroundPattern,
                legacyPatternKey: nil,
                preferences: preferences
            ),
            showsGuideWords: Self.storedBoolean(
                forKey: StorageKey.lexiconGuideWords,
                preferences: preferences,
                defaultValue: false
            ),
            showsStamp: Self.storedBoolean(
                forKey: StorageKey.lexiconStamp,
                preferences: preferences,
                defaultValue: false
            )
        )
        wordQuiz = WordQuizPersonalization(
            backgroundPattern: Self.storedBackgroundPattern(
                forKey: StorageKey.wordQuizBackgroundPattern,
                interimKey: StorageKey.legacyFeatureBackgroundPattern,
                legacyPatternKey: nil,
                preferences: preferences
            )
        )
        wordQuizSoundEffect = Self.storedChoice(
            forKey: StorageKey.wordQuizSoundEffect,
            preferences: preferences,
            defaultValue: .off
        )
        let storedBookmark = preferences?.data(
            forKey: StorageKey.exportDirectoryBookmark
        )
        let storedPath = preferences?.string(
            forKey: StorageKey.exportDirectoryPath
        )
        // 书签和展示路径必须成对存在，避免界面显示“未设置”却仍直接导出。
        if storedBookmark != nil, storedPath != nil {
            exportDirectoryBookmark = storedBookmark
            exportDirectoryPath = storedPath
        } else {
            exportDirectoryBookmark = nil
            exportDirectoryPath = nil
        }
    }

    var personalization: AppPersonalization {
        AppPersonalization(
            showsLanguageCardArtwork: showsLanguageCardArtwork,
            dashboardBackgroundPattern: dashboardBackgroundPattern,
            wordBook: wordBook,
            lexicon: lexicon,
            wordQuiz: wordQuiz
        )
    }

    var hasExportDirectory: Bool {
        exportDirectoryBookmark != nil && exportDirectoryPath != nil
    }

    func setLanguageCardArtwork(_ isEnabled: Bool) {
        showsLanguageCardArtwork = isEnabled
        preferences?.set(isEnabled, forKey: StorageKey.languageCardArtwork)
    }

    /// 每个页面的背景各自落盘；这里是唯一的写入口，保证不会有两个页面写到同一个键。
    func setBackgroundPattern(
        _ pattern: PageBackgroundPattern,
        for page: PageBackgroundScope
    ) {
        switch page {
        case .dashboard:
            dashboardBackgroundPattern = pattern
            preferences?.set(pattern.rawValue, forKey: StorageKey.dashboardBackgroundPattern)
        case .wordBook:
            wordBook.backgroundPattern = pattern
            preferences?.set(pattern.rawValue, forKey: StorageKey.wordBookBackgroundPattern)
        case .lexicon:
            lexicon.backgroundPattern = pattern
            preferences?.set(pattern.rawValue, forKey: StorageKey.lexiconBackgroundPattern)
        case .wordQuiz:
            wordQuiz.backgroundPattern = pattern
            preferences?.set(pattern.rawValue, forKey: StorageKey.wordQuizBackgroundPattern)
        }
    }

    func setWordBookLayout(_ layout: WordBookLayoutStyle) {
        wordBook.layout = layout
        preferences?.set(layout.rawValue, forKey: StorageKey.wordBookLayout)
    }

    func setWordBookRuledLineStyle(_ style: RuledLineStyle) {
        wordBook.ruledLineStyle = style
        preferences?.set(style.rawValue, forKey: StorageKey.wordBookRuledLineStyle)
    }

    func setWordBookLamp(_ isEnabled: Bool) {
        wordBook.showsLamp = isEnabled
        preferences?.set(isEnabled, forKey: StorageKey.wordBookLamp)
    }

    func setLexiconLayout(_ layout: LexiconLayoutStyle) {
        lexicon.layout = layout
        preferences?.set(layout.rawValue, forKey: StorageKey.lexiconLayout)
    }

    func setLexiconRuledLineStyle(_ style: RuledLineStyle) {
        lexicon.ruledLineStyle = style
        preferences?.set(style.rawValue, forKey: StorageKey.lexiconRuledLineStyle)
    }

    func setLexiconGuideWords(_ isEnabled: Bool) {
        lexicon.showsGuideWords = isEnabled
        preferences?.set(isEnabled, forKey: StorageKey.lexiconGuideWords)
    }

    func setLexiconStamp(_ isEnabled: Bool) {
        lexicon.showsStamp = isEnabled
        preferences?.set(isEnabled, forKey: StorageKey.lexiconStamp)
    }

    func setWordQuizSoundEffect(_ effect: WordQuizSoundEffect) {
        wordQuizSoundEffect = effect
        preferences?.set(effect.rawValue, forKey: StorageKey.wordQuizSoundEffect)
    }

    func selectExportDirectory(_ directoryURL: URL) throws {
        let selection = try exportDirectoryService.makeSelection(for: directoryURL)
        exportDirectoryBookmark = selection.bookmarkData
        exportDirectoryPath = selection.displayPath
        preferences?.set(
            selection.bookmarkData,
            forKey: StorageKey.exportDirectoryBookmark
        )
        preferences?.set(
            selection.displayPath,
            forKey: StorageKey.exportDirectoryPath
        )
    }

    func clearExportDirectory() {
        exportDirectoryBookmark = nil
        exportDirectoryPath = nil
        preferences?.removeObject(forKey: StorageKey.exportDirectoryBookmark)
        preferences?.removeObject(forKey: StorageKey.exportDirectoryPath)
    }

    /// 返回 nil 表示默认目录不可用，调用方应打开系统保存面板。
    func exportToPreferredDirectory(
        data: Data,
        preferredFilename: String
    ) throws -> URL? {
        guard let exportDirectoryBookmark else { return nil }

        switch try exportDirectoryService.export(
            data: data,
            preferredFilename: preferredFilename,
            using: exportDirectoryBookmark
        ) {
        case .unavailable:
            return nil
        case let .exported(url, refreshedBookmarkData):
            if let refreshedBookmarkData {
                self.exportDirectoryBookmark = refreshedBookmarkData
                preferences?.set(
                    refreshedBookmarkData,
                    forKey: StorageKey.exportDirectoryBookmark
                )
                let refreshedDirectoryPath = ExportDirectoryPath.displayPath(
                    for: url.deletingLastPathComponent()
                )
                self.exportDirectoryPath = refreshedDirectoryPath
                preferences?.set(
                    refreshedDirectoryPath,
                    forKey: StorageKey.exportDirectoryPath
                )
            }
            return url
        }
    }

    private static func storedBoolean(
        forKey key: String,
        preferences: (any AppSettingsPreferences)?,
        defaultValue: Bool
    ) -> Bool {
        guard let value = preferences?.object(forKey: key) as? Bool else {
            return defaultValue
        }
        return value
    }

    private static func storedChoice<Choice: RawRepresentable>(
        forKey key: String,
        preferences: (any AppSettingsPreferences)?,
        defaultValue: Choice
    ) -> Choice where Choice.RawValue == String {
        guard let rawValue = preferences?.string(forKey: key),
              let choice = Choice(rawValue: rawValue) else {
            return defaultValue
        }
        return choice
    }

    /// 按页读取背景。页键存在就以它为准（未知值回到网格）；否则依次回退到
    /// 中间版本的功能页共用键、1.0.4 的全局网格开关与旧单词本图案，保证升级后画面不变。
    private static func storedBackgroundPattern(
        forKey key: String,
        interimKey: String?,
        legacyPatternKey: String?,
        preferences: (any AppSettingsPreferences)?
    ) -> PageBackgroundPattern {
        for candidate in [key, interimKey].compactMap({ $0 })
        where preferences?.object(forKey: candidate) != nil {
            return storedChoice(
                forKey: candidate,
                preferences: preferences,
                defaultValue: .grid
            )
        }

        let legacyGridIsEnabled = storedBoolean(
            forKey: StorageKey.legacyGridBackground,
            preferences: preferences,
            defaultValue: true
        )
        guard legacyGridIsEnabled else { return .none }
        guard let legacyPatternKey else { return .grid }
        return storedChoice(
            forKey: legacyPatternKey,
            preferences: preferences,
            defaultValue: .grid
        )
    }

    /// 横格线样式按页保存；页键缺失时沿用中间版本两页共用的旧值，用户之前的选择不丢。
    private static func storedRuledLineStyle(
        forKey key: String,
        preferences: (any AppSettingsPreferences)?
    ) -> RuledLineStyle {
        for candidate in [key, StorageKey.legacyRuledLineStyle]
        where preferences?.object(forKey: candidate) != nil {
            return storedChoice(
                forKey: candidate,
                preferences: preferences,
                defaultValue: .alignedSolid
            )
        }
        return .alignedSolid
    }
}

extension AppSettingsStore {
    static var preview: AppSettingsStore {
        AppSettingsStore(preferences: nil)
    }
}

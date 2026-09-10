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
        static let gridBackground = "settings.gridBackground"
        static let wordQuizSoundEffect = "settings.wordQuizSoundEffect"
        static let exportDirectoryBookmark = "settings.exportDirectoryBookmark"
        static let exportDirectoryPath = "settings.exportDirectoryPath"
    }

    private let preferences: (any AppSettingsPreferences)?
    private let exportDirectoryService: any ExportDirectoryService
    private var exportDirectoryBookmark: Data?

    private(set) var showsLanguageCardArtwork: Bool
    private(set) var showsGridBackground: Bool
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
        showsGridBackground = Self.storedBoolean(
            forKey: StorageKey.gridBackground,
            preferences: preferences,
            defaultValue: true
        )
        wordQuizSoundEffect = WordQuizSoundEffect(
            rawValue: preferences?.string(forKey: StorageKey.wordQuizSoundEffect) ?? ""
        ) ?? .off
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
            showsGridBackground: showsGridBackground
        )
    }

    var hasExportDirectory: Bool {
        exportDirectoryBookmark != nil && exportDirectoryPath != nil
    }

    func setLanguageCardArtwork(_ isEnabled: Bool) {
        showsLanguageCardArtwork = isEnabled
        preferences?.set(isEnabled, forKey: StorageKey.languageCardArtwork)
    }

    func setGridBackground(_ isEnabled: Bool) {
        showsGridBackground = isEnabled
        preferences?.set(isEnabled, forKey: StorageKey.gridBackground)
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
}

extension AppSettingsStore {
    static var preview: AppSettingsStore {
        AppSettingsStore(preferences: nil)
    }
}

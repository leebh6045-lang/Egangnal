//
//  AppDependencies.swift
//  Egangnal
//

import Foundation
import SwiftData

@MainActor
struct AppDependencies {
    let modelContainer: ModelContainer
    let profileStore: ProfileStore
    let appearanceStore: AppearanceStore
    let settingsStore: AppSettingsStore
    let workspaceNavigationStore: WorkspaceNavigationStore
    let wordQuizSoundPlayer: any WordQuizSoundPlaying
    let wordBookRepository: any WordBookRepository
    let studyTimeController: StudyTimeController
    let appUpdateController: any AppUpdating

    static func live() -> AppDependencies {
        let arguments = ProcessInfo.processInfo.arguments
        let isUITesting = arguments.contains("--ui-testing")
        let defaultAppearance: AppAppearance = arguments.contains("--ui-testing-light-theme")
            ? .light
            : .dark
        let appearanceStore = AppearanceStore(
            preferences: isUITesting ? nil : UserDefaults.standard,
            defaultMode: defaultAppearance
        )
        let settingsStore = AppSettingsStore(
            preferences: isUITesting ? nil : UserDefaults.standard
        )
        let workspaceNavigationStore = WorkspaceNavigationStore(
            preferences: isUITesting ? nil : UserDefaults.standard
        )
        let wordQuizSoundPlayer: any WordQuizSoundPlaying = isUITesting
            ? SilentWordQuizSoundPlayer()
            : AVAudioWordQuizSoundPlayer()
        let appUpdateController: any AppUpdating = isUITesting
            ? DisabledAppUpdateController()
            : AppUpdateController()

        if isUITesting {
            do {
                let dependencies = try make(
                    isStoredInMemoryOnly: true,
                    appearanceStore: appearanceStore,
                    settingsStore: settingsStore,
                    workspaceNavigationStore: workspaceNavigationStore,
                    wordQuizSoundPlayer: wordQuizSoundPlayer,
                    appUpdateController: appUpdateController
                )
                if arguments.contains("--ui-testing-word-book-fixtures") {
                    try seedWordBookFixtures(in: dependencies.wordBookRepository)
                }
                if arguments.contains("--ui-testing-word-book-pagination-fixtures") {
                    try seedWordBookPaginationFixtures(in: dependencies.wordBookRepository)
                }
                if arguments.contains("--ui-testing-word-quiz-fixtures") {
                    try seedWordQuizFixtures(in: dependencies.wordBookRepository)
                }
                return dependencies
            } catch {
                preconditionFailure("无法创建 UI 测试数据容器：\(error.localizedDescription)")
            }
        }

        do {
            return try make(
                isStoredInMemoryOnly: false,
                appearanceStore: appearanceStore,
                settingsStore: settingsStore,
                workspaceNavigationStore: workspaceNavigationStore,
                wordQuizSoundPlayer: wordQuizSoundPlayer,
                appUpdateController: appUpdateController
            )
        } catch {
            do {
                return try make(
                    isStoredInMemoryOnly: true,
                    initialMessage: "本地持久化暂不可用：单词本写入和学习计时已禁用。",
                    appearanceStore: appearanceStore,
                    settingsStore: settingsStore,
                    workspaceNavigationStore: workspaceNavigationStore,
                    wordQuizSoundPlayer: wordQuizSoundPlayer,
                    appUpdateController: appUpdateController
                )
            } catch {
                // 内存容器也无法创建时，应用没有可继续运行的安全存储环境。
                preconditionFailure("无法创建 SwiftData 容器：\(error.localizedDescription)")
            }
        }
    }

    private static func make(
        isStoredInMemoryOnly: Bool,
        initialMessage: String? = nil,
        appearanceStore: AppearanceStore,
        settingsStore: AppSettingsStore,
        workspaceNavigationStore: WorkspaceNavigationStore,
        wordQuizSoundPlayer: any WordQuizSoundPlaying,
        appUpdateController: any AppUpdating
    ) throws -> AppDependencies {
        let schema = Schema([
            UserProfile.self,
            StudyTimeRecord.self,
            DailyStudyActivity.self,
            WordEntry.self,
            WordImportBatch.self,
            WordOccurrence.self
        ])
        let configuration = ModelConfiguration(
            "Egangnal",
            schema: schema,
            isStoredInMemoryOnly: isStoredInMemoryOnly,
            groupContainer: .none,
            cloudKitDatabase: .none
        )
        let modelContainer = try ModelContainer(
            for: schema,
            configurations: [configuration]
        )
        let repository = SwiftDataProfileRepository(modelContainer: modelContainer)
        let wordBookRepository: any WordBookRepository
        if isStoredInMemoryOnly && initialMessage != nil {
            // 生产环境降级到内存容器时禁止单词本写入，避免退出后静默丢失数据。
            wordBookRepository = UnavailableWordBookRepository()
        } else {
            wordBookRepository = SwiftDataWordBookRepository(modelContainer: modelContainer)
        }
        let profileStore = ProfileStore(
            repository: repository,
            initialMessage: initialMessage
        )
        let studyTimeRepository: any StudyTimeRepository
        if isStoredInMemoryOnly && initialMessage != nil {
            studyTimeRepository = UnavailableStudyTimeRepository()
        } else {
            studyTimeRepository = SwiftDataStudyTimeRepository(modelContainer: modelContainer)
        }
        let studyTimeController = StudyTimeController(
            repository: studyTimeRepository,
            initialMessage: initialMessage
        )

        return AppDependencies(
            modelContainer: modelContainer,
            profileStore: profileStore,
            appearanceStore: appearanceStore,
            settingsStore: settingsStore,
            workspaceNavigationStore: workspaceNavigationStore,
            wordQuizSoundPlayer: wordQuizSoundPlayer,
            wordBookRepository: wordBookRepository,
            studyTimeController: studyTimeController,
            appUpdateController: appUpdateController
        )
    }

    private static func seedWordBookFixtures(
        in repository: any WordBookRepository
    ) throws {
        // 示例数据只服务 UI 自动化，不接触用户的正式持久化存储。
        let entries = [
            ("apple", "苹果"),
            ("banana", "香蕉"),
            ("language", "语言"),
            ("remember", "记住"),
            (
                "pneumonoultramicroscopicsilicovolcanoconiosis",
                "由超长词条触发的自动换行验证文本"
            )
        ]
        for (term, meaning) in entries {
            _ = try repository.addManualEntry(
                term: term,
                meaning: meaning,
                in: .english
            )
        }
    }

    private static func seedWordBookPaginationFixtures(
        in repository: any WordBookRepository
    ) throws {
        // 独立生成 21 条数据，覆盖分页边界且不影响其他 UI 测试夹具。
        for index in 1...21 {
            _ = try repository.addManualEntry(
                term: String(format: "pagination-word-%02d", index),
                meaning: "释义\(index)",
                in: .english
            )
        }
    }

    private static func seedWordQuizFixtures(
        in repository: any WordBookRepository
    ) throws {
        let firstDate = VocabularyDocumentDate(year: 2026, month: 8, day: 16)!
        let secondDate = VocabularyDocumentDate(year: 2026, month: 8, day: 17)!

        try importFixture(
            [
                ("apple", "苹果"),
                ("banana", "香蕉"),
                ("language", "语言"),
                ("remember", "记住"),
                ("study", "学习")
            ],
            date: firstDate,
            space: .english,
            repository: repository
        )
        try importFixture(
            [
                ("language", "语言"),
                ("time", "时间"),
                ("book", "书")
            ],
            date: secondDate,
            space: .english,
            repository: repository
        )
        try importFixture(
            [
                ("ことば", "语言"),
                ("勉強", "学习"),
                ("本", "书"),
                ("時間", "时间")
            ],
            date: firstDate,
            space: .japanese,
            repository: repository
        )
    }

    private static func importFixture(
        _ entries: [(term: String, meaning: String)],
        date: VocabularyDocumentDate,
        space: LanguageSpace,
        repository: any WordBookRepository
    ) throws {
        let words = entries.enumerated().map { index, entry in
            ParsedWord(
                term: entry.term,
                meaning: entry.meaning,
                lineNumber: index + 1
            )
        }
        _ = try repository.importDocument(
            ParsedWordDocument(sourceDate: date, words: words),
            into: space,
            sourceFilename: "word-quiz-\(space.rawValue)-\(date.storageKey).md",
            importedAt: .now
        )
    }
}

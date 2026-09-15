//
//  AppDependencies.swift
//  Egangnal
//

import Foundation
import OSLog
import SwiftData

@MainActor
struct AppDependencies {
    let modelContainer: ModelContainer
    let profileStore: ProfileStore
    let appearanceStore: AppearanceStore
    let settingsStore: AppSettingsStore
    let workspaceNavigationStore: WorkspaceNavigationStore
    let dashboardStore: DashboardStore
    let wordQuizSoundPlayer: any WordQuizSoundPlaying
    let wordBookRepository: any WordBookRepository
    let lexiconRepository: any LexiconRepository
    /// 洗牌状态必须活在应用级：每次进入页面都新建的话，冷却期就失去意义。
    /// 词库与单词本各自独立，互不影响对方的浏览顺序。
    let lexiconShuffleController: ShuffleSeedController
    let wordBookShuffleController: ShuffleSeedController
    let studyTimeController: StudyTimeController
    let appUpdateController: any AppUpdating
    /// 启动页的进入记录活在应用级：换页面重建视图不能让"当天首次"重新计数。
    let entryCeremonyStore: WorkspaceEntryCeremonyStore

    static func live() -> AppDependencies {
        let arguments = ProcessInfo.processInfo.arguments
        let isUITesting = arguments.contains("--ui-testing")
        let defaultAppearance: AppAppearance = if arguments.contains("--ui-testing-light-theme") {
            .light
        } else if arguments.contains("--ui-testing-warm-theme") {
            .warm
        } else {
            .dark
        }
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
            let repository = SwiftDataWordBookRepository(modelContainer: modelContainer)
            do {
                try repository.migrateLegacyEntrySourcesIfNeeded()
            } catch {
                // 回填失败不阻塞启动：`WordEntry.source` 会退回旧字段推断，语义仍然正确，
                // 只是每次启动重试一次。这里记录原因，不做静默忽略。
                Logger(subsystem: "com.ly.Egangnal", category: "WordBook").warning(
                    "词条来源回填失败，本次沿用旧字段推断：\(error.localizedDescription)"
                )
            }
            wordBookRepository = repository
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

        // 词库随 App 打包，不依赖 SwiftData；打开失败时保留原因并降级为明确失败实现，
        // 页面据此显示"资源缺失"或"版本不兼容"，不会伪装成空词库。
        let lexiconRepository: any LexiconRepository
        do {
            lexiconRepository = try SQLiteLexiconRepository.live()
        } catch let error as LexiconRepositoryError {
            lexiconRepository = UnavailableLexiconRepository(failure: error)
        } catch {
            lexiconRepository = UnavailableLexiconRepository(
                failure: .openFailed(error.localizedDescription)
            )
        }

        return AppDependencies(
            modelContainer: modelContainer,
            profileStore: profileStore,
            appearanceStore: appearanceStore,
            settingsStore: settingsStore,
            workspaceNavigationStore: workspaceNavigationStore,
            dashboardStore: DashboardStore(repository: wordBookRepository),
            wordQuizSoundPlayer: wordQuizSoundPlayer,
            wordBookRepository: wordBookRepository,
            lexiconRepository: lexiconRepository,
            lexiconShuffleController: ShuffleSeedController(),
            wordBookShuffleController: ShuffleSeedController(),
            studyTimeController: studyTimeController,
            appUpdateController: appUpdateController,
            entryCeremonyStore: WorkspaceEntryCeremonyStore()
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

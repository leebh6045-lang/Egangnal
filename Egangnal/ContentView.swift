//
//  ContentView.swift
//  Egangnal
//
//  Created by LBH on 2026/8/2.
//

import SwiftUI
import AppKit

struct ContentView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let appearanceStore: AppearanceStore
    let settingsStore: AppSettingsStore
    let workspaceNavigationStore: WorkspaceNavigationStore
    let dashboardStore: DashboardStore
    let wordQuizSoundPlayer: any WordQuizSoundPlaying
    let wordBookRepository: any WordBookRepository
    let lexiconRepository: any LexiconRepository
    let lexiconShuffleController: ShuffleSeedController
    let wordBookShuffleController: ShuffleSeedController
    let studyTimeController: StudyTimeController
    let appUpdateController: any AppUpdating
    let entryCeremonyStore: WorkspaceEntryCeremonyStore

    // UI 自动化可直接进入指定页面，正式启动始终从首页开始。
    @State private var route: AppRoute = Self.initialRoute
    // 每次从首页进入语言空间时递增，用于触发一次顶部栏新手提示。
    @State private var workspaceEntryRevealID = 0
    /// 本次进入语言空间要播的启动页；离开首页以外的路由变化不改变它。
    @State private var pendingEntryCeremony: WorkspaceEntryCeremonyStyle?

    private static var initialRoute: AppRoute {
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("--ui-testing-settings") {
            return .settings
        }
        if arguments.contains("--ui-testing-workspace-word-book") {
            return .workspace(.english, .wordBook)
        }
        if arguments.contains("--ui-testing-workspace-word-quiz") {
            return .workspace(.english, .wordQuiz)
        }
        if arguments.contains("--ui-testing-workspace-lexicon") {
            return .workspace(.english, .lexicon)
        }
        return .dashboard
    }

    var body: some View {
        ZStack {
            switch route {
            case .dashboard:
                DashboardView(
                    appearanceStore: appearanceStore,
                    dashboardStore: dashboardStore,
                    studyTimeController: studyTimeController,
                    openLanguage: openLanguage,
                    openSettings: openSettings
                )
                .transition(rootPageTransition)
            case .settings:
                SettingsView(
                    appearanceStore: appearanceStore,
                    settingsStore: settingsStore,
                    wordQuizSoundPlayer: wordQuizSoundPlayer,
                    appUpdateController: appUpdateController,
                    openDashboard: openDashboard
                )
                .transition(rootPageTransition)
            case let .workspace(space, feature):
                WorkspaceShell(
                    space: space,
                    selectedFeature: feature,
                    studyTimeController: studyTimeController,
                    selectFeature: { openWorkspace(space, $0) },
                    entryRevealID: workspaceEntryRevealID,
                    entryCeremony: pendingEntryCeremony
                ) { exitCoordinator in
                    workspaceContent(
                        space: space,
                        feature: feature,
                        exitCoordinator: exitCoordinator
                    )
                }
                .transition(workspaceEnterTransition)
            }
        }
        .animation(rootPageAnimation, value: route.rootPageIdentity)
        .focusedSceneValue(\.appRoute, $route)
        .environment(\.appPalette, appearanceStore.mode.palette)
        .environment(\.appPersonalization, settingsStore.personalization)
        // 仅改变 SwiftUI 内容树的配色，避免驱动 AppKit 窗口重新计算布局。
        .environment(\.colorScheme, appearanceStore.mode.colorScheme)
        .foregroundStyle(appearanceStore.mode.palette.primaryText)
        .tint(appearanceStore.mode.palette.calendarAccent)
        .onChange(of: route) { oldRoute, newRoute in
            if synchronizeStudyTime(from: oldRoute, to: newRoute),
               case let .workspace(space, feature) = newRoute {
                workspaceNavigationStore.setLastFeature(feature, for: space)
            }
        }
        .onAppear {
            studyTimeController.startCheckpointing()
            // 测试启动参数可能直接打开工作区，此时没有路由变化事件可触发计时。
            if let space = route.learningSpace {
                _ = studyTimeController.show(space)
            }
            if case let .workspace(space, feature) = route {
                workspaceNavigationStore.setLastFeature(feature, for: space)
            }
        }
        .onReceive(
            NotificationCenter.default.publisher(
                for: NSApplication.didBecomeActiveNotification
            )
        ) { _ in
            studyTimeController.applicationDidBecomeActive()
        }
        .onReceive(
            NotificationCenter.default.publisher(
                for: NSApplication.willResignActiveNotification
            )
        ) { _ in
            studyTimeController.applicationWillResignActive()
        }
        .onReceive(
            NSWorkspace.shared.notificationCenter.publisher(
                for: NSWorkspace.willSleepNotification
            )
        ) { _ in
            studyTimeController.systemWillSleep()
        }
        .onReceive(
            NSWorkspace.shared.notificationCenter.publisher(
                for: NSWorkspace.didWakeNotification
            )
        ) { _ in
            studyTimeController.systemDidWake()
        }
        .onReceive(
            NotificationCenter.default.publisher(
                for: NSApplication.willTerminateNotification
            )
        ) { _ in
            studyTimeController.applicationWillTerminate()
        }
        .background {
            WindowAppearanceConfigurator(appearance: appearanceStore.mode)
                .frame(width: 0, height: 0)
        }
    }

    private func openDashboard() {
        pendingEntryCeremony = nil
        route = .dashboard
    }

    private var rootPageTransition: AnyTransition {
        reduceMotion ? .identity : .opacity
    }

    /// 语言空间的常驻进入效果：从轻微模糊与放大中浮现；离开仍是淡出。
    private var workspaceEnterTransition: AnyTransition {
        guard !reduceMotion else { return .identity }
        // 播启动页时它本身就是转场，功能页直接就位在幕布底下；只有不播时才做浮现。
        guard pendingEntryCeremony == nil else {
            return .asymmetric(insertion: .identity, removal: .opacity)
        }
        return .asymmetric(
            insertion: .modifier(
                active: WorkspaceEnterModifier(isActive: true),
                identity: WorkspaceEnterModifier(isActive: false)
            ),
            removal: .opacity
        )
    }

    private var rootPageAnimation: Animation? {
        guard !reduceMotion else { return nil }
        // 进入语言空间用更长的浮现时长，其它根路由切换保持原有淡入淡出。
        if case .workspace = route {
            return .easeOut(duration: AppTheme.workspaceEnterDuration)
        }
        return .easeInOut(duration: AppTheme.pageFadeDuration)
    }

    private func openLanguage(_ space: LanguageSpace) {
        // 首页入口直接恢复该语言上次使用的功能，跳过旧的功能卡片中间页。
        workspaceEntryRevealID &+= 1
        let entry = settingsStore.workspaceEntry
        let plays = entryCeremonyStore.registerEntry(
            to: space,
            frequency: entry.ceremonyFrequency,
            reduceMotion: reduceMotion || Self.suppressesEntryCeremony
        )
        pendingEntryCeremony = plays ? entry.ceremonyStyle : nil
        route = .workspace(
            space,
            workspaceNavigationStore.lastFeature(for: space)
        )
    }

    /// UI 自动化默认不播启动页：既有用例进入功能页后立即断言，1 秒的覆盖层会让它们假失败。
    /// 专门验证启动页的用例再用 `--ui-testing-entry-ceremony` 打开。
    private static var suppressesEntryCeremony: Bool {
        let arguments = ProcessInfo.processInfo.arguments
        return arguments.contains("--ui-testing")
            && !arguments.contains("--ui-testing-entry-ceremony")
    }

    private func openSettings() {
        route = .settings
    }

    private func openWorkspace(
        _ space: LanguageSpace,
        _ feature: WorkspaceFeature
    ) {
        route = .workspace(space, feature)
    }

    @ViewBuilder
    private func workspaceContent(
        space: LanguageSpace,
        feature: WorkspaceFeature,
        exitCoordinator: WorkspaceExitCoordinator
    ) -> some View {
        switch feature {
        case .wordBook:
            WordBookView(
                space: space,
                repository: wordBookRepository,
                settingsStore: settingsStore,
                shuffle: wordBookShuffleController,
                openWorkspace: openDashboard
            )
        case .wordQuiz:
            WordQuizView(
                space: space,
                candidateSource: WordQuizCandidateSource(
                    repository: wordBookRepository
                ),
                lexiconCandidateSource: LexiconQuizCandidateSource(
                    lexiconRepository: lexiconRepository
                ),
                settingsStore: settingsStore,
                soundPlayer: wordQuizSoundPlayer,
                openWorkspace: openDashboard,
                exitCoordinator: exitCoordinator
            )
        case .lexicon:
            // 词库目前只有英语数据；日语空间继续显示占位，避免出现一个空词库。
            if space == .english {
                LexiconView(
                    space: space,
                    repository: lexiconRepository,
                    wordBookRepository: wordBookRepository,
                    shuffle: lexiconShuffleController,
                    openDashboard: openDashboard
                )
            } else {
                WorkspaceLexiconPlaceholder(openDashboard: openDashboard)
            }
        }
    }

    @discardableResult
    private func synchronizeStudyTime(
        from oldRoute: AppRoute,
        to newRoute: AppRoute
    ) -> Bool {
        let succeeded: Bool
        if let space = newRoute.learningSpace {
            succeeded = studyTimeController.show(space)
        } else {
            _ = studyTimeController.leaveSpace()
            succeeded = true
        }

        guard !succeeded else { return true }
        // 保存失败时拒绝跨语言路由，避免界面和计时归属分裂。
        if route == newRoute {
            route = oldRoute
        }
        return false
    }
}

#Preview {
    ContentView(
        appearanceStore: .preview,
        settingsStore: .preview,
        workspaceNavigationStore: .preview,
        dashboardStore: .preview,
        wordQuizSoundPlayer: SilentWordQuizSoundPlayer(),
        wordBookRepository: PreviewWordBookRepository(),
        lexiconRepository: PreviewLexiconRepository(),
        lexiconShuffleController: ShuffleSeedController(),
        wordBookShuffleController: ShuffleSeedController(),
        studyTimeController: .preview,
        appUpdateController: DisabledAppUpdateController(),
        entryCeremonyStore: WorkspaceEntryCeremonyStore()
    )
        .frame(width: 1080, height: 700)
}

/// 功能页浮现时的起始状态：略微放大并带一点模糊，落定后清晰。
private struct WorkspaceEnterModifier: ViewModifier {
    let isActive: Bool

    func body(content: Content) -> some View {
        content
            .opacity(isActive ? 0 : 1)
            .scaleEffect(isActive ? AppTheme.workspaceEnterScale : 1)
            .blur(radius: isActive ? AppTheme.workspaceEnterBlur : 0)
    }
}

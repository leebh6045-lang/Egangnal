//
//  EgangnalApp.swift
//  Egangnal
//
//  Created by LBH on 2026/8/2.
//

import SwiftUI
import SwiftData
import AppKit

@main
struct EgangnalApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    private let dependencies = AppDependencies.live()

    private var minimumContentHeight: CGFloat {
        // 紧凑 UI 测试按窗口外框验收，正式应用仍保留原有最小内容高度。
        ProcessInfo.processInfo.arguments.contains("--ui-testing-compact-window")
            ? 0
            : 560
    }

    var body: some Scene {
        Window("Egangnal", id: "main") {
            ContentView(
                appearanceStore: dependencies.appearanceStore,
                settingsStore: dependencies.settingsStore,
                workspaceNavigationStore: dependencies.workspaceNavigationStore,
                dashboardStore: dependencies.dashboardStore,
                wordQuizSoundPlayer: dependencies.wordQuizSoundPlayer,
                wordBookRepository: dependencies.wordBookRepository,
                lexiconRepository: dependencies.lexiconRepository,
                lexiconShuffleController: dependencies.lexiconShuffleController,
                wordBookShuffleController: dependencies.wordBookShuffleController,
                studyTimeController: dependencies.studyTimeController,
                appUpdateController: dependencies.appUpdateController
            )
                .frame(minWidth: 820, minHeight: minimumContentHeight)
                .modelContainer(dependencies.modelContainer)
        }
        .defaultSize(width: 1080, height: 700)
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentMinSize)
        .commands {
            AppCommands()
        }
    }
}

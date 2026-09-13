//
//  AppCommands.swift
//  Egangnal
//

import SwiftUI

struct AppCommands: Commands {
    @FocusedBinding(\.appRoute) private var route

    var body: some Commands {
        CommandMenu("学习空间") {
            Button("总览") {
                route = .dashboard
            }
            .disabled(route == nil || route?.isWordQuiz == true)

            Divider()

            Button("单词本") {
                requestFeature(.wordBook)
            }
            .keyboardShortcut("1", modifiers: .command)
            .disabled(!isWorkspace)
            Button("单词刷") {
                requestFeature(.wordQuiz)
            }
            .keyboardShortcut("2", modifiers: .command)
            .disabled(!isWorkspace)

            Button("学习资料") {
                requestFeature(.lexicon)
            }
            .keyboardShortcut("3", modifiers: .command)
            .disabled(!isWorkspace)
        }
    }

    private var isWorkspace: Bool {
        guard let route else { return false }
        guard case .workspace = route else { return false }
        return true
    }

    private func requestFeature(_ feature: WorkspaceFeature) {
        guard let route, case let .workspace(space, _) = route else { return }
        NotificationCenter.default.post(
            name: .workspaceFeatureNavigationRequested,
            object: WorkspaceFeatureNavigationRequest(
                space: space,
                feature: feature
            )
        )
    }
}

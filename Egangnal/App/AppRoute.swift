//
//  AppRoute.swift
//  Egangnal
//

import SwiftUI

enum AppRootPageIdentity: Hashable {
    case dashboard
    case settings
    case workspace(LanguageSpace)
}

enum AppRoute: Hashable {
    case dashboard
    case settings
    case workspace(LanguageSpace, WorkspaceFeature)

    var accessibilityIdentifier: String {
        switch self {
        case .dashboard:
            "route.dashboard"
        case .settings:
            "route.settings"
        case let .workspace(space, feature):
            "route.workspace.\(space.rawValue).\(feature.rawValue)"
        }
    }

    /// 统一描述当前页面所属的语言空间，供计时与路由测试复用。
    var learningSpace: LanguageSpace? {
        switch self {
        case .dashboard, .settings:
            nil
        case let .workspace(space, _):
            space
        }
    }

    var isWordQuiz: Bool {
        switch self {
        case .workspace(_, .wordQuiz):
            true
        default:
            false
        }
    }

    /// 根页面转场忽略工作区功能，避免顶部栏随功能内容一起淡出。
    var rootPageIdentity: AppRootPageIdentity {
        switch self {
        case .dashboard:
            .dashboard
        case .settings:
            .settings
        case let .workspace(space, _):
            .workspace(space)
        }
    }
}

private struct AppRouteKey: FocusedValueKey {
    typealias Value = Binding<AppRoute>
}

extension FocusedValues {
    var appRoute: Binding<AppRoute>? {
        get { self[AppRouteKey.self] }
        set { self[AppRouteKey.self] = newValue }
    }
}

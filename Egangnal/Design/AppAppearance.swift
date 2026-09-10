//
//  AppAppearance.swift
//  Egangnal
//

import SwiftUI

enum AppAppearance: String, CaseIterable {
    case light
    case dark

    var colorScheme: ColorScheme {
        switch self {
        case .light:
            .light
        case .dark:
            .dark
        }
    }

    var title: String {
        switch self {
        case .light:
            "浅色主题"
        case .dark:
            "深色主题"
        }
    }

    var toggled: AppAppearance {
        switch self {
        case .light:
            .dark
        case .dark:
            .light
        }
    }
}

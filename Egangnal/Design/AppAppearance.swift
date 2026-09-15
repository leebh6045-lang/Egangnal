//
//  AppAppearance.swift
//  Egangnal
//

import SwiftUI

enum AppAppearance: String, CaseIterable, Identifiable {
    case light
    /// 暖纸：略暖的浅色底，配合"纸和本子"的比喻。
    case warm
    /// 石墨风格的深色主题。原始值保持 `dark`，已保存的偏好无需迁移。
    case dark

    var id: Self { self }

    var colorScheme: ColorScheme {
        switch self {
        case .light, .warm:
            .light
        case .dark:
            .dark
        }
    }

    var title: String {
        switch self {
        case .light:
            "浅色主题"
        case .warm:
            "暖纸主题"
        case .dark:
            "深色主题"
        }
    }

    /// 首页主题按钮的循环顺序：浅色 → 暖纸 → 深色 → 浅色。
    var next: AppAppearance {
        switch self {
        case .light:
            .warm
        case .warm:
            .dark
        case .dark:
            .light
        }
    }
}

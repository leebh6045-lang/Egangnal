//
//  AppearanceStore.swift
//  Egangnal
//

import Foundation
import Observation

protocol AppearancePreferences: AnyObject {
    func string(forKey defaultName: String) -> String?
    func set(_ value: Any?, forKey defaultName: String)
}

extension UserDefaults: AppearancePreferences {}

@MainActor
@Observable
final class AppearanceStore {
    static let storageKey = "appAppearance"

    private let preferences: AppearancePreferences?
    private(set) var mode: AppAppearance

    init(
        preferences: AppearancePreferences? = UserDefaults.standard,
        defaultMode: AppAppearance = .dark
    ) {
        self.preferences = preferences

        if let storedValue = preferences?.string(forKey: Self.storageKey),
           let storedMode = AppAppearance(rawValue: storedValue) {
            mode = storedMode
        } else {
            mode = defaultMode
        }
    }

    /// 首页按钮：按固定顺序切到下一套主题。
    func cycle() {
        select(mode.next)
    }

    /// 设置页：直接选定某一套主题。
    func select(_ newMode: AppAppearance) {
        mode = newMode
        preferences?.set(newMode.rawValue, forKey: Self.storageKey)
    }
}

extension AppearanceStore {
    static var preview: AppearanceStore {
        AppearanceStore(preferences: nil, defaultMode: .dark)
    }
}

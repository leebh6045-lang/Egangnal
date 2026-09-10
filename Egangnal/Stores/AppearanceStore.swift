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

    func toggle() {
        mode = mode.toggled
        preferences?.set(mode.rawValue, forKey: Self.storageKey)
    }
}

extension AppearanceStore {
    static var preview: AppearanceStore {
        AppearanceStore(preferences: nil, defaultMode: .dark)
    }
}

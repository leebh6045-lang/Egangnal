//
//  PreferencesTestSupport.swift
//  EgangnalTests
//

import Foundation
@testable import Egangnal

/// 主题偏好的内存替身：只记录字符串，不触碰真实 UserDefaults。
final class TestAppearancePreferences: AppearancePreferences {
    private(set) var values: [String: String]

    init(values: [String: String] = [:]) {
        self.values = values
    }

    func string(forKey defaultName: String) -> String? {
        values[defaultName]
    }

    func set(_ value: Any?, forKey defaultName: String) {
        values[defaultName] = value as? String
    }
}

/// 设置偏好的内存替身。
final class TestAppSettingsPreferences: AppSettingsPreferences {
    private var values: [String: Any] = [:]

    func object(forKey defaultName: String) -> Any? {
        values[defaultName]
    }

    func data(forKey defaultName: String) -> Data? {
        values[defaultName] as? Data
    }

    func string(forKey defaultName: String) -> String? {
        values[defaultName] as? String
    }

    func set(_ value: Any?, forKey defaultName: String) {
        values[defaultName] = value
    }

    func removeObject(forKey defaultName: String) {
        values.removeValue(forKey: defaultName)
    }
}

//
//  WorkspaceNavigationStore.swift
//  Egangnal
//

import Foundation
import Observation

protocol WorkspaceNavigationPreferences: AnyObject {
    func string(forKey defaultName: String) -> String?
    func set(_ value: Any?, forKey defaultName: String)
}

extension UserDefaults: WorkspaceNavigationPreferences {}

@MainActor
@Observable
final class WorkspaceNavigationStore {
    enum StorageKey {
        static func lastFeature(for space: LanguageSpace) -> String {
            "workspace.lastFeature.\(space.rawValue)"
        }
    }

    private let preferences: (any WorkspaceNavigationPreferences)?
    private var lastFeatures: [LanguageSpace: WorkspaceFeature]

    init(
        preferences: (any WorkspaceNavigationPreferences)? = UserDefaults.standard
    ) {
        self.preferences = preferences
        lastFeatures = Dictionary(uniqueKeysWithValues: LanguageSpace.allCases.map { space in
            let storedValue = preferences?.string(
                forKey: StorageKey.lastFeature(for: space)
            )
            // 首次启动或遇到已失效的存量值时，稳定回退到单词本。
            let feature = storedValue.flatMap(WorkspaceFeature.init(rawValue:))
                ?? .wordBook
            return (space, feature)
        })
    }

    func lastFeature(for space: LanguageSpace) -> WorkspaceFeature {
        lastFeatures[space] ?? .wordBook
    }

    func setLastFeature(_ feature: WorkspaceFeature, for space: LanguageSpace) {
        guard lastFeatures[space] != feature else { return }
        lastFeatures[space] = feature
        preferences?.set(
            feature.rawValue,
            forKey: StorageKey.lastFeature(for: space)
        )
    }
}

extension WorkspaceNavigationStore {
    static var preview: WorkspaceNavigationStore {
        WorkspaceNavigationStore(preferences: nil)
    }
}

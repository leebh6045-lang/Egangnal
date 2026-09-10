//
//  AppPersonalization.swift
//  Egangnal
//

import SwiftUI

struct AppPersonalization: Equatable, Sendable {
    let showsLanguageCardArtwork: Bool
    let showsGridBackground: Bool

    static let enabled = AppPersonalization(
        showsLanguageCardArtwork: true,
        showsGridBackground: true
    )
}

private struct AppPersonalizationKey: EnvironmentKey {
    static let defaultValue = AppPersonalization.enabled
}

extension EnvironmentValues {
    var appPersonalization: AppPersonalization {
        get { self[AppPersonalizationKey.self] }
        set { self[AppPersonalizationKey.self] = newValue }
    }
}

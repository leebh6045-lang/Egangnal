//
//  UserProfile.swift
//  Egangnal
//

import Foundation
import SwiftData

@Model
final class UserProfile {
    static let primaryIdentifier = "primary"

    @Attribute(.unique) var identifier: String
    var nickname: String
    var updatedAt: Date

    init(
        identifier: String = UserProfile.primaryIdentifier,
        nickname: String,
        updatedAt: Date = .now
    ) {
        self.identifier = identifier
        self.nickname = nickname
        self.updatedAt = updatedAt
    }
}

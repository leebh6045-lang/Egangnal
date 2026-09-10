//
//  ProfileRepository.swift
//  Egangnal
//

import Foundation
import SwiftData

@MainActor
protocol ProfileRepository: AnyObject {
    func loadNickname() throws -> String?
    func saveNickname(_ nickname: String) throws
}

@MainActor
final class SwiftDataProfileRepository: ProfileRepository {
    private let modelContext: ModelContext

    init(modelContainer: ModelContainer) {
        modelContext = ModelContext(modelContainer)
        modelContext.autosaveEnabled = false
    }

    func loadNickname() throws -> String? {
        try primaryProfile()?.nickname
    }

    func saveNickname(_ nickname: String) throws {
        do {
            let profile: UserProfile

            if let existingProfile = try primaryProfile() {
                profile = existingProfile
            } else {
                profile = UserProfile(nickname: nickname)
                modelContext.insert(profile)
            }

            profile.nickname = nickname
            profile.updatedAt = .now
            try modelContext.save()
        } catch {
            // 保存失败时丢弃上下文中的脏状态，避免失败值被后续操作意外提交。
            modelContext.rollback()
            throw error
        }
    }

    private func primaryProfile() throws -> UserProfile? {
        let primaryIdentifier = UserProfile.primaryIdentifier
        var descriptor = FetchDescriptor<UserProfile>(
            predicate: #Predicate { profile in
                profile.identifier == primaryIdentifier
            }
        )
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }
}

@MainActor
final class PreviewProfileRepository: ProfileRepository {
    private var nickname: String?

    init(nickname: String? = nil) {
        self.nickname = nickname
    }

    func loadNickname() throws -> String? {
        nickname
    }

    func saveNickname(_ nickname: String) throws {
        self.nickname = nickname
    }
}

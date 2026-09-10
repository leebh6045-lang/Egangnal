//
//  ProfileStore.swift
//  Egangnal
//

import Foundation
import Observation

@MainActor
@Observable
final class ProfileStore {
    static let defaultNickname = "学习者"
    static let maximumNicknameLength = 24

    private let repository: ProfileRepository

    private(set) var nickname: String
    private(set) var message: String?
    private(set) var persistenceWarning: String?

    init(
        repository: ProfileRepository,
        initialMessage: String? = nil
    ) {
        self.repository = repository
        nickname = Self.defaultNickname
        message = nil
        persistenceWarning = initialMessage

        do {
            if let storedNickname = try repository.loadNickname() {
                nickname = storedNickname
            }
        } catch {
            persistenceWarning = "昵称读取失败，本次将使用默认昵称。"
        }
    }

    @discardableResult
    func saveNickname(_ input: String) -> Bool {
        let normalizedNickname = input.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !normalizedNickname.isEmpty else {
            message = "昵称不能为空。"
            return false
        }

        guard normalizedNickname.count <= Self.maximumNicknameLength else {
            message = "昵称不能超过 \(Self.maximumNicknameLength) 个字符。"
            return false
        }

        do {
            try repository.saveNickname(normalizedNickname)
            nickname = normalizedNickname
            message = nil
            return true
        } catch {
            message = "昵称保存失败，请稍后再试。"
            return false
        }
    }

    func clearMessage() {
        message = nil
    }
}

extension ProfileStore {
    static var preview: ProfileStore {
        ProfileStore(repository: PreviewProfileRepository(nickname: "学习者"))
    }
}

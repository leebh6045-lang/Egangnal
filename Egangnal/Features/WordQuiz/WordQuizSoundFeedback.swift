//
//  WordQuizSoundFeedback.swift
//  Egangnal
//

import AVFoundation
import Foundation
import OSLog

extension WordQuizSoundEffect {
    var title: String {
        switch self {
        case .off:
            "关闭"
        case .sound1:
            "音效 1"
        case .sound2:
            "音效 2"
        }
    }

    var resource: WordQuizSoundResource? {
        switch self {
        case .off:
            nil
        case .sound1:
            WordQuizSoundResource(name: "WordQuizClick1", fileExtension: "wav")
        case .sound2:
            WordQuizSoundResource(name: "WordQuizClick2", fileExtension: "mp3")
        }
    }
}

struct WordQuizSoundResource: Equatable, Sendable {
    let name: String
    let fileExtension: String
}

@MainActor
protocol WordQuizSoundPlaying: AnyObject {
    func play(_ effect: WordQuizSoundEffect)
}

@MainActor
final class AVAudioWordQuizSoundPlayer: WordQuizSoundPlaying {
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "Egangnal",
        category: "WordQuizAudio"
    )
    private var players: [WordQuizSoundEffect: AVAudioPlayer] = [:]

    init(bundle: Bundle = .main) {
        for effect in WordQuizSoundEffect.allCases where effect != .off {
            guard let resource = effect.resource,
                  let url = Self.resourceURL(for: resource, in: bundle) else {
                logger.error("单词刷音效资源缺失：\(effect.rawValue, privacy: .public)")
                continue
            }

            do {
                let player = try AVAudioPlayer(contentsOf: url)
                player.prepareToPlay()
                players[effect] = player
            } catch {
                logger.error(
                    "单词刷音效无法解码：\(effect.rawValue, privacy: .public)"
                )
            }
        }
    }

    func play(_ effect: WordQuizSoundEffect) {
        guard effect != .off, let player = players[effect] else { return }
        player.stop()
        player.currentTime = 0
        _ = player.play()
    }

    func isAvailable(_ effect: WordQuizSoundEffect) -> Bool {
        effect == .off || players[effect] != nil
    }

    static func resourceURL(
        for resource: WordQuizSoundResource,
        in bundle: Bundle
    ) -> URL? {
        bundle.url(
            forResource: resource.name,
            withExtension: resource.fileExtension,
            subdirectory: "Audio"
        ) ?? bundle.url(
            forResource: resource.name,
            withExtension: resource.fileExtension
        )
    }
}

@MainActor
final class SilentWordQuizSoundPlayer: WordQuizSoundPlaying {
    func play(_ effect: WordQuizSoundEffect) {}
}

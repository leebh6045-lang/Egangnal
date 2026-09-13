//
//  ShuffleSeedController.swift
//  Egangnal
//

import Foundation

/// 浏览顺序的洗牌控制，词库与单词本各持有一个实例。
///
/// 目的：避免"每次打开都从同一批内容开始"造成的枯燥感，同时不能一离开就换，
/// 否则用户切到别的页面再回来，刚才看的内容就找不到了。
/// 因此采用**单条时间规则 + 手动按钮**：距上次洗牌超过冷却期才自动换一批。
@MainActor
final class ShuffleSeedController {
    /// 冷却期。低于这个间隔再次进入词库保持原顺序。
    static let cooldown: TimeInterval = 15 * 60

    private(set) var seed: Int
    private var lastShuffledAt: Date
    private let now: () -> Date
    private let makeSeed: () -> Int

    init(
        now: @escaping () -> Date = { .now },
        makeSeed: @escaping () -> Int = { Int.random(in: 1...1_000_000) }
    ) {
        self.now = now
        self.makeSeed = makeSeed
        self.seed = makeSeed()
        lastShuffledAt = now()
    }

    /// 进入词库时取当前种子；超过冷却期则先换一批。
    /// 进入页面时取当前种子；超过冷却期则先换一批。
    func seedForEntry() -> Int {
        if now().timeIntervalSince(lastShuffledAt) >= Self.cooldown {
            reshuffle()
        }
        return seed
    }

    /// 手动换一批。
    func reshuffle() {
        seed = makeSeed()
        lastShuffledAt = now()
    }
}

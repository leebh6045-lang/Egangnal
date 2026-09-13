//
//  ShuffleSeedControllerTests.swift
//  EgangnalTests
//

import Foundation
import Testing
@testable import Egangnal

/// 洗牌刷新策略：冷却期内保持顺序，超过冷却期才换一批，并且随时可以手动换。
@MainActor
struct ShuffleSeedControllerTests {
    @Test @MainActor
    func keepsTheSameSeedWithinTheCooldownWindow() {
        var current = Date(timeIntervalSince1970: 1_000_000)
        var issued = 0
        let controller = ShuffleSeedController(
            now: { current },
            makeSeed: { issued += 1; return issued }
        )

        let first = controller.seedForEntry()
        // 冷却期内反复进入词库，顺序必须保持不变，否则用户会“丢失刚才看的词”。
        current = current.addingTimeInterval(60)
        #expect(controller.seedForEntry() == first)
        current = current.addingTimeInterval(ShuffleSeedController.cooldown - 61)
        #expect(controller.seedForEntry() == first)
    }

    @Test @MainActor
    func reshufflesAfterTheCooldownWindow() {
        var current = Date(timeIntervalSince1970: 1_000_000)
        var issued = 0
        let controller = ShuffleSeedController(
            now: { current },
            makeSeed: { issued += 1; return issued }
        )

        let first = controller.seedForEntry()
        current = current.addingTimeInterval(ShuffleSeedController.cooldown + 1)

        #expect(controller.seedForEntry() != first)
    }

    @Test @MainActor
    func manualReshuffleChangesTheSeedAndRestartsTheCooldown() {
        var current = Date(timeIntervalSince1970: 1_000_000)
        var issued = 0
        let controller = ShuffleSeedController(
            now: { current },
            makeSeed: { issued += 1; return issued }
        )

        let first = controller.seedForEntry()
        controller.reshuffle()
        let second = controller.seed
        #expect(second != first)

        // 手动换过之后冷却期重新计时。
        current = current.addingTimeInterval(ShuffleSeedController.cooldown - 1)
        #expect(controller.seedForEntry() == second)
    }

    @Test @MainActor
    func cooldownIsFifteenMinutes() {
        #expect(ShuffleSeedController.cooldown == 15 * 60)
    }
}

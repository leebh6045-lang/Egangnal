//
//  AppUpdateController.swift
//  Egangnal
//

import Foundation
import Observation

#if canImport(Sparkle)
import Sparkle
#endif

/// 设置页只依赖这组能力，避免页面直接绑定 Sparkle 的实现细节。
@MainActor
protocol AppUpdating: AnyObject {
    var isConfigured: Bool { get }
    var canCheckForUpdates: Bool { get }
    func checkForUpdates()
}

@MainActor
@Observable
final class AppUpdateController: AppUpdating {
    @ObservationIgnored private let feedURL: URL?

    // Sparkle 在启动和更新过程中会异步改变该状态，设置页需要随之刷新。
    private(set) var canCheckForUpdatesState = false

#if canImport(Sparkle)
    @ObservationIgnored private let updaterController: SPUStandardUpdaterController?
    @ObservationIgnored private var canCheckObservation: NSKeyValueObservation?
#endif

    init(bundle: Bundle = .main) {
        let feedURL = Self.feedURL(from: bundle)
        self.feedURL = feedURL

#if canImport(Sparkle)
        // 开发阶段没有更新源或公钥时不启动 Sparkle，避免弹出错误配置提示。
        let publicKey = bundle.object(forInfoDictionaryKey: "SUPublicEDKey") as? String
        guard feedURL != nil, Self.hasText(publicKey) else {
            updaterController = nil
            return
        }

        let controller = SPUStandardUpdaterController(
            startingUpdater: false,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
        updaterController = controller
        canCheckObservation = controller.updater.observe(
            \SPUUpdater.canCheckForUpdates,
            options: [.initial, .new]
        ) { [weak self] _, change in
            guard let value = change.newValue else { return }
            Task { @MainActor [weak self] in
                self?.canCheckForUpdatesState = value
            }
        }
        controller.startUpdater()
#endif
    }

    var isConfigured: Bool {
#if canImport(Sparkle)
        updaterController != nil && feedURL != nil
#else
        false
#endif
    }

    var canCheckForUpdates: Bool {
#if canImport(Sparkle)
        canCheckForUpdatesState
#else
        false
#endif
    }

    func checkForUpdates() {
#if canImport(Sparkle)
        guard let updaterController, updaterController.updater.canCheckForUpdates else {
            return
        }
        updaterController.checkForUpdates(nil)
#endif
    }

    private static func feedURL(from bundle: Bundle) -> URL? {
        guard
            let value = bundle.object(forInfoDictionaryKey: "SUFeedURL") as? String,
            let url = URL(string: value),
            url.scheme?.lowercased() == "https",
            !url.absoluteString.isEmpty
        else {
            return nil
        }
        return url
    }

    private static func hasText(_ value: String?) -> Bool {
        guard let value else { return false }
        return !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

/// 预览和 UI 测试使用的无网络实现，保证测试不会依赖远程更新源。
@MainActor
final class DisabledAppUpdateController: AppUpdating {
    let isConfigured = false
    let canCheckForUpdates = false

    func checkForUpdates() {}
}

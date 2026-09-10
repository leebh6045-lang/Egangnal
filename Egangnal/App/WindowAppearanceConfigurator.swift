//
//  WindowAppearanceConfigurator.swift
//  Egangnal
//

import AppKit
import SwiftUI

struct WindowAppearanceConfigurator: NSViewRepresentable {
    let appearance: AppAppearance

    func makeNSView(context: Context) -> WindowConfigurationView {
        WindowConfigurationView(appearance: appearance)
    }

    func updateNSView(_ nsView: WindowConfigurationView, context: Context) {
        nsView.updateAppearance(appearance)
    }
}

final class WindowConfigurationView: NSView {
    private var appAppearance: AppAppearance
    private var didPrepareTestingWindow = false
    private weak var configuredWindow: NSWindow?

    init(appearance: AppAppearance) {
        appAppearance = appearance
        super.init(frame: .zero)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("不支持通过 NSCoder 创建窗口配置视图。")
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        configureWindowIfNeeded()
    }

    func updateAppearance(_ appearance: AppAppearance) {
        appAppearance = appearance
        // 主题变化只更新 SwiftUI 调色板，避免 AppKit 重新计算内容区布局。
        configureWindowIfNeeded()
    }

    private func configureWindowIfNeeded() {
        guard let window else { return }
        guard configuredWindow !== window else { return }

        configuredWindow = window

        // 标题栏只保留窗口控制按钮，背景和内容区保持连续。
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.titlebarSeparatorStyle = .none
        window.styleMask.insert(.fullSizeContentView)
        window.isMovableByWindowBackground = true
        window.appearance = NSAppearance(
            named: appAppearance == .dark ? .darkAqua : .aqua
        )

        configureWindowButtonIdentifiers(in: window)
        prepareTestingWindowIfNeeded(window)
    }

    private func configureWindowButtonIdentifiers(in window: NSWindow) {
        window.standardWindowButton(.closeButton)?
            .setAccessibilityIdentifier("window.close")
        window.standardWindowButton(.miniaturizeButton)?
            .setAccessibilityIdentifier("window.minimize")
        window.standardWindowButton(.zoomButton)?
            .setAccessibilityIdentifier("window.zoom")
    }

    private func prepareTestingWindowIfNeeded(_ window: NSWindow) {
        guard ProcessInfo.processInfo.arguments.contains("--ui-testing"),
              !didPrepareTestingWindow else {
            return
        }

        let usesCompactSize = ProcessInfo.processInfo.arguments.contains(
            "--ui-testing-compact-window"
        )
        didPrepareTestingWindow = true

        Task { @MainActor [weak window] in
            guard let window else { return }
            window.setFrameAutosaveName("")

            // SwiftUI 可能在视图挂载后再次恢复旧窗口尺寸，因此延迟后再确认一次。
            applyTestingFrame(to: window, usesCompactSize: usesCompactSize)
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            applyTestingFrame(to: window, usesCompactSize: usesCompactSize)
        }
    }

    @MainActor
    private func applyTestingFrame(to window: NSWindow, usesCompactSize: Bool) {
        let targetFrameSize = NSSize(
            width: usesCompactSize ? 820 : 1080,
            height: usesCompactSize ? 560 : 700
        )
        window.collectionBehavior.insert(.moveToActiveSpace)
        // UI 测试按窗口外框验收，避免标题栏高度被重复计入。
        window.setFrame(
            NSRect(origin: window.frame.origin, size: targetFrameSize),
            display: true
        )
        window.center()
        window.deminiaturize(nil)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

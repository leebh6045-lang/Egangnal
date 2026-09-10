//
//  AppDelegate.swift
//  Egangnal
//

import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // 首版只有一个主窗口，关闭窗口即结束本次使用。
        true
    }
}

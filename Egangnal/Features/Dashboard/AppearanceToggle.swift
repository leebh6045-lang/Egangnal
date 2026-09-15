//
//  AppearanceToggle.swift
//  Egangnal
//

import SwiftUI

struct AppearanceToggle: View {
    @Environment(\.appPalette) private var palette

    let appearanceStore: AppearanceStore
    let isEnabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: targetSystemImage)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(palette.calendarAccent)
                .frame(width: AppTheme.toggleSize, height: AppTheme.toggleSize)
                .background(palette.panel, in: .rect(cornerRadius: 8))
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(palette.border, lineWidth: 1)
                }
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .help("切换到\(appearanceStore.mode.next.title)")
        .accessibilityLabel("切换主题")
        .accessibilityValue(appearanceStore.mode.title)
        .accessibilityHint("切换到\(appearanceStore.mode.next.title)")
        .accessibilityIdentifier("dashboard.appearanceToggle")
    }

    /// 图标表达"将要切换到"的主题，而不是当前主题。
    private var targetSystemImage: String {
        switch appearanceStore.mode.next {
        case .light:
            "sun.max.fill"
        case .warm:
            "book.closed.fill"
        case .dark:
            "moon.fill"
        }
    }
}

#Preview {
    AppearanceToggle(appearanceStore: .preview, isEnabled: true) {}
        .environment(\.appPalette, AppAppearance.dark.palette)
        .padding()
}

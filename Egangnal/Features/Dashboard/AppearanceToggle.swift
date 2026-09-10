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
        .help("切换到\(appearanceStore.mode.toggled.title)")
        .accessibilityLabel("切换主题")
        .accessibilityValue(appearanceStore.mode.title)
        .accessibilityHint("切换到\(appearanceStore.mode.toggled.title)")
        .accessibilityIdentifier("dashboard.appearanceToggle")
    }

    private var targetSystemImage: String {
        appearanceStore.mode == .dark ? "sun.max.fill" : "moon.fill"
    }
}

#Preview {
    AppearanceToggle(appearanceStore: .preview, isEnabled: true) {}
        .environment(\.appPalette, AppAppearance.dark.palette)
        .padding()
}

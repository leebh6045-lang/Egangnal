//
//  LanguageLauncher.swift
//  Egangnal
//

import SwiftUI

struct LanguageLauncher: View {
    @Environment(\.appPalette) private var palette
    @Environment(\.appPersonalization) private var personalization

    @State private var hoveredSpace: LanguageSpace?

    let availableWidth: CGFloat
    let openLanguage: (LanguageSpace) -> Void

    var body: some View {
        HStack(alignment: .top, spacing: AppTheme.panelSpacing) {
            ForEach(orderedSpaces) { space in
                languageButton(for: space)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("dashboard.languageLauncher")
    }

    private func languageButton(for space: LanguageSpace) -> some View {
        Button {
            openLanguage(space)
        } label: {
            languageCard(for: space)
        }
        .buttonStyle(.plain)
        .onHover { isHovering in
            hoveredSpace = isHovering ? space : nil
        }
        .animation(.easeOut(duration: 0.14), value: hoveredSpace)
        .help("进入\(space.title)学习空间")
        .accessibilityIdentifier("dashboard.open.\(space.rawValue)")
    }

    private func languageCard(for space: LanguageSpace) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Spacer(minLength: 0)

            VStack(alignment: .leading, spacing: 4) {
                Text(space.title)
                    .font(.system(size: 31, weight: .semibold))
                    .foregroundStyle(palette.primaryText)
                Text(space.nativeTitle)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(palette.secondaryText)
            }
        }
        .contentShape(.rect)
        .padding(18)
        .frame(
            width: cardWidth,
            height: AppTheme.launcherCardHeight,
            alignment: .topLeading
        )
        .background {
            LanguageCardBackground(
                space: space,
                showsArtwork: personalization.showsLanguageCardArtwork,
                isHovered: hoveredSpace == space
            )
        }
        .clipShape(.rect(cornerRadius: AppTheme.panelCornerRadius))
        .overlay {
            RoundedRectangle(cornerRadius: AppTheme.panelCornerRadius)
                .stroke(
                    hoveredSpace == space
                        ? palette.accent(for: space)
                        : palette.border,
                    lineWidth: 1
                )
        }
        .shadow(color: palette.panelShadow, radius: 12, y: 5)
    }

    private var cardWidth: CGFloat {
        let totalSpacing = AppTheme.panelSpacing
            * CGFloat(max(orderedSpaces.count - 1, 0))
        let proposedWidth = (availableWidth - totalSpacing)
            / CGFloat(orderedSpaces.count)
        return min(max(proposedWidth, 190), AppTheme.launcherCardMaxWidth)
    }

    // 首页按使用习惯展示英语在左、日语在右，不改变全局语言枚举顺序。
    private var orderedSpaces: [LanguageSpace] {
        [.english, .japanese]
    }
}

private struct LanguageCardBackground: View {
    @Environment(\.appPalette) private var palette

    let space: LanguageSpace
    let showsArtwork: Bool
    let isHovered: Bool

    var body: some View {
        ZStack {
            isHovered ? palette.panelRaised : palette.panel

            if showsArtwork {
                Image(space.coverImageName)
                    .resizable()
                    .scaledToFill()
                    .saturation(0.72)
                    .contrast(0.92)
                    .opacity(isHovered ? 0.48 : 0.38)
                    .accessibilityHidden(true)

                LinearGradient(
                    colors: [
                        palette.panel.opacity(0.20),
                        palette.panel.opacity(0.48),
                        palette.panel.opacity(0.92)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
        }
        .clipped()
    }
}

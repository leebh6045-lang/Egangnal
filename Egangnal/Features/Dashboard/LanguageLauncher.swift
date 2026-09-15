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
    let isCompact: Bool
    let openLanguage: (LanguageSpace) -> Void

    var body: some View {
        Group {
            if isCompact {
                VStack(alignment: .center, spacing: Metrics.compactSpacing) {
                    languageCards
                }
            } else {
                HStack(alignment: .top, spacing: AppTheme.panelSpacing) {
                    languageCards
                }
            }
        }
        .frame(width: availableWidth, alignment: isCompact ? .top : .topLeading)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("dashboard.languageLauncher")
    }

    @ViewBuilder
    private var languageCards: some View {
        ForEach(orderedSpaces) { space in
            languageButton(for: space)
        }
    }

    private func languageButton(for space: LanguageSpace) -> some View {
        Button {
            openLanguage(space)
        } label: {
            languageCard(for: space)
        }
        .buttonStyle(.plain)
        .frame(
            width: cardWidth,
            height: cardHeight,
            alignment: .topLeading
        )
        .help("进入\(space.title)学习空间")
        .accessibilityLabel("\(space.title)，\(space.nativeTitle)")
        .accessibilityIdentifier("dashboard.open.\(space.rawValue)")
        .overlay {
            Rectangle()
                .fill(.clear)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(space.title)卡片视觉边界")
                .accessibilityIdentifier("dashboard.cardFrame.\(space.rawValue)")
                .allowsHitTesting(false)
        }
        .onHover { isHovering in
            hoveredSpace = isHovering ? space : nil
        }
        .animation(.easeOut(duration: 0.14), value: hoveredSpace)
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
            height: cardHeight,
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

    // 首页按使用习惯展示英语在左、日语在右，不改变全局语言枚举顺序。
    private var orderedSpaces: [LanguageSpace] {
        [.english, .japanese]
    }

    private var cardWidth: CGFloat {
        guard !isCompact else { return Metrics.compactCardWidth }
        return (availableWidth - AppTheme.panelSpacing) / 2
    }

    private var cardHeight: CGFloat {
        guard !isCompact else { return Metrics.compactCardHeight }
        return cardWidth / Metrics.cardAspectRatio
    }
}

private extension LanguageLauncher {
    enum Metrics {
        static let compactCardWidth: CGFloat = 320
        static let compactCardHeight: CGFloat = 154
        static let compactSpacing: CGFloat = 10
        static let cardAspectRatio: CGFloat = 320 / 176
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

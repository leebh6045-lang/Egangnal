//
//  BrandWordmark.swift
//  Egangnal
//

import SwiftUI

struct BrandGlyphSpec: Identifiable, Equatable {
    let sourceIndex: Int
    let targetIndex: Int
    let source: String
    let target: String

    var id: Int { sourceIndex }

    var changesIntoU: Bool {
        source == "n" && target == "u"
    }
}

enum BrandWordmarkModel {
    // 稳定源索引可区分重复字母，并保证正反向重排使用同一组字形。
    static let glyphs: [BrandGlyphSpec] = [
        BrandGlyphSpec(sourceIndex: 0, targetIndex: 7, source: "E", target: "e"),
        BrandGlyphSpec(sourceIndex: 1, targetIndex: 6, source: "g", target: "g"),
        BrandGlyphSpec(sourceIndex: 2, targetIndex: 5, source: "a", target: "a"),
        BrandGlyphSpec(sourceIndex: 3, targetIndex: 4, source: "n", target: "u"),
        BrandGlyphSpec(sourceIndex: 4, targetIndex: 3, source: "g", target: "g"),
        BrandGlyphSpec(sourceIndex: 5, targetIndex: 2, source: "n", target: "n"),
        BrandGlyphSpec(sourceIndex: 6, targetIndex: 1, source: "a", target: "a"),
        BrandGlyphSpec(sourceIndex: 7, targetIndex: 0, source: "l", target: "L")
    ]

    static var sourceWord: String {
        glyphs
            .sorted { $0.sourceIndex < $1.sourceIndex }
            .map(\.source)
            .joined()
    }

    static var targetWord: String {
        glyphs
            .sorted { $0.targetIndex < $1.targetIndex }
            .map(\.target)
            .joined()
    }
}

struct BrandWordmark: View {
    @Environment(\.appPalette) private var palette
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let isEnabled: Bool
    let onAnimationStateChanged: (Bool) -> Void

    @State private var arrangementProgress: CGFloat = 0
    @State private var showsCompanionWords = false
    @State private var isLanguage = false
    @State private var isAnimating = false
    @State private var animationTask: Task<Void, Never>?

    var body: some View {
        ZStack(alignment: .topLeading) {
            companionWord("For", width: BrandWordmarkMetrics.forWidth)
                .offset(x: BrandWordmarkMetrics.forX)
                .offset(x: showsCompanionWords ? 0 : 8)

            ForEach(BrandWordmarkModel.glyphs) { glyph in
                BrandGlyphLayer(
                    glyph: glyph,
                    progress: arrangementProgress,
                    color: palette.watermark
                )
                .animation(letterAnimation(for: glyph), value: arrangementProgress)
            }

            companionWord("Study", width: BrandWordmarkMetrics.studyWidth)
                .offset(x: BrandWordmarkMetrics.studyX)
                .offset(x: showsCompanionWords ? 0 : -8)

            Button(action: toggleWordmark) {
                Color.clear
                    .frame(
                        width: BrandWordmarkMetrics.wordWidth,
                        height: BrandWordmarkMetrics.canvasHeight
                    )
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .offset(x: isLanguage ? BrandWordmarkMetrics.languageX : 0)
            .disabled(!isEnabled || isAnimating)
            .help(isLanguage ? "恢复 Egangnal" : "展开品牌含义")
            .accessibilityLabel(accessibilityLabel)
            .accessibilityValue(accessibilityValue)
            .accessibilityIdentifier("dashboard.brand.toggle")
        }
        .frame(
            width: BrandWordmarkMetrics.canvasWidth,
            height: BrandWordmarkMetrics.canvasHeight,
            alignment: .topLeading
        )
        .onDisappear {
            animationTask?.cancel()
            setAnimating(false)
        }
    }

    private func companionWord(_ word: String, width: CGFloat) -> some View {
        Text(word)
            .font(.system(size: 22, weight: .semibold, design: .rounded))
            .foregroundStyle(palette.secondaryText)
            .frame(width: width, height: BrandWordmarkMetrics.canvasHeight)
            .opacity(showsCompanionWords ? 1 : 0)
            .animation(
                reduceMotion
                    ? nil
                    : .easeOut(duration: BrandWordmarkTiming.companionFadeDuration),
                value: showsCompanionWords
            )
            .accessibilityHidden(true)
    }

    private var accessibilityLabel: String {
        if isAnimating {
            return isLanguage ? "品牌含义正在展开" : "品牌含义正在收起"
        }
        return isLanguage ? "Language，收起品牌含义" : "Egangnal，展开品牌含义"
    }

    private var accessibilityValue: String {
        if isAnimating {
            return isLanguage ? "正在展开" : "正在收起"
        }
        return isLanguage ? "For Language Study" : "Egangnal"
    }

    private func letterAnimation(for glyph: BrandGlyphSpec) -> Animation? {
        guard !reduceMotion else { return nil }

        let order = arrangementProgress > 0.5
            ? glyph.sourceIndex
            : glyph.targetIndex
        return .easeInOut(duration: BrandWordmarkTiming.letterDuration)
            .delay(Double(order) * BrandWordmarkTiming.letterStagger)
    }

    private func toggleWordmark() {
        guard isEnabled, !isAnimating else { return }

        if reduceMotion {
            switchWithoutMotion()
        } else if isLanguage {
            collapseWordmark()
        } else {
            expandWordmark()
        }
    }

    private func expandWordmark() {
        isLanguage = true
        setAnimating(true)
        arrangementProgress = 1

        animationTask = Task { @MainActor in
            // 先完成字母重排，再呈现两侧单词。
            guard await wait(BrandWordmarkTiming.arrangementSettleDelay) else { return }
            showsCompanionWords = true
            guard await wait(BrandWordmarkTiming.companionSettleDelay) else { return }
            setAnimating(false)
        }
    }

    private func collapseWordmark() {
        isLanguage = false
        setAnimating(true)
        showsCompanionWords = false

        animationTask = Task { @MainActor in
            // 两侧单词淡出后，才开始反向重排。
            guard await wait(BrandWordmarkTiming.companionSettleDelay) else { return }
            arrangementProgress = 0
            guard await wait(BrandWordmarkTiming.arrangementSettleDelay) else { return }
            setAnimating(false)
        }
    }

    private func switchWithoutMotion() {
        animationTask?.cancel()
        isLanguage.toggle()
        arrangementProgress = isLanguage ? 1 : 0
        showsCompanionWords = isLanguage
        setAnimating(false)
    }

    @MainActor
    private func wait(_ duration: Duration) async -> Bool {
        do {
            try await Task.sleep(for: duration)
            return !Task.isCancelled
        } catch {
            setAnimating(false)
            return false
        }
    }

    private func setAnimating(_ value: Bool) {
        guard isAnimating != value else { return }
        isAnimating = value
        onAnimationStateChanged(value)
    }
}

private struct BrandGlyphLayer: View {
    let glyph: BrandGlyphSpec
    let progress: CGFloat
    let color: Color

    var body: some View {
        ZStack {
            if glyph.source == glyph.target {
                glyphText(glyph.source)
            } else {
                glyphText(glyph.source)
                    .modifier(
                        BrandGlyphFaceModifier(
                            progress: progress,
                            showsTarget: false,
                            rotates: glyph.changesIntoU
                        )
                    )
                glyphText(glyph.target)
                    .modifier(
                        BrandGlyphFaceModifier(
                            progress: progress,
                            showsTarget: true,
                            rotates: glyph.changesIntoU
                        )
                    )
            }
        }
        .frame(
            width: BrandWordmarkMetrics.glyphWidth,
            height: BrandWordmarkMetrics.canvasHeight
        )
        .modifier(
            BrandGlyphMotionModifier(
                progress: progress,
                sourceIndex: glyph.sourceIndex,
                targetIndex: glyph.targetIndex
            )
        )
        .accessibilityHidden(true)
    }

    private func glyphText(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 48, weight: .bold, design: .rounded))
            .foregroundStyle(color)
            .lineLimit(1)
    }
}

private struct BrandGlyphMotionModifier: ViewModifier, @preconcurrency Animatable {
    var progress: CGFloat
    let sourceIndex: Int
    let targetIndex: Int

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    func body(content: Content) -> some View {
        let value = min(max(progress, 0), 1)
        let sourceX = CGFloat(sourceIndex) * BrandWordmarkMetrics.glyphWidth
        let targetX = BrandWordmarkMetrics.languageX
            + CGFloat(targetIndex) * BrandWordmarkMetrics.glyphWidth
        let x = sourceX + (targetX - sourceX) * value
        // 短弧线让交叉移动的字母保持可辨识，同时不扩大固定画布。
        let arc = sin(.pi * value)
        let direction: CGFloat = sourceIndex.isMultiple(of: 2) ? -1 : 1

        content
            .offset(x: x, y: -arc * (8 + CGFloat(sourceIndex % 3) * 2))
            .rotationEffect(.degrees(direction * 4 * arc))
            .scaleEffect(1 + 0.035 * arc)
    }
}

private struct BrandGlyphFaceModifier: ViewModifier, @preconcurrency Animatable {
    var progress: CGFloat
    let showsTarget: Bool
    let rotates: Bool

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    func body(content: Content) -> some View {
        let value = min(max(progress, 0), 1)
        let opacity = showsTarget ? value : 1 - value
        let rotation: Double = rotates
            ? (showsTarget
                ? -180 * Double(1 - value)
                : 180 * Double(value))
            : 0

        content
            .opacity(opacity)
            .rotationEffect(.degrees(rotation))
            .scaleEffect(0.94 + 0.06 * opacity)
    }
}

private enum BrandWordmarkMetrics {
    static let canvasWidth: CGFloat = 400
    static let canvasHeight: CGFloat = 60
    static let glyphWidth: CGFloat = 32
    static let wordWidth = glyphWidth * 8
    static let languageX: CGFloat = 52
    static let forX: CGFloat = 0
    static let forWidth: CGFloat = 38
    static let studyX = languageX + wordWidth + 14
    static let studyWidth: CGFloat = 66
}

private enum BrandWordmarkTiming {
    static let letterDuration = 0.62
    static let letterStagger = 0.025
    static let companionFadeDuration = 0.28
    static let arrangementSettleDelay: Duration = .milliseconds(850)
    static let companionSettleDelay: Duration = .milliseconds(320)
}

#Preview {
    BrandWordmark(isEnabled: true, onAnimationStateChanged: { _ in })
        .environment(\.appPalette, AppAppearance.dark.palette)
        .padding()
        .background(AppAppearance.dark.palette.canvasTop)
}

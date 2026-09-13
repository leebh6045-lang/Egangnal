//
//  AppTheme.swift
//  Egangnal
//

import SwiftUI

enum AppTheme {
    static let panelCornerRadius: CGFloat = 8
    static let contentPadding: CGFloat = 28
    static let panelSpacing: CGFloat = 20
    static let dashboardTopPadding: CGFloat = 48
    static let dashboardHeaderSpacing: CGFloat = 24
    static let dashboardCalendarWidth: CGFloat = 274
    static let dashboardLauncherTopOffset: CGFloat = 172
    static let launcherCardMaxWidth: CGFloat = 320
    static let launcherCardHeight: CGFloat = 176
    static let workspaceCardMaxWidth: CGFloat = 344
    static let workspaceCardHeight: CGFloat = 192
    static let workspaceGridMaxWidth: CGFloat = 708
    static let workspaceNavigationWidth: CGFloat = 440
    static let workspaceNavigationHeight: CGFloat = 58
    static let workspaceNavigationTopInset: CGFloat = 10
    static let workspaceNavigationActivationHeight: CGFloat = 24
    static let workspaceStudyTimeWidth: CGFloat = 150
    static let workspaceStudyTimeGap: CGFloat = 12
    static let backgroundGridSpacing: CGFloat = 28
    static let wordBookContentMinHeight: CGFloat = 150
    static let wordBookNavigationClearance: CGFloat = 56
    static let wordBookReadingControlsClearance: CGFloat = 104
    static let wordBookEntryFontSize: CGFloat = 30
    static let wordBookEntryMinHeight: CGFloat = 74
    static let wordBookEntryColumnSpacing: CGFloat = 32
    static let wordBookFieldSpacing: CGFloat = 18
    static let wordBookMaskCornerRadius: CGFloat = 6
    static let wordQuizBodyMaxWidth: CGFloat = 980
    static let wordQuizBodyHorizontalInset: CGFloat = 24
    static let wordQuizContentHeight: CGFloat = 400
    static let wordQuizContentMinHeight: CGFloat = 320
    static let wordQuizColumnSpacing: CGFloat = 24
    static let wordQuizSettingsWidth: CGFloat = 250
    static let wordQuizChoiceWidth: CGFloat = 136
    static let wordQuizCompactChoiceWidth: CGFloat = 166
    static let wordQuizChoiceSpacing: CGFloat = 12
    static let wordQuizChoiceHeight: CGFloat = 78
    static let wordQuizSuccessRingLineWidth: CGFloat = 2
    static let wordQuizFeedbackHeight: CGFloat = 54
    static let wordQuizIdleWatermarkFontSize: CGFloat = 54
    // 词库：沿用单词本的双栏词块语言，但字号更小、多了检索区与悬停浮层。
    static let lexiconEntryTermFontSize: CGFloat = 24
    static let lexiconEntryGlossFontSize: CGFloat = 20
    static let lexiconEntryMinHeight: CGFloat = 64
    static let lexiconEntryFieldSpacing: CGFloat = 8
    static let lexiconGridRowSpacing: CGFloat = 28
    static let lexiconFilterFontSize: CGFloat = 16
    /// 检索区收窄到居中的一条带，避免筛选与搜索被拉开到窗口两端。
    static let lexiconFilterBandMaxWidth: CGFloat = 720
    static let lexiconSeparatorThickness: CGFloat = 2
    static let lexiconFilterUnderlineHeight: CGFloat = 2
    static let lexiconResultCountFontSize: CGFloat = 14
    static let lexiconPaginationFontSize: CGFloat = 14
    static let lexiconSearchFontSize: CGFloat = 16
    /// 浮层延时。太短会随处误触发，实测 0.6 秒更稳。
    static let lexiconTooltipDelay: Duration = .milliseconds(600)
    /// 收藏按钮固定占位，显隐不推动词条。
    static let lexiconCollectButtonWidth: CGFloat = 26
    static let lexiconTooltipMinWidth: CGFloat = 200
    static let lexiconTooltipMaxWidth: CGFloat = 360
    static let lexiconTooltipFadeDuration: TimeInterval = 0.28
    static let lexiconTooltipEdgeInset: CGFloat = 12
    static let toggleSize: CGFloat = 36
    static let pageFadeDuration: TimeInterval = 0.22
    static let rippleDuration: TimeInterval = 0.72
    static let rippleFeather: CGFloat = 40
    static let rippleCleanupDelay: Duration = .milliseconds(800)
}

struct AppPalette {
    let canvasTop: Color
    let canvasBottom: Color
    let panel: Color
    let panelRaised: Color
    let border: Color
    let primaryText: Color
    let secondaryText: Color
    let tertiaryText: Color
    let watermark: Color
    let japaneseAccent: Color
    let englishAccent: Color
    let grammarAccent: Color
    let frequencyAccent: Color
    let calendarAccent: Color
    let calendarCompleted: Color
    let calendarVisited: Color
    /// “已收录到单词本”的标记色。浅色主题必须压深，否则在白色面板上看不清。
    let collectedAccent: Color
    let accentForeground: Color
    let guideBackground: Color
    let guideText: Color
    let guideBorder: Color
    let success: Color
    let error: Color
    let panelShadow: Color
    let ambientLeading: Color
    let ambientTrailing: Color

    func accent(for space: LanguageSpace) -> Color {
        switch space {
        case .japanese:
            japaneseAccent
        case .english:
            englishAccent
        }
    }
}

extension AppAppearance {
    var palette: AppPalette {
        switch self {
        case .light:
            AppPalette(
                canvasTop: Color(red: 0.961, green: 0.969, blue: 0.980),
                canvasBottom: Color(red: 0.929, green: 0.945, blue: 0.957),
                panel: .white,
                panelRaised: Color(red: 0.910, green: 0.929, blue: 0.949),
                border: Color(red: 0.529, green: 0.584, blue: 0.647),
                primaryText: Color(red: 0.094, green: 0.129, blue: 0.169),
                secondaryText: Color(red: 0.349, green: 0.396, blue: 0.451),
                tertiaryText: Color(red: 0.455, green: 0.506, blue: 0.569),
                watermark: Color(red: 0.659, green: 0.690, blue: 0.729),
                // 两个语言空间使用统一的浅蓝强调色，避免产生错误的语言色彩暗示。
                japaneseAccent: Color(red: 0.200, green: 0.435, blue: 0.820),
                englishAccent: Color(red: 0.200, green: 0.435, blue: 0.820),
                grammarAccent: Color(red: 0.227, green: 0.490, blue: 0.365),
                frequencyAccent: Color(red: 0.118, green: 0.400, blue: 0.690),
                calendarAccent: Color(red: 0.118, green: 0.400, blue: 0.690),
                // 完成学习日使用金黄色，区别于访问但未达标的灰色。
                calendarCompleted: Color(red: 0.925, green: 0.682, blue: 0.118),
                calendarVisited: Color(red: 0.694, green: 0.729, blue: 0.776),
                // 浅色背景上必须用深金，浅黄会失去对比度。
                collectedAccent: Color(red: 0.635, green: 0.455, blue: 0.024),
                accentForeground: .white,
                guideBackground: Color(red: 1.000, green: 0.980, blue: 0.875),
                guideText: Color(red: 0.075, green: 0.075, blue: 0.067),
                guideBorder: Color(red: 0.820, green: 0.733, blue: 0.475),
                success: Color(red: 0.110, green: 0.490, blue: 0.310),
                error: Color(red: 0.780, green: 0.160, blue: 0.220),
                panelShadow: .black.opacity(0.08),
                ambientLeading: .clear,
                ambientTrailing: .clear
            )
        case .dark:
            AppPalette(
                canvasTop: Color(red: 0.035, green: 0.051, blue: 0.071),
                canvasBottom: Color(red: 0.051, green: 0.075, blue: 0.106),
                panel: Color(red: 0.071, green: 0.098, blue: 0.137),
                panelRaised: Color(red: 0.098, green: 0.141, blue: 0.200),
                border: Color(red: 0.337, green: 0.400, blue: 0.478),
                primaryText: Color(red: 0.957, green: 0.969, blue: 0.984),
                secondaryText: Color(red: 0.682, green: 0.725, blue: 0.780),
                tertiaryText: Color(red: 0.522, green: 0.573, blue: 0.639),
                watermark: Color(red: 0.306, green: 0.361, blue: 0.427),
                japaneseAccent: Color(red: 0.302, green: 0.553, blue: 1.000),
                englishAccent: Color(red: 0.302, green: 0.553, blue: 1.000),
                grammarAccent: Color(red: 0.180, green: 0.827, blue: 0.604),
                frequencyAccent: Color(red: 0.259, green: 0.784, blue: 1.000),
                calendarAccent: Color(red: 0.259, green: 0.784, blue: 1.000),
                // 深色主题提高饱和度，让金黄色在深色背景上更清晰。
                calendarCompleted: Color(red: 1.000, green: 0.710, blue: 0.157),
                calendarVisited: Color(red: 0.357, green: 0.431, blue: 0.529),
                // 深色背景上用浅黄。
                collectedAccent: Color(red: 0.976, green: 0.827, blue: 0.365),
                accentForeground: Color(red: 0.035, green: 0.051, blue: 0.071),
                guideBackground: Color(red: 0.098, green: 0.141, blue: 0.200),
                guideText: Color(red: 0.957, green: 0.969, blue: 0.984),
                guideBorder: Color(red: 0.337, green: 0.400, blue: 0.478),
                success: Color(red: 0.239, green: 0.859, blue: 0.596),
                error: Color(red: 1.000, green: 0.369, blue: 0.431),
                panelShadow: .black.opacity(0.34),
                ambientLeading: Color(red: 1.000, green: 0.110, blue: 0.275).opacity(0.12),
                ambientTrailing: Color(red: 0.110, green: 0.490, blue: 1.000).opacity(0.15)
            )
        }
    }
}

private struct AppPaletteKey: EnvironmentKey {
    static let defaultValue = AppAppearance.dark.palette
}

extension EnvironmentValues {
    var appPalette: AppPalette {
        get { self[AppPaletteKey.self] }
        set { self[AppPaletteKey.self] = newValue }
    }
}

struct WorkspaceBackground: View {
    @Environment(\.appPalette) private var palette
    @Environment(\.appPersonalization) private var personalization

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [palette.canvasTop, palette.canvasBottom],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            LinearGradient(
                stops: [
                    .init(color: palette.ambientLeading, location: 0),
                    .init(color: .clear, location: 0.54)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0.42),
                    .init(color: palette.ambientTrailing, location: 1)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            if personalization.showsGridBackground {
                WorkspaceGridPattern()
            }
        }
        .ignoresSafeArea()
    }
}

private struct WorkspaceGridPattern: View {
    @Environment(\.appPalette) private var palette

    var body: some View {
        Canvas { context, size in
            var path = Path()
            let spacing = AppTheme.backgroundGridSpacing

            for x in stride(from: CGFloat.zero, through: size.width, by: spacing) {
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: size.height))
            }
            for y in stride(from: CGFloat.zero, through: size.height, by: spacing) {
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
            }

            context.stroke(
                path,
                with: .color(palette.border.opacity(0.13)),
                lineWidth: 0.5
            )
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

private struct WorkspacePanelModifier: ViewModifier {
    @Environment(\.appPalette) private var palette

    func body(content: Content) -> some View {
        content
            .background(palette.panel)
            .clipShape(.rect(cornerRadius: AppTheme.panelCornerRadius))
            .overlay {
                RoundedRectangle(cornerRadius: AppTheme.panelCornerRadius)
                    .stroke(palette.border, lineWidth: 1)
            }
            .shadow(color: palette.panelShadow, radius: 12, y: 5)
    }
}

extension View {
    func workspacePanel() -> some View {
        modifier(WorkspacePanelModifier())
    }
}

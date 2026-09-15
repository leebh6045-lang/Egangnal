//
//  AppTheme.swift
//  Egangnal
//

import SwiftUI

enum AppTheme {
    static let panelCornerRadius: CGFloat = 8
    static let contentPadding: CGFloat = 28
    static let panelSpacing: CGFloat = 20
    static let workspaceCardMaxWidth: CGFloat = 344
    static let workspaceCardHeight: CGFloat = 192
    static let workspaceGridMaxWidth: CGFloat = 708
    static let workspaceNavigationWidth: CGFloat = 440
    static let workspaceNavigationHeight: CGFloat = 58
    static let workspaceNavigationTopInset: CGFloat = 10
    static let workspaceNavigationActivationHeight: CGFloat = 24
    static let workspaceStudyTimeWidth: CGFloat = 150
    static let workspaceStudyTimeGap: CGFloat = 12
    /// 功能栏唤出时顶部渐进材质带的高度（从窗口顶边算起）。
    /// 数值来自 2026-09-13 的静态预览定稿：192 pt 能盖住页眉但不碰到第一行词条。
    static let workspaceNavigationBackdropHeight: CGFloat = 192
    /// 材质带顶端的面板色着色浓度，向下渐弱到零。
    static let workspaceNavigationBackdropTint: Double = 0.35
    /// 胶囊背后已经是被模糊过的内容，着色要比材质带重，否则显得虚。
    static let workspaceNavigationCapsuleTint: Double = 0.62
    static let backgroundGridSpacing: CGFloat = 28
    static let wordBookContentMinHeight: CGFloat = 150
    static let wordBookNavigationClearance: CGFloat = 56
    static let wordBookReadingControlsClearance: CGFloat = 104
    // 词条字号：单词本与词库共用同一组，切换页面时文字尺寸不再跳变。
    // 26 / 20 由 2026-09-13 的字号实验台定稿：26 落在原先两页（30 与 24）之间且偏向词库，
    // 20 的词义在默认窗口下能让 12 字释义整行放下。
    static let entryTermFontSize: CGFloat = 26
    static let entryGlossFontSize: CGFloat = 20
    static let entryMinHeight: CGFloat = 64
    static let entryGridColumnSpacing: CGFloat = 32
    static let entryGridRowSpacing: CGFloat = 24
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
    // 词库：沿用单词本的双栏词块语言，多了检索区与悬停浮层。
    static let lexiconEntryFieldSpacing: CGFloat = 8
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
    // 横格本。行高必须是背景网格间距的整数倍：「对齐实线」样式的前提就是横线落在网格线上。
    static let ruledRowHeight: CGFloat = backgroundGridSpacing * 2
    /// 行号列宽同样取网格的整数倍，让页边线也落在网格线上。
    static let ruledNumberColumnWidth: CGFloat = backgroundGridSpacing * 2
    static let ruledNumberFontSize: CGFloat = 11
    static let ruledNumberTrailingInset: CGFloat = 12
    static let ruledCellLeadingInset: CGFloat = 20
    static let ruledCellTrailingInset: CGFloat = 12
    /// 文字底部与横线之间的距离，模拟"写在线上"。
    static let ruledTextBottomInset: CGFloat = 5
    static let ruledLineWidth: CGFloat = 1
    static let ruledDashPattern: [CGFloat] = [7, 5]
    /// 单词与词义的宽度比。横格下靠左排布，词义带词性前缀更长，多分一点。
    static let ruledFieldProportions: [CGFloat] = [1, 1.25]
    /// 「局部隐格」时背景网格从滚动区上下边缘向纸面内部延伸的距离，之后再淡出。
    /// 42 pt 由用户在 2026-09-14 定稿。
    static let ruledGridCutoutInset: CGFloat = 42
    /// 「局部隐格」时延伸段末端的淡出长度。
    static let ruledGridFeather: CGFloat = 20
    /// 单词本横格纸面末尾留给右下角遮盖按钮的空白；取网格的整数倍以免纸面网格错相。
    static let ruledWordBookBottomInset: CGFloat = backgroundGridSpacing * 4
    /// 集词阁横格纸面末尾留给清除遮盖按钮的空白。
    static let ruledLexiconBottomInset: CGFloat = backgroundGridSpacing * 2
    // 手帐。行高比横格紧一点：没有横线要落笔，靠分组标题和项目符号建立节律。
    static let journalRowHeight: CGFloat = 46
    static let journalTopInset: CGFloat = 12
    static let journalSectionSpacing: CGFloat = 18
    static let journalHeaderSpacing: CGFloat = 6
    static let journalHeaderFontSize: CGFloat = 13
    static let journalHeaderSubtitleFontSize: CGFloat = 12.5
    static let journalHeaderDotSize: CGFloat = 8
    static let journalColumnSpacing: CGFloat = 48
    static let journalBulletWidth: CGFloat = 22
    static let journalBulletSpacing: CGFloat = 8
    static let journalBulletFontSize: CGFloat = 12
    /// 荧光笔：一条略斜的粗色带压在单词后半高度上。
    static let journalMarkerHeight: CGFloat = 12
    static let journalMarkerHorizontalBleed: CGFloat = 4
    static let journalMarkerBottomOffset: CGFloat = 4
    static let journalMarkerSkewDegrees: Double = -0.6
    /// 单词本背景点阵的点半径。0.8 在 Retina 上恰好是"一粒"，不会糊成一小团。
    static let backgroundDotRadius: CGFloat = 0.8
    /// 台灯光：以窗口左上角为圆心的暖色径向渐变，半径按窗口短边比例取值。
    static let lampRadiusFraction: CGFloat = 0.62
    // 集词阁的图书馆元素。
    static let lexiconGuideWordFontSize: CGFloat = 12
    static let lexiconGuideWordBandHeight: CGFloat = 22
    static let lexiconStampSize: CGFloat = 150
    static let lexiconStampRingFontSize: CGFloat = 11
    static let lexiconStampCenterFontSize: CGFloat = 22
    static let toggleSize: CGFloat = 36
    static let pageFadeDuration: TimeInterval = 0.22
    /// 从首页进入功能页的常驻过渡：略带模糊与放大地浮现，比纯淡入更不生硬（2026-09-15 用户定稿）。
    static let workspaceEnterDuration: TimeInterval = 0.36
    static let workspaceEnterBlur: CGFloat = 3
    static let workspaceEnterScale: CGFloat = 1.012
    /// 功能页之间的切换（2026-09-15 用户定稿）：滑移 20 pt、浮现幅度为进入效果的一半，0.30 s。
    static let featureTransitionDuration: TimeInterval = 0.30
    static let featureSlideDistance: CGFloat = 20
    static let featureFloatScale: CGFloat = 1.008
    static let featureFloatBlur: CGFloat = 2
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
    /// 横格本的横线：比背景网格粗、深，并换一个色相，才能从网格里“提”出来。
    let ruledLine: Color
    /// 横格本左侧的页边线。
    let ruledMargin: Color
    /// 手帐里划过高频词的荧光笔颜色。
    let markerHighlight: Color
    /// 单词本台灯光的颜色（含透明度）；浅色主题几乎不可见是刻意的，白底上没有"灯"可打。
    let lampLight: Color
    /// 集词阁藏书章的墨色。
    let stampInk: Color

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
                ambientTrailing: .clear,
                // 墨蓝色横线，与冷灰网格拉开色相。
                ruledLine: Color(red: 0.227, green: 0.322, blue: 0.455).opacity(0.42),
                ruledMargin: Color(red: 0.769, green: 0.329, blue: 0.329).opacity(0.52),
                markerHighlight: Color(red: 1.000, green: 0.839, blue: 0.329).opacity(0.55),
                lampLight: Color(red: 1.000, green: 0.839, blue: 0.588).opacity(0.10),
                stampInk: Color(red: 0.227, green: 0.322, blue: 0.455).opacity(0.16)
            )
        case .warm:
            // 暖纸：整体向米色偏移，文字用暖黑，强调色降一点饱和度以免在暖底上发紫。
            AppPalette(
                canvasTop: Color(red: 0.961, green: 0.945, blue: 0.914),
                canvasBottom: Color(red: 0.922, green: 0.898, blue: 0.851),
                panel: Color(red: 0.988, green: 0.980, blue: 0.961),
                panelRaised: Color(red: 0.918, green: 0.890, blue: 0.839),
                border: Color(red: 0.604, green: 0.569, blue: 0.514),
                primaryText: Color(red: 0.133, green: 0.122, blue: 0.102),
                secondaryText: Color(red: 0.373, green: 0.353, blue: 0.318),
                tertiaryText: Color(red: 0.494, green: 0.471, blue: 0.427),
                watermark: Color(red: 0.710, green: 0.682, blue: 0.631),
                japaneseAccent: Color(red: 0.227, green: 0.392, blue: 0.706),
                englishAccent: Color(red: 0.227, green: 0.392, blue: 0.706),
                grammarAccent: Color(red: 0.255, green: 0.471, blue: 0.353),
                frequencyAccent: Color(red: 0.173, green: 0.361, blue: 0.620),
                calendarAccent: Color(red: 0.173, green: 0.361, blue: 0.620),
                calendarCompleted: Color(red: 0.878, green: 0.627, blue: 0.110),
                calendarVisited: Color(red: 0.706, green: 0.678, blue: 0.627),
                collectedAccent: Color(red: 0.604, green: 0.420, blue: 0.012),
                accentForeground: .white,
                guideBackground: Color(red: 0.996, green: 0.973, blue: 0.863),
                guideText: Color(red: 0.075, green: 0.075, blue: 0.067),
                guideBorder: Color(red: 0.780, green: 0.690, blue: 0.451),
                success: Color(red: 0.110, green: 0.490, blue: 0.310),
                error: Color(red: 0.780, green: 0.160, blue: 0.220),
                panelShadow: Color(red: 0.235, green: 0.176, blue: 0.078).opacity(0.10),
                ambientLeading: .clear,
                ambientTrailing: .clear,
                // 赭色横线，像纸上印的格线。
                ruledLine: Color(red: 0.463, green: 0.361, blue: 0.227).opacity(0.46),
                ruledMargin: Color(red: 0.737, green: 0.329, blue: 0.282).opacity(0.52),
                markerHighlight: Color(red: 1.000, green: 0.839, blue: 0.329).opacity(0.60),
                lampLight: Color(red: 1.000, green: 0.816, blue: 0.510).opacity(0.22),
                stampInk: Color(red: 0.463, green: 0.361, blue: 0.227).opacity(0.18)
            )
        case .dark:
            // 石墨：中性深灰，不再带蓝底与红蓝环境光；层次只靠面板与边框的明度差表达。
            AppPalette(
                canvasTop: Color(red: 0.055, green: 0.059, blue: 0.067),
                canvasBottom: Color(red: 0.082, green: 0.090, blue: 0.102),
                panel: Color(red: 0.106, green: 0.118, blue: 0.133),
                panelRaised: Color(red: 0.141, green: 0.157, blue: 0.180),
                border: Color(red: 0.353, green: 0.376, blue: 0.408),
                primaryText: Color(red: 0.949, green: 0.953, blue: 0.961),
                secondaryText: Color(red: 0.706, green: 0.725, blue: 0.757),
                tertiaryText: Color(red: 0.525, green: 0.549, blue: 0.584),
                watermark: Color(red: 0.290, green: 0.314, blue: 0.345),
                japaneseAccent: Color(red: 0.357, green: 0.608, blue: 1.000),
                englishAccent: Color(red: 0.357, green: 0.608, blue: 1.000),
                grammarAccent: Color(red: 0.180, green: 0.827, blue: 0.604),
                frequencyAccent: Color(red: 0.322, green: 0.780, blue: 0.949),
                calendarAccent: Color(red: 0.322, green: 0.780, blue: 0.949),
                // 深色主题提高饱和度，让金黄色在深色背景上更清晰。
                calendarCompleted: Color(red: 1.000, green: 0.710, blue: 0.157),
                calendarVisited: Color(red: 0.373, green: 0.400, blue: 0.439),
                // 深色背景上用浅黄。
                collectedAccent: Color(red: 0.961, green: 0.812, blue: 0.353),
                accentForeground: Color(red: 0.055, green: 0.059, blue: 0.067),
                guideBackground: Color(red: 0.141, green: 0.157, blue: 0.180),
                guideText: Color(red: 0.949, green: 0.953, blue: 0.961),
                guideBorder: Color(red: 0.353, green: 0.376, blue: 0.408),
                success: Color(red: 0.239, green: 0.859, blue: 0.596),
                error: Color(red: 1.000, green: 0.369, blue: 0.431),
                panelShadow: .black.opacity(0.40),
                ambientLeading: .clear,
                ambientTrailing: .clear,
                // 冷灰横线：深底上靠明度而不是靠色相与网格区分。
                ruledLine: Color(red: 0.769, green: 0.808, blue: 0.863).opacity(0.30),
                ruledMargin: Color(red: 1.000, green: 0.439, blue: 0.439).opacity(0.32),
                markerHighlight: Color(red: 0.961, green: 0.812, blue: 0.353).opacity(0.32),
                lampLight: Color(red: 1.000, green: 0.769, blue: 0.471).opacity(0.10),
                stampInk: Color(red: 0.769, green: 0.808, blue: 0.863).opacity(0.13)
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

    /// 背景图案按页面独立保存；调用方必须显式指明页面，新页面不能悄悄继承别页的偏好。
    let page: PageBackgroundScope
    /// 是否在左上角打一盏台灯。
    var showsLamp = false
    /// 横格本所占的滚动区。纸面自己决定画不画网格，
    /// 这里只负责把背景网格从纸面下面抽掉。
    var gridCutout: RuledSheetRegion?

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

            if showsLamp {
                WorkspaceLampLight()
            }

            if pattern != .none {
                // 图案随页面偏好变化时整层替换，让它交叉淡入而不是瞬间重画。
                WorkspaceGridPattern(pattern: pattern, cutout: gridCutout)
                    .id(pattern)
                    .transition(.opacity)
            }
        }
        .ignoresSafeArea()
    }

    private var pattern: PageBackgroundPattern {
        personalization.backgroundPattern(for: page)
    }
}

/// 左上角的一片暖色径向光，给桌面一个光源方向。压在网格之下、底色之上。
private struct WorkspaceLampLight: View {
    @Environment(\.appPalette) private var palette

    var body: some View {
        GeometryReader { proxy in
            let radius = min(proxy.size.width, proxy.size.height) * AppTheme.lampRadiusFraction
            RadialGradient(
                colors: [palette.lampLight, .clear],
                center: .topLeading,
                startRadius: 0,
                endRadius: radius
            )
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// 全局细网格（或点阵）。间距、线宽与透明度是横格本样式的对齐基准，改动时同步检查 `AppTheme.ruled*`。
struct WorkspaceGridPattern: View {
    @Environment(\.appPalette) private var palette

    let pattern: PageBackgroundPattern
    let cutout: RuledSheetRegion?

    var body: some View {
        GeometryReader { proxy in
            let origin = proxy.frame(in: .global).origin
            Canvas { context, size in
                switch pattern {
                case .none:
                    break
                case .grid:
                    Self.drawGrid(
                        in: &context,
                        size: size,
                        spacing: AppTheme.backgroundGridSpacing,
                        color: palette.border.opacity(0.13)
                    )
                case .dots:
                    Self.drawDots(
                        in: &context,
                        size: size,
                        spacing: AppTheme.backgroundGridSpacing,
                        color: palette.border.opacity(0.42)
                    )
                }
                if let cutout {
                    // 区域以全局坐标上报，转换到本视图坐标后再抠除。
                    Self.eraseCutout(
                        cutout.frame.offsetBy(dx: -origin.x, dy: -origin.y),
                        inset: cutout.inset,
                        feather: cutout.feather,
                        in: &context,
                        size: size
                    )
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    static func drawGrid(
        in context: inout GraphicsContext,
        size: CGSize,
        spacing: CGFloat,
        color: Color
    ) {
        var path = Path()
        for x in stride(from: CGFloat.zero, through: size.width, by: spacing) {
            path.move(to: CGPoint(x: x, y: 0))
            path.addLine(to: CGPoint(x: x, y: size.height))
        }
        for y in stride(from: CGFloat.zero, through: size.height, by: spacing) {
            path.move(to: CGPoint(x: 0, y: y))
            path.addLine(to: CGPoint(x: size.width, y: y))
        }
        context.stroke(path, with: .color(color), lineWidth: 0.5)
    }

    /// 点落在网格交点上，与网格共用同一套坐标，横格本的线仍然穿过点。
    static func drawDots(
        in context: inout GraphicsContext,
        size: CGSize,
        spacing: CGFloat,
        color: Color
    ) {
        var path = Path()
        let radius = AppTheme.backgroundDotRadius
        for x in stride(from: CGFloat.zero, through: size.width, by: spacing) {
            for y in stride(from: CGFloat.zero, through: size.height, by: spacing) {
                path.addEllipse(in: CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2))
            }
        }
        context.fill(path, with: .color(color))
    }

    /// 用 destinationOut 把纸面区域内已画好的图案擦掉。
    /// `inset` 让图案从区域边缘向内多伸一段，之后再用 `feather` 长度淡出。
    private static func eraseCutout(
        _ cutout: CGRect,
        inset: CGFloat,
        feather: CGFloat,
        in context: inout GraphicsContext,
        size: CGSize
    ) {
        let eraseRect = CGRect(
            x: 0,
            y: cutout.minY + inset - feather,
            width: size.width,
            height: cutout.height - (inset - feather) * 2
        )
        guard eraseRect.height > 0 else { return }
        let featherFraction = min(feather / eraseRect.height, 0.5)

        context.blendMode = .destinationOut
        context.fill(
            Path(eraseRect),
            with: .linearGradient(
                Gradient(stops: [
                    .init(color: featherFraction > 0 ? .clear : .black, location: 0),
                    .init(color: .black, location: featherFraction),
                    .init(color: .black, location: 1 - featherFraction),
                    .init(color: featherFraction > 0 ? .clear : .black, location: 1)
                ]),
                startPoint: CGPoint(x: 0, y: eraseRect.minY),
                endPoint: CGPoint(x: 0, y: eraseRect.maxY)
            )
        )
        context.blendMode = .normal
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

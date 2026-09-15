//
//  RuledEntrySheet.swift
//  Egangnal
//

import SwiftUI

/// 横格本纸面：把词条排成“纸上的行”。
///
/// 每行两个词条，行高固定为两格背景网格；行号列、页边线、横线与纸面自己的网格
/// 由本视图统一绘制，词条内容由调用方提供，因此单词本与词库共用同一张纸，
/// 各自只关心自己的词条视图。线条样式与是否画网格也由调用方按自己页面的偏好传入，
/// 纸面本身不读个性化设置，两页的选择才不会互相串。
///
/// 纸面横向铺满滚动区（调用方把滚动区拉到窗口两边），行内容再按 `horizontalInset` 收进来，
/// 这样线条通到窗口边缘而文字仍与页面其它内容左对齐。
///
/// 网格的处理：背景网格在纸面所在的滚动区内被抠掉（调用方用 `ruledSheetRegion(_:)` 登记），
/// 「对齐实线」「虚线」两种样式由纸面自己重画一套随内容滚动的网格，横线永远落在网格线上；
/// 「局部隐格」则让纸面留白。纸面网格的横向相位按全局坐标计算，与窗口背景网格的竖线同相。
struct RuledEntrySheet<Item, Cell: View>: View {
    let items: [Item]
    let lineStyle: RuledLineStyle
    /// 页面背景是否有图案；没有图案时纸面也不重画网格，否则纸面会比页面"多出"一层格子。
    let showsGrid: Bool
    /// 行内容距纸面左右边缘的距离，通常等于页面的内容内边距。
    var horizontalInset: CGFloat = AppTheme.contentPadding
    /// 最后一行之后的空白纸面高度，用来给悬浮按钮让位。取网格间距的整数倍，纸面网格才不会错相。
    var bottomInset: CGFloat = 0
    @ViewBuilder let cell: (Item) -> Cell

    var body: some View {
        let rows = RuledSheetGeometry.rows(of: items)
        LazyVStack(spacing: 0) {
            ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                RuledEntryRow(
                    number: index + 1,
                    lineStyle: lineStyle,
                    showsGrid: showsGrid,
                    horizontalInset: horizontalInset,
                    leading: cell(row.leading),
                    trailing: row.trailing.map(cell)
                )
            }

            if bottomInset > 0 {
                RuledSheetPaper(
                    lineStyle: lineStyle,
                    showsGrid: showsGrid,
                    drawsRule: false,
                    horizontalInset: horizontalInset
                )
                .frame(height: bottomInset)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("ruledSheet")
    }
}

struct RuledSheetRow<Item> {
    let leading: Item
    let trailing: Item?
}

/// 纸面的纯几何规则，独立出来便于单测。
enum RuledSheetGeometry {
    /// 每行两个词条；词条数为奇数时最后一行右侧留空。
    static func rows<Item>(of items: [Item]) -> [RuledSheetRow<Item>] {
        stride(from: 0, to: items.count, by: 2).map { index in
            RuledSheetRow(
                leading: items[index],
                trailing: index + 1 < items.count ? items[index + 1] : nil
            )
        }
    }

    /// 纸面网格竖线在本地坐标中的起点：让竖线落在全局 x 为网格间距整数倍的位置。
    static func gridPhase(globalMinX: CGFloat) -> CGFloat {
        let spacing = AppTheme.backgroundGridSpacing
        let remainder = globalMinX.truncatingRemainder(dividingBy: spacing)
        if remainder == 0 { return 0 }
        return remainder > 0 ? spacing - remainder : -remainder
    }

    /// 页边线的本地 x：贴着行号列的右缘。
    static func marginX(horizontalInset: CGFloat) -> CGFloat {
        horizontalInset + AppTheme.ruledNumberColumnWidth
    }

    /// 两个词条格之间的竖线：取内容区中点，再吸附到最近的网格竖线上，与页边线一样“长在格子上”。
    /// 极窄宽度下第一个格子至少保留一格，否则单词没有落笔的地方。
    static func dividerX(
        paperWidth: CGFloat,
        horizontalInset: CGFloat,
        gridPhase: CGFloat
    ) -> CGFloat {
        let spacing = AppTheme.backgroundGridSpacing
        let marginX = marginX(horizontalInset: horizontalInset)
        let midpoint = marginX + (paperWidth - horizontalInset - marginX) / 2
        let snapped = gridPhase + ((midpoint - gridPhase) / spacing).rounded() * spacing
        return max(snapped, marginX + spacing)
    }
}

/// 纸面的一行：行号 + 两个词条格，底部一条横线。
private struct RuledEntryRow<Cell: View>: View {
    @Environment(\.appPalette) private var palette

    let number: Int
    let lineStyle: RuledLineStyle
    let showsGrid: Bool
    let horizontalInset: CGFloat
    let leading: Cell
    let trailing: Cell?

    var body: some View {
        GeometryReader { proxy in
            let phase = RuledSheetGeometry.gridPhase(globalMinX: proxy.frame(in: .global).minX)
            let marginX = RuledSheetGeometry.marginX(horizontalInset: horizontalInset)
            let dividerX = RuledSheetGeometry.dividerX(
                paperWidth: proxy.size.width,
                horizontalInset: horizontalInset,
                gridPhase: phase
            )

            HStack(spacing: 0) {
                Text(String(format: "%02d", number))
                    .font(.system(size: AppTheme.ruledNumberFontSize, design: .monospaced))
                    .foregroundStyle(palette.tertiaryText)
                    .padding(.trailing, AppTheme.ruledNumberTrailingInset)
                    .padding(.bottom, AppTheme.ruledTextBottomInset + 2)
                    .frame(width: marginX, height: AppTheme.ruledRowHeight, alignment: .bottomTrailing)
                    .accessibilityHidden(true)

                slot(leading)
                    .frame(width: max(dividerX - marginX, 0))

                slot(trailing)
                    .frame(maxWidth: .infinity)

                Color.clear
                    .frame(width: horizontalInset)
            }
        }
        .frame(height: AppTheme.ruledRowHeight)
        .background {
            RuledSheetPaper(
                lineStyle: lineStyle,
                showsGrid: showsGrid,
                drawsRule: true,
                horizontalInset: horizontalInset
            )
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("ruledSheet.row.\(number)")
    }

    @ViewBuilder
    private func slot(_ content: Cell?) -> some View {
        if let content {
            content
                .padding(.leading, AppTheme.ruledCellLeadingInset)
                .padding(.trailing, AppTheme.ruledCellTrailingInset)
                .padding(.bottom, AppTheme.ruledTextBottomInset)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
        } else {
            Color.clear
        }
    }
}

/// 纸面底层：纸面网格、页边线、词条格之间的竖线与横线。
private struct RuledSheetPaper: View {
    @Environment(\.appPalette) private var palette

    let lineStyle: RuledLineStyle
    let showsGrid: Bool
    let drawsRule: Bool
    let horizontalInset: CGFloat

    var body: some View {
        GeometryReader { proxy in
            let phase = RuledSheetGeometry.gridPhase(globalMinX: proxy.frame(in: .global).minX)
            Canvas { context, size in
                if showsGrid && lineStyle.drawsSheetGrid {
                    drawSheetGrid(in: &context, size: size, phase: phase)
                }
                drawVerticalRules(in: &context, size: size, phase: phase)
                if drawsRule {
                    drawRule(in: &context, size: size)
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    /// 行内部的横向网格线（顶边与底边让位给横线）与全局同相的竖线。
    /// 纸面上只重画网格，不重画点阵：横格本的横线已经把行分开，点阵在这里没有意义。
    private func drawSheetGrid(in context: inout GraphicsContext, size: CGSize, phase: CGFloat) {
        let spacing = AppTheme.backgroundGridSpacing
        var grid = Path()
        var y = spacing
        while y < size.height - 0.5 {
            grid.move(to: CGPoint(x: 0, y: y))
            grid.addLine(to: CGPoint(x: size.width, y: y))
            y += spacing
        }
        var x = phase
        while x <= size.width {
            grid.move(to: CGPoint(x: x, y: 0))
            grid.addLine(to: CGPoint(x: x, y: size.height))
            x += spacing
        }
        context.stroke(grid, with: .color(palette.border.opacity(0.13)), lineWidth: 0.5)
    }

    /// 页边线用页边色；词条格之间的竖线用横线色。半像素偏移让 1 pt 线不被反锯齿拆成两条。
    private func drawVerticalRules(in context: inout GraphicsContext, size: CGSize, phase: CGFloat) {
        let marginX = RuledSheetGeometry.marginX(horizontalInset: horizontalInset) + 0.5
        var margin = Path()
        margin.move(to: CGPoint(x: marginX, y: 0))
        margin.addLine(to: CGPoint(x: marginX, y: size.height))
        context.stroke(margin, with: .color(palette.ruledMargin), lineWidth: 1)

        guard drawsRule else { return }
        let dividerX = RuledSheetGeometry.dividerX(
            paperWidth: size.width,
            horizontalInset: horizontalInset,
            gridPhase: phase
        ) + 0.5
        var divider = Path()
        divider.move(to: CGPoint(x: dividerX, y: 0))
        divider.addLine(to: CGPoint(x: dividerX, y: size.height))
        context.stroke(divider, with: .color(palette.ruledLine), lineWidth: AppTheme.ruledLineWidth)
    }

    private func drawRule(in context: inout GraphicsContext, size: CGSize) {
        var rule = Path()
        let ruleY = size.height - AppTheme.ruledLineWidth / 2
        rule.move(to: CGPoint(x: 0, y: ruleY))
        rule.addLine(to: CGPoint(x: size.width, y: ruleY))
        context.stroke(
            rule,
            with: .color(palette.ruledLine),
            style: StrokeStyle(
                lineWidth: AppTheme.ruledLineWidth,
                dash: lineStyle == .dashed ? AppTheme.ruledDashPattern : []
            )
        )
    }
}

private extension RuledLineStyle {
    /// 「局部隐格」把纸面留白；另外两种样式在纸面上重画网格，让横线始终对齐网格。
    var drawsSheetGrid: Bool {
        self != .gridCutout
    }
}

// MARK: - 纸面区域登记

/// 横格本所在滚动区在窗口中的位置（全局坐标）以及背景图案的处理参数，
/// 供 `WorkspaceBackground` 抠掉该区域的背景图案。
struct RuledSheetRegion: Equatable, Sendable {
    let frame: CGRect
    /// 背景图案从区域边缘向内延伸的距离。纸面自己重画网格时为 0（边缘硬切）；
    /// 纸面留白时延伸一段再淡出，让纸面像是"放在"网格上而不是"挖掉"网格。
    let inset: CGFloat
    /// 延伸段末端的淡出长度。
    let feather: CGFloat
}

struct RuledSheetRegionPreferenceKey: PreferenceKey {
    static let defaultValue: RuledSheetRegion? = nil

    static func reduce(value: inout RuledSheetRegion?, nextValue: () -> RuledSheetRegion?) {
        value = nextValue() ?? value
    }
}

private struct RuledSheetRegionReporter: ViewModifier {
    /// 当前页面横格本的线条样式；nil 表示本页没有在用横格本，不登记区域。
    let lineStyle: RuledLineStyle?

    func body(content: Content) -> some View {
        content.background {
            if let lineStyle {
                GeometryReader { proxy in
                    let leavesPaperBlank = lineStyle == .gridCutout
                    Color.clear.preference(
                        key: RuledSheetRegionPreferenceKey.self,
                        value: RuledSheetRegion(
                            frame: proxy.frame(in: .global),
                            inset: leavesPaperBlank ? AppTheme.ruledGridCutoutInset : 0,
                            feather: leavesPaperBlank ? AppTheme.ruledGridFeather : 0
                        )
                    )
                }
            }
        }
    }
}

extension View {
    /// 把本视图（应当是承载纸面的滚动区）登记为横格本区域。
    /// 登记滚动区而不是纸面本身：纸面比视口高，滚动后会伸到页眉底下，抠网格必须以视口为准。
    /// 传入本页的线条样式；传 nil 表示本页未启用横格本，不登记，背景网格保持完整。
    func ruledSheetRegion(_ lineStyle: RuledLineStyle?) -> some View {
        modifier(RuledSheetRegionReporter(lineStyle: lineStyle))
    }
}

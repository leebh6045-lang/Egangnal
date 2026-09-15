//
//  EntryFieldsLayout.swift
//  Egangnal
//

import SwiftUI

/// 把若干字段横向排布，长文本只在自己的区域内换行。
///
/// 单词本（单词 + 中文意思）与词库（单词 + 词性词义）共用这套排布：
/// 默认样式下两个字段等宽、顶部对齐；横格样式下按比例分配宽度并对齐首行基线，
/// 让 26 pt 的单词与 20 pt 的词义像写在同一条线上。
struct EntryFieldsLayout: Layout {
    let spacing: CGFloat
    /// 各字段的宽度比。为空或数量不足时，缺省的字段按 1 计。
    var proportions: [CGFloat] = []
    var alignsBaselines = false

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {
        guard !subviews.isEmpty else { return .zero }

        let idealWidth = subviews
            .map { $0.sizeThatFits(.unspecified).width }
            .reduce(0, +) + spacing * CGFloat(max(subviews.count - 1, 0))
        let resolvedWidth = proposal.width ?? idealWidth
        let widths = fieldWidths(totalWidth: resolvedWidth, count: subviews.count)
        let placement = verticalPlacement(for: subviews, widths: widths)

        return CGSize(width: resolvedWidth, height: placement.height)
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        guard !subviews.isEmpty else { return }

        let widths = fieldWidths(totalWidth: bounds.width, count: subviews.count)
        let placement = verticalPlacement(for: subviews, widths: widths)
        var x = bounds.minX

        for (index, subview) in subviews.enumerated() {
            subview.place(
                at: CGPoint(x: x, y: bounds.minY + placement.offsets[index]),
                anchor: .topLeading,
                proposal: ProposedViewSize(width: widths[index], height: nil)
            )
            x += widths[index] + spacing
        }
    }

    /// 按比例切分总宽度；比例缺省为等分。
    static func fieldWidths(
        totalWidth: CGFloat,
        count: Int,
        spacing: CGFloat,
        proportions: [CGFloat]
    ) -> [CGFloat] {
        guard count > 0 else { return [] }
        let available = max(totalWidth - spacing * CGFloat(count - 1), 0)
        let weights = (0..<count).map { index in
            index < proportions.count ? max(proportions[index], 0) : 1
        }
        let totalWeight = weights.reduce(0, +)
        guard totalWeight > 0 else {
            return Array(repeating: available / CGFloat(count), count: count)
        }
        return weights.map { available * $0 / totalWeight }
    }

    private func fieldWidths(totalWidth: CGFloat, count: Int) -> [CGFloat] {
        Self.fieldWidths(
            totalWidth: totalWidth,
            count: count,
            spacing: spacing,
            proportions: proportions
        )
    }

    /// 每个字段的纵向偏移与整体高度。
    /// 对齐基线时，基线位置最低的字段决定其余字段要下移多少。
    private func verticalPlacement(
        for subviews: Subviews,
        widths: [CGFloat]
    ) -> (offsets: [CGFloat], height: CGFloat) {
        let dimensions = zip(subviews, widths).map { subview, width in
            subview.dimensions(in: ProposedViewSize(width: width, height: nil))
        }
        guard alignsBaselines else {
            return (
                Array(repeating: 0, count: dimensions.count),
                dimensions.map(\.height).max() ?? 0
            )
        }

        let baselines = dimensions.map { $0[.firstTextBaseline] }
        let deepestBaseline = baselines.max() ?? 0
        let offsets = baselines.map { deepestBaseline - $0 }
        let height = zip(dimensions, offsets)
            .map { $0.height + $1 }
            .max() ?? 0
        return (offsets, height)
    }
}

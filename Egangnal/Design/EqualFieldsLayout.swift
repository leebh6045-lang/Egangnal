//
//  EqualFieldsLayout.swift
//  Egangnal
//

import SwiftUI

/// 把若干字段等宽排布，长文本只在自己的区域内换行。
///
/// 单词本（单词 + 中文意思）与词库（单词 + 词性词义）共用这套排布：
/// 每个词条占网格的一半，词条内两个字段再各占一半，合起来就是四等分。
struct EqualFieldsLayout: Layout {
    let spacing: CGFloat

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
        let fieldWidth = widthPerField(totalWidth: resolvedWidth, count: subviews.count)
        let fieldProposal = ProposedViewSize(width: fieldWidth, height: nil)
        let height = subviews
            .map { $0.sizeThatFits(fieldProposal).height }
            .max() ?? 0

        return CGSize(width: resolvedWidth, height: height)
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        guard !subviews.isEmpty else { return }

        let fieldWidth = widthPerField(totalWidth: bounds.width, count: subviews.count)
        let fieldProposal = ProposedViewSize(width: fieldWidth, height: nil)

        for (index, subview) in subviews.enumerated() {
            let x = bounds.minX + CGFloat(index) * (fieldWidth + spacing)
            subview.place(
                at: CGPoint(x: x, y: bounds.minY),
                anchor: .topLeading,
                proposal: fieldProposal
            )
        }
    }

    private func widthPerField(totalWidth: CGFloat, count: Int) -> CGFloat {
        let totalSpacing = spacing * CGFloat(max(count - 1, 0))
        return max((totalWidth - totalSpacing) / CGFloat(max(count, 1)), 0)
    }
}

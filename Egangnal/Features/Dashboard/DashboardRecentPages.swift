//
//  DashboardRecentPages.swift
//  Egangnal
//

import SwiftUI

/// 语言卡片下方的只读摘要；这些标签刻意不使用 `Button`，
/// 避免暗示可导航。
struct DashboardRecentPages: View {
    @Environment(\.appPalette) private var palette

    let state: DashboardStore.State
    let availableWidth: CGFloat

    var body: some View {
        HStack(spacing: 10) {
            Text("最近的页")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(palette.tertiaryText)
                .fixedSize()

            content
        }
        .frame(
            width: availableWidth,
            height: availableWidth < 560 ? 40 : 44,
            alignment: .leading
        )
        .overlay(alignment: .top) {
            Rectangle()
                .fill(palette.border.opacity(0.38))
                .frame(height: 1)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("dashboard.recentPages")
    }

    @ViewBuilder
    private var content: some View {
        switch state {
        case .loading:
            statusText("正在读取")
        case let .loaded(pages):
            if pages.isEmpty {
                statusText("暂无收录")
            } else {
                ForEach(visiblePages(from: pages)) { page in
                    recentPage(page)
                }
            }
        case .unavailable:
            statusText("暂时无法读取")
        }
    }

    private func recentPage(_ page: DashboardRecentPage) -> some View {
        Text("\(page.title) · \(page.wordCount) 词")
            .font(.subheadline.weight(.medium))
            .foregroundStyle(palette.secondaryText)
            .lineLimit(1)
            .minimumScaleFactor(0.82)
            .padding(.horizontal, 12)
            .frame(minWidth: itemMinimumWidth, minHeight: 34)
            .background(palette.panel.opacity(0.56), in: .capsule)
            .overlay {
                Capsule()
                    .stroke(palette.border.opacity(0.68), lineWidth: 1)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(page.title)，收录 \(page.wordCount) 个单词")
            .accessibilityIdentifier("dashboard.recentPage.\(page.id)")
    }

    private var itemMinimumWidth: CGFloat {
        availableWidth < 560 ? 104 : 126
    }

    private func statusText(_ text: String) -> some View {
        Text(text)
            .font(.subheadline)
            .foregroundStyle(palette.tertiaryText)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityIdentifier("dashboard.recentPages.status")
    }

    /// 最小窗口保留未归档摘要，只减少一个日期页，
    /// 避免关键信息被截掉。
    private func visiblePages(
        from pages: [DashboardRecentPage]
    ) -> [DashboardRecentPage] {
        guard availableWidth < 560, pages.count > 3 else {
            return Array(pages.prefix(4))
        }
        guard let unarchived = pages.first(where: { $0.kind == .unarchived }) else {
            return Array(pages.prefix(3))
        }
        return Array(pages.prefix(2)) + [unarchived]
    }
}

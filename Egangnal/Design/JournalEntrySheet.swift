//
//  JournalEntrySheet.swift
//  Egangnal
//

import SwiftUI

/// 手帐纸面：按组排列的词条列表。
///
/// 与横格本相反，它不画贯通的线：每组一个彩色圆点加标题，每条一个项目符号，
/// 两栏靠左。它是单词本的"个人空间"排版，集词阁不使用。
/// 词条内容由调用方提供，本视图只负责分组、项目符号与行高。
struct JournalEntrySheet<Item: Identifiable, Cell: View>: View {
    @Environment(\.appPalette) private var palette

    let sections: [JournalSection<Item>]
    let accent: Color
    /// 末尾留给悬浮按钮的空白。
    var bottomInset: CGFloat = 0
    @ViewBuilder let cell: (Item) -> Cell

    var body: some View {
        LazyVStack(alignment: .leading, spacing: AppTheme.journalSectionSpacing) {
            ForEach(sections) { section in
                VStack(alignment: .leading, spacing: AppTheme.journalHeaderSpacing) {
                    if let title = section.title {
                        header(title: title, subtitle: section.subtitle)
                    }

                    LazyVGrid(
                        columns: [
                            GridItem(.flexible(), spacing: AppTheme.journalColumnSpacing, alignment: .leading),
                            GridItem(.flexible(), alignment: .leading)
                        ],
                        alignment: .leading,
                        spacing: 0
                    ) {
                        ForEach(section.items) { item in
                            row(item)
                        }
                    }
                }
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("journalSheet.section.\(section.id)")
            }
        }
        .padding(.top, AppTheme.journalTopInset)
        .padding(.bottom, bottomInset)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("journalSheet")
    }

    private func header(title: String, subtitle: String?) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Circle()
                .fill(accent)
                .frame(width: AppTheme.journalHeaderDotSize, height: AppTheme.journalHeaderDotSize)
                .accessibilityHidden(true)
            Text(title)
                .font(.system(size: AppTheme.journalHeaderFontSize, weight: .semibold, design: .rounded))
                .foregroundStyle(palette.secondaryText)
            if let subtitle {
                Text(subtitle)
                    .font(.system(size: AppTheme.journalHeaderSubtitleFontSize, design: .rounded))
                    .foregroundStyle(palette.tertiaryText)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func row(_ item: Item) -> some View {
        HStack(alignment: .center, spacing: AppTheme.journalBulletSpacing) {
            Text("•")
                .font(.system(size: AppTheme.journalBulletFontSize, design: .rounded))
                .foregroundStyle(palette.tertiaryText)
                .frame(width: AppTheme.journalBulletWidth, alignment: .center)
                .accessibilityHidden(true)
            cell(item)
        }
        .frame(maxWidth: .infinity, minHeight: AppTheme.journalRowHeight, alignment: .leading)
    }
}

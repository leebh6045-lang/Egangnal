//
//  EntryFieldArrangement.swift
//  Egangnal
//

import SwiftUI

/// 词条内字段（单词、词义）的排布形态，由页面的排版样式派生。
///
/// 单词本与集词阁的词条视图都只按它配置对齐、宽度比、基线、行数与字体气质，
/// 不直接判断排版样式；日后某一页新增排版样式时，先在这里回答“字段怎么排”，
/// 再决定用哪个网格容器。
enum EntryFieldArrangement: Equatable, Sendable {
    /// 默认样式：字段等宽、文字居中、词条自带最小高度。
    case centered
    /// 横格样式：字段靠左、按比例分配宽度、首行基线对齐、单行截断，高度由纸面行高决定。
    case ruled
    /// 手帐样式：与横格同样靠左、比例分宽、基线对齐、单行；圆体字，高频词用荧光笔而不是变色。
    case journal

    var textAlignment: TextAlignment {
        switch self {
        case .centered: .center
        case .ruled, .journal: .leading
        }
    }

    var frameAlignment: Alignment {
        switch self {
        case .centered: .center
        case .ruled, .journal: .leading
        }
    }

    /// 词条行里编辑、收藏等控件相对字段的纵向对齐。
    /// 横格下字段贴着横线落笔，控件也贴底，才不会悬在半空。
    var controlsAlignment: VerticalAlignment {
        switch self {
        case .centered, .journal: .center
        case .ruled: .bottom
        }
    }

    var proportions: [CGFloat] {
        switch self {
        case .centered: []
        case .ruled, .journal: AppTheme.ruledFieldProportions
        }
    }

    var alignsBaselines: Bool {
        self != .centered
    }

    /// 横格与手帐的行高固定，词义只能单行；默认样式的单词本允许长释义换行。
    var lineLimit: Int? {
        switch self {
        case .centered: nil
        case .ruled, .journal: 1
        }
    }

    /// 默认样式靠最小高度撑开行距；其它样式的高度由容器统一给定。
    var minHeight: CGFloat? {
        switch self {
        case .centered: AppTheme.entryMinHeight
        case .ruled, .journal: nil
        }
    }

    /// 字体气质：手帐用圆体表达“个人的本子”，其余沿用系统默认。
    var fontDesign: Font.Design {
        switch self {
        case .journal: .rounded
        case .centered, .ruled: .default
        }
    }

    /// 高频词的强调方式：手帐用一笔荧光笔划过，其余样式把单词染成强调色。
    var emphasizesFrequencyWithMarker: Bool {
        self == .journal
    }
}

extension WordBookLayoutStyle {
    var fieldArrangement: EntryFieldArrangement {
        switch self {
        case .standard: .centered
        case .ruled: .ruled
        case .journal: .journal
        }
    }
}

extension LexiconLayoutStyle {
    var fieldArrangement: EntryFieldArrangement {
        switch self {
        case .standard: .centered
        case .ruled: .ruled
        }
    }
}

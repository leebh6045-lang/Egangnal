//
//  AppPersonalization.swift
//  Egangnal
//

import SwiftUI

/// 单词本词条区的排版样式。
///
/// 与 `LexiconLayoutStyle` 刻意分开：两页日后会各自增加排列方式，
/// 共用一个枚举会让一页新增样式时另一页也被迫处理它。
enum WordBookLayoutStyle: String, CaseIterable, Identifiable, Sendable {
    /// 两栏四等分、文字居中的原有排版。
    case standard
    /// 横格本：横线、行号与页边线把词条排成纸上的行。
    case ruled
    /// 手帐：按日期分组、项目符号、荧光笔标记高频词，圆体字。
    case journal

    var id: Self { self }

    var title: String {
        switch self {
        case .standard:
            "默认"
        case .ruled:
            "横格本"
        case .journal:
            "手帐"
        }
    }
}

/// 集词阁词条区的排版样式，拆分理由见 `WordBookLayoutStyle`。
enum LexiconLayoutStyle: String, CaseIterable, Identifiable, Sendable {
    case standard
    case ruled

    var id: Self { self }

    var title: String {
        switch self {
        case .standard:
            "默认"
        case .ruled:
            "横格本"
        }
    }
}

/// 横格本的线条样式。
///
/// 它只描述"横线长什么样、与背景网格怎样区分"。枚举由单词本与集词阁共用，
/// 但两页各自保存一份选择：一页改成「局部隐格」不能让另一页的纸面也留白。
enum RuledLineStyle: String, CaseIterable, Identifiable, Sendable {
    /// 横线落在背景网格线上，用更粗、更深、不同色相的实线把它从网格里提出来。
    case alignedSolid
    /// 横线改为短划虚线，与实线网格一眼可分。
    case dashed
    /// 纸面范围内不画网格，只留横线。
    case gridCutout

    var id: Self { self }

    var title: String {
        switch self {
        case .alignedSolid:
            "对齐实线"
        case .dashed:
            "虚线"
        case .gridCutout:
            "局部隐格"
        }
    }
}

/// 页面背景图案。每个页面各自保存一份，没有全局开关。
enum PageBackgroundPattern: String, CaseIterable, Identifiable, Sendable {
    case none
    case grid
    /// 点阵：网格交点处的细点，手帐纸面的标准图案。与网格同一套坐标，横格本仍能对齐。
    case dots

    var id: Self { self }

    var title: String {
        switch self {
        case .none:
            "无"
        case .grid:
            "网格"
        case .dots:
            "点阵"
        }
    }
}

/// 背景图案的归属页面。首页（含设置页）一份，三个功能页各一份。
/// 调用方必须显式指明页面：改动任何一页的偏好都不能影响其它页，新页面也不能悄悄继承别页的设置。
enum PageBackgroundScope: CaseIterable, Sendable {
    case dashboard
    case wordBook
    case lexicon
    case wordQuiz
}

/// 单词本页面的全部个性化项。
struct WordBookPersonalization: Equatable, Sendable {
    var layout: WordBookLayoutStyle = .standard
    var ruledLineStyle: RuledLineStyle = .alignedSolid
    var backgroundPattern: PageBackgroundPattern = .grid
    /// 左上角的一片暖色台灯光。
    var showsLamp = false
}

/// 集词阁页面的全部个性化项。
struct LexiconPersonalization: Equatable, Sendable {
    var layout: LexiconLayoutStyle = .standard
    var ruledLineStyle: RuledLineStyle = .alignedSolid
    var backgroundPattern: PageBackgroundPattern = .grid
    /// 检索带下方两角的页眉词（本页首尾词条）。
    var showsGuideWords = false
    /// 右下角的藏书章水印。
    var showsStamp = false
}

/// 单词刷页面的个性化项。
struct WordQuizPersonalization: Equatable, Sendable {
    var backgroundPattern: PageBackgroundPattern = .grid
}

/// 全部个性化偏好的只读快照，经环境值注入页面。
///
/// 按页面分组而不是平铺：用户在设置里按页调整，任何一页的偏好都不能"顺带"改变另一页；
/// 分组后给某一页新增选项只需要改该页的结构体，视图也只读自己那一组。
struct AppPersonalization: Equatable, Sendable {
    var showsLanguageCardArtwork = true
    /// 首页与设置页共用：设置页是根页面，不属于任何功能页。
    var dashboardBackgroundPattern: PageBackgroundPattern = .grid
    var wordBook = WordBookPersonalization()
    var lexicon = LexiconPersonalization()
    var wordQuiz = WordQuizPersonalization()

    /// 首次启动的默认值：封面图开启，所有页面显示网格，氛围元素关闭。
    static let enabled = AppPersonalization()

    func backgroundPattern(for page: PageBackgroundScope) -> PageBackgroundPattern {
        switch page {
        case .dashboard:
            dashboardBackgroundPattern
        case .wordBook:
            wordBook.backgroundPattern
        case .lexicon:
            lexicon.backgroundPattern
        case .wordQuiz:
            wordQuiz.backgroundPattern
        }
    }
}

private struct AppPersonalizationKey: EnvironmentKey {
    static let defaultValue = AppPersonalization.enabled
}

extension EnvironmentValues {
    var appPersonalization: AppPersonalization {
        get { self[AppPersonalizationKey.self] }
        set { self[AppPersonalizationKey.self] = newValue }
    }
}

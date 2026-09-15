//
//  WorkspaceEntryCeremony.swift
//  Egangnal
//

import Foundation

/// 从首页进入语言空间时的启动页样式。
enum WorkspaceEntryCeremonyStyle: String, CaseIterable, Identifiable, Sendable {
    /// 扉页：页面底色为幕，语言原文名淡入、一条细线展开，再整体上移消失。
    case title
    /// 灯亮：暗场起手，左上角一盏灯亮起，语言名在光里浮现再溶解。
    case lamp

    var id: Self { self }

    var title: String {
        switch self {
        case .title:
            "扉页"
        case .lamp:
            "灯亮"
        }
    }
}

/// 语言空间内功能页之间的切换效果。
enum WorkspaceFeatureTransitionStyle: String, CaseIterable, Identifiable, Sendable {
    /// 只有内容交叉淡入淡出。
    case crossfade
    /// 按功能栏左右顺序滑移 20 pt 并淡入淡出，与胶囊选中块同向。
    case slide
    /// 与从首页进入同一种动作：轻微模糊与缩放中浮现，幅度减半。
    case float

    var id: Self { self }

    var title: String {
        switch self {
        case .crossfade:
            "交叉淡入"
        case .slide:
            "顺序滑移"
        case .float:
            "浮现"
        }
    }
}

/// 启动页多久播一次。
enum WorkspaceEntryCeremonyFrequency: String, CaseIterable, Identifiable, Sendable {
    /// 每次从首页进入都播。
    case always
    /// 距上次进入同一语言超过冷却时间才播。
    case cooldown
    /// 本次运行内、本地日期内第一次进入某语言才播。
    case daily

    var id: Self { self }

    var title: String {
        switch self {
        case .always:
            "每次进入"
        case .cooldown:
            "每隔 30 分钟"
        case .daily:
            "当天首次"
        }
    }
}

/// 启动页的时长与判定规则，纯函数便于单测。
///
/// 时长定为 1.0 秒（2026-09-15 用户在静态预览中定稿）：文字在 25% 时到位，55% 开始离场，
/// 60% 起页面接受输入，用户永远不会被启动页挡住。
enum WorkspaceEntryCeremonyPolicy {
    static let duration: TimeInterval = 1.0
    /// 「每隔 30 分钟」的冷却时间。
    static let cooldown: TimeInterval = 30 * 60
    /// 从这一比例起覆盖层不再截获输入。
    static let inputUnlockFraction: Double = 0.6

    /// 上一次进入同一语言的记录；用于冷却与当天首次的判定。
    struct PreviousEntry: Equatable, Sendable {
        let dateKey: StudyDateKey
        let time: TimeInterval
    }

    /// 系统开启「减少动态效果」时一律不播，与主题波纹的降级规则一致。
    static func shouldPlay(
        frequency: WorkspaceEntryCeremonyFrequency,
        previousEntry: PreviousEntry?,
        now: TimeInterval,
        todayKey: StudyDateKey,
        reduceMotion: Bool
    ) -> Bool {
        guard !reduceMotion else { return false }
        guard let previousEntry else { return true }
        switch frequency {
        case .always:
            return true
        case .cooldown:
            return now - previousEntry.time >= cooldown
        case .daily:
            return previousEntry.dateKey != todayKey
        }
    }
}

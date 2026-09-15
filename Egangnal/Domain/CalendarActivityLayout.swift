//
//  CalendarActivityLayout.swift
//  Egangnal
//

/// 月历上学习反馈底色的连接规则。
///
/// 同一周行内、状态相同的相邻日期把底色连成一条：橙橙相连、灰灰相连；
/// 橙与灰之间、周日与下周一之间必须断开，没有可连接的邻居时收拢为独立的圆。
/// 这是"自律正反馈"的核心视觉。判断全部集中在这里以便单测，渲染层只负责把首尾圆角化。
enum CalendarActivityLayout {
    /// 月历网格每行的天数；`statuses` 必须按 `CalendarMonth.dayGrid` 的顺序逐行排列。
    static let daysPerWeek = 7

    /// 索引 `index` 的日期是否与左侧邻居相连。
    static func connectsLeading(
        at index: Int,
        statuses: [DailyStudyFeedbackStatus]
    ) -> Bool {
        guard statuses.indices.contains(index),
              index % daysPerWeek != 0,
              statuses[index] != .none else {
            return false
        }
        return statuses[index - 1] == statuses[index]
    }

    /// 索引 `index` 的日期是否与右侧邻居相连。
    static func connectsTrailing(
        at index: Int,
        statuses: [DailyStudyFeedbackStatus]
    ) -> Bool {
        guard statuses.indices.contains(index),
              index + 1 < statuses.count,
              (index + 1) % daysPerWeek != 0,
              statuses[index] != .none else {
            return false
        }
        return statuses[index + 1] == statuses[index]
    }
}

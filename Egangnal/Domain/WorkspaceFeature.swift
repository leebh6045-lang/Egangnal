//
//  WorkspaceFeature.swift
//  Egangnal
//

/// 语言工作区内可切换的功能，声明顺序同时决定顶部栏顺序。
enum WorkspaceFeature: String, CaseIterable, Identifiable, Codable, Hashable, Sendable {
    case wordBook
    case lexicon
    case wordQuiz

    var id: Self { self }

    var title: String {
        switch self {
        case .wordBook:
            "单词本"
        case .wordQuiz:
            "单词刷"
        case .lexicon:
            "集词阁"
        }
    }
}

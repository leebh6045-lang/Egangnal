//
//  DashboardStore.swift
//  Egangnal
//

import Foundation
import Observation

/// 协调首页只读摘要的加载；视图无需知道个人词条如何持久化。
@MainActor
@Observable
final class DashboardStore {
    enum State: Equatable {
        case loading
        case loaded([DashboardRecentPage])
        case unavailable(String)
    }

    private let repository: any WordBookRepository

    private(set) var state: State = .loading

    init(repository: any WordBookRepository) {
        self.repository = repository
    }

    /// 每次回到首页都重新读取，确保刚导入或收录的单词
    /// 立即出现在摘要中。
    func reload() {
        do {
            let entries = try LanguageSpace.allCases.map { space in
                (space, try repository.entries(in: space))
            }
            let entriesBySpace = Dictionary(uniqueKeysWithValues: entries)
            state = .loaded(
                DashboardSummaryBuilder.recentPages(from: entriesBySpace)
            )
        } catch {
            state = .unavailable(error.localizedDescription)
        }
    }
}

extension DashboardStore {
    static var preview: DashboardStore {
        DashboardStore(repository: PreviewWordBookRepository())
    }
}

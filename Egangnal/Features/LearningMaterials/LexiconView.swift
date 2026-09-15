//
//  LexiconView.swift
//  Egangnal
//

import SwiftUI

/// 词库页面。
///
/// 沿用单词本的阅读语言（双栏、无边框、点击遮盖），差异集中在检索区、
/// 悬停浮层与每页 50 条的滚动分页上。公共词库只读，页面没有任何写入路径。
struct LexiconView: View {
    @Environment(\.appPalette) private var palette
    @Environment(\.appPersonalization) private var personalization
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let space: LanguageSpace
    let openDashboard: () -> Void

    @State private var store: LexiconCatalogStore
    @State private var cellFrames: [UUID: CGRect] = [:]
    @State private var tooltipSize: CGSize = .zero
    @State private var hoveredEntryID: UUID?
    @State private var pendingEntryID: UUID?
    /// 浮层是否已完成淡入。测量尺寸与显示必须分成两步，
    /// 否则透明度会被测量结果直接改写，出现"啪"地一下的瞬显。
    @State private var isTooltipShown = false
    @State private var tooltipHideTask: Task<Void, Never>?
    /// 立即生效的悬停词块：收录按钮不等悬停延迟。
    @State private var hoveredCellID: UUID?
    @State private var hoverTask: Task<Void, Never>?

    private static let gridSpace = "lexicon.grid"
    private static let topAnchorID = "lexicon.grid.top"

    init(
        space: LanguageSpace,
        repository: any LexiconRepository,
        wordBookRepository: any WordBookRepository,
        shuffle: ShuffleSeedController,
        openDashboard: @escaping () -> Void
    ) {
        self.space = space
        self.openDashboard = openDashboard
        _store = State(
            initialValue: LexiconCatalogStore(
                repository: repository,
                wordBookRepository: wordBookRepository,
                shuffle: shuffle,
                space: space
            )
        )
    }

    var body: some View {
        // 搜索框需要可写绑定；Store 仍是唯一事实来源，写入后由 onChange 触发重新查询。
        @Bindable var store = store

        // 背景由 WorkspaceShell 统一绘制，见 WordBookView 的说明。
        return ZStack(alignment: .topLeading) {
            VStack(spacing: 0) {
                LexiconHeaderRow(
                    title: "\(space.title)集词阁",
                    resultCount: store.page.totalCount,
                    canReshuffle: !store.isSearching,
                    reshuffle: { store.reshuffle() },
                    openDashboard: openDashboard
                )
                LexiconSeparator()

                LexiconFilterBar(
                    selectedLevel: store.level,
                    keyword: $store.keyword,
                    accent: palette.accent(for: space),
                    selectLevel: { store.selectLevel($0) }
                )
                LexiconSeparator()

                if personalization.lexicon.showsGuideWords {
                    LexiconGuideWords(
                        first: store.page.entries.first?.term,
                        last: store.page.entries.last?.term
                    )
                }

                content

                LexiconPaginationBar(
                    page: store.page,
                    goToPrevious: { store.goToPreviousPage() },
                    goToNext: { store.goToNextPage() }
                )
            }

            if personalization.lexicon.showsStamp {
                LexiconLibraryStamp()
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                    // 藏书章避开右下角的清除遮盖按钮：放在它左侧。
                    .padding(.trailing, AppTheme.contentPadding + AppTheme.toggleSize + 12)
                    .padding(.bottom, AppTheme.contentPadding + 8)
            }
        }
        .onAppear {
            if store.page.entries.isEmpty, store.errorMessage == nil {
                store.loadInitial()
            }
        }
        .onChange(of: store.keyword) { _, _ in
            store.keywordDidChange()
        }
        .onChange(of: store.page) { _, _ in
            // 换页、换等级或改关键词后，旧词块的位置信息全部失效。
            clearHover()
        }
        .onDisappear {
            hoverTask?.cancel()
        }
    }

    // MARK: - 内容区

    @ViewBuilder
    private var content: some View {
        if let errorMessage = store.errorMessage {
            LexiconEmptyState(title: "集词阁暂不可用", message: errorMessage)
        } else if store.isEmpty {
            LexiconEmptyState(title: "没有匹配的词条", message: emptyMessage)
        } else {
            gridArea
        }
    }

    private var emptyMessage: String {
        if store.isSearching {
            return "没有匹配「\(store.keyword)」的单词或释义，换个关键词试试。"
        }
        return "「\(store.selectedLevelTitle)」下暂时没有词条。"
    }

    private var layoutStyle: LexiconLayoutStyle {
        personalization.lexicon.layout
    }

    private var gridArea: some View {
        GeometryReader { viewport in
            ScrollViewReader { reader in
                ScrollView {
                    // 滚动锚点必须放在网格**外面**：放进去会占掉第一个格位，
                    // 导致整列词条向下错位一行。
                    VStack(spacing: 0) {
                        Color.clear
                            .frame(height: 0)
                            .id(Self.topAnchorID)

                        entryContainer
                    }
                }
                .ruledSheetRegion(
                    layoutStyle == .ruled ? personalization.lexicon.ruledLineStyle : nil
                )
                .coordinateSpace(name: Self.gridSpace)
                .overlay(alignment: .topLeading) {
                    tooltipLayer(viewport: viewport.size)
                }
                .overlay(alignment: .bottomTrailing) {
                    if store.hasAnyMask {
                        resetMaskButton
                    }
                }
                .overlay(alignment: .bottom) {
                    if let notice = store.notice {
                        noticePill(notice)
                    }
                }
                .onPreferenceChange(LexiconCellFramePreferenceKey.self) { frames in
                    cellFrames = frames
                }
                .onPreferenceChange(LexiconTooltipSizePreferenceKey.self) { size in
                    guard size != .zero else { return }
                    let needsFadeIn = tooltipSize == .zero && hoveredEntryID != nil
                    tooltipSize = size
                    guard needsFadeIn, !isTooltipShown else { return }
                    withAnimation(tooltipFadeAnimation) {
                        isTooltipShown = true
                    }
                }
                .onChange(of: store.page.pageIndex) { _, _ in
                    reader.scrollTo(Self.topAnchorID, anchor: .top)
                }
            }
        }
    }

    /// 排版样式只决定词块被装进哪种容器；词块本身通过 `EntryFieldArrangement` 适配。
    @ViewBuilder
    private var entryContainer: some View {
        switch layoutStyle {
        case .standard:
            LazyVGrid(
                columns: [
                    GridItem(
                        .flexible(),
                        spacing: AppTheme.entryGridColumnSpacing
                    ),
                    GridItem(.flexible())
                ],
                spacing: AppTheme.entryGridRowSpacing
            ) {
                ForEach(store.page.entries) { entry in
                    cell(entry)
                }
            }
            .padding(.horizontal, AppTheme.contentPadding)
            .padding(.top, 20)
            // 为右下角悬浮的清除按钮预留空间，避免遮住最后一行。
            .padding(.bottom, 56)
        case .ruled:
            RuledEntrySheet(
                items: store.page.entries,
                lineStyle: personalization.lexicon.ruledLineStyle,
                showsGrid: personalization.lexicon.backgroundPattern != .none,
                horizontalInset: AppTheme.contentPadding,
                bottomInset: AppTheme.ruledLexiconBottomInset
            ) { entry in
                cell(entry)
            }
        }
    }

    private func cell(_ entry: LexiconEntry) -> some View {
        let display = LexiconGlossFormatter.browsingDisplay(from: entry.gloss)

        return LexiconEntryCell(
            entry: entry,
            display: display,
            arrangement: layoutStyle.fieldArrangement,
            keyword: store.keyword,
            searchMode: store.searchMode,
            accent: palette.accent(for: space),
            isTermMasked: store.isTermMasked(entry),
            isGlossMasked: store.isGlossMasked(entry),
            isHovered: hoveredCellID == entry.id,
            collectionState: store.collectionState(for: entry),
            toggleTerm: { store.toggleTermMask(entry) },
            toggleGloss: { store.toggleGlossMask(entry) },
            collect: { store.toggleCollection(entry) },
            glossHoverChanged: { handleGlossHover(entry: entry, isHovering: $0) }
        )
        .background {
            GeometryReader { proxy in
                Color.clear.preference(
                    key: LexiconCellFramePreferenceKey.self,
                    value: [entry.id: proxy.frame(in: .named(Self.gridSpace))]
                )
            }
        }
        .onHover { isHovering in
            // 词块级悬停只负责收藏按钮的显隐，浮层由词性词义单独触发。
            hoveredCellID = isHovering
                ? entry.id
                : (hoveredCellID == entry.id ? nil : hoveredCellID)
        }
    }

    private func noticePill(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13))
            .foregroundStyle(palette.primaryText)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(palette.panel, in: .capsule)
            .overlay { Capsule().stroke(palette.border, lineWidth: 1) }
            .shadow(color: palette.panelShadow, radius: 10, y: 4)
            .padding(.bottom, 12)
            .allowsHitTesting(false)
            .accessibilityIdentifier("lexicon.notice")
    }

    private var resetMaskButton: some View {
        Button {
            store.clearMasks()
        } label: {
            Image(systemName: "arrow.counterclockwise")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(palette.secondaryText)
                .frame(width: AppTheme.toggleSize, height: AppTheme.toggleSize)
                .background(palette.panel, in: .rect(cornerRadius: 8))
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(palette.border, lineWidth: 1)
                }
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .help("清除本页遮盖")
        .accessibilityLabel("清除本页遮盖")
        .accessibilityIdentifier("lexicon.mask.reset")
        .padding(AppTheme.contentPadding)
    }

    // MARK: - 悬停浮层

    @ViewBuilder
    private func tooltipLayer(viewport: CGSize) -> some View {
        if let entry = hoveredEntry,
           let frame = cellFrames[entry.id] {
            let display = LexiconGlossFormatter.browsingDisplay(from: entry.gloss)
            // 遮盖优先：词义被遮住时浮层不重复显示，避免遮盖失去意义。
            let showsFullGloss = display.isTruncated && !store.isGlossMasked(entry)

            LexiconTooltip(
                entry: entry,
                showsFullGloss: showsFullGloss,
                collectedDates: store.collectionInfo(for: entry).collectedDates
            )
                .fixedSize(horizontal: false, vertical: true)
                .background {
                    GeometryReader { proxy in
                        Color.clear.preference(
                            key: LexiconTooltipSizePreferenceKey.self,
                            value: proxy.size
                        )
                    }
                }
                // 第一帧只用来测量尺寸（透明），测量完成后才在动画里淡入。
                .opacity(isTooltipShown ? 1 : 0)
                .offset(
                    x: tooltipX(cellFrame: frame, viewport: viewport),
                    y: tooltipY(cellFrame: frame, viewport: viewport)
                )
                .allowsHitTesting(false)
                // 淡入淡出完全由 isTooltipShown 驱动：再叠加 transition 会让
                // 透明度被两套动画相乘，观感不可控。
                .transition(.identity)
                .animation(tooltipFadeAnimation, value: isTooltipShown)
        }
    }

    private var hoveredEntry: LexiconEntry? {
        guard let hoveredEntryID else { return nil }
        return store.page.entries.first { $0.id == hoveredEntryID }
    }

    /// 默认贴在词块下方居中；左右越界时收拢进窗口。
    private func tooltipX(cellFrame: CGRect, viewport: CGSize) -> CGFloat {
        let inset = AppTheme.lexiconTooltipEdgeInset
        let width = tooltipSize.width
        let ideal = cellFrame.midX - width / 2
        return min(max(ideal, inset), max(inset, viewport.width - width - inset))
    }

    /// 下方空间不足时翻到词块上方；上下都放不下时贴在可视区内。
    private func tooltipY(cellFrame: CGRect, viewport: CGSize) -> CGFloat {
        let inset = AppTheme.lexiconTooltipEdgeInset
        let gap: CGFloat = 8
        let height = tooltipSize.height

        let below = cellFrame.maxY + gap
        if below + height <= viewport.height - inset {
            return below
        }

        let above = cellFrame.minY - gap - height
        if above >= inset {
            return above
        }

        return min(max(below, inset), max(inset, viewport.height - height - inset))
    }

    private var tooltipFadeAnimation: Animation? {
        reduceMotion
            ? nil
            : .easeOut(duration: AppTheme.lexiconTooltipFadeDuration)
    }

    /// 浮层只由“悬浮在词性词义上”触发，并且需要持续停留一段时间。
    private func handleGlossHover(entry: LexiconEntry, isHovering: Bool) {
        if isHovering {
            hoverTask?.cancel()
            pendingEntryID = entry.id
            hoverTask = Task { @MainActor in
                try? await Task.sleep(for: AppTheme.lexiconTooltipDelay)
                guard !Task.isCancelled, pendingEntryID == entry.id else { return }
                tooltipHideTask?.cancel()
                tooltipHideTask = nil
                // 先以透明状态渲染一帧完成测量，再由回调触发淡入。
                isTooltipShown = false
                tooltipSize = .zero
                hoveredEntryID = entry.id
            }
        } else {
            // 只有离开的正是待显示或正在显示的那个词块时才清除，
            // 避免从 A 移到 B 时把 B 的浮层一起取消。
            if pendingEntryID == entry.id {
                pendingEntryID = nil
                hoverTask?.cancel()
                hoverTask = nil
            }
            if hoveredEntryID == entry.id {
                hideTooltip()
            }
        }
    }

    /// 先淡出，动画结束后再卸载，避免"边淡出边被移除"造成的生硬收尾。
    private func hideTooltip() {
        guard hoveredEntryID != nil || isTooltipShown else { return }
        withAnimation(tooltipFadeAnimation) {
            isTooltipShown = false
        }
        tooltipHideTask?.cancel()
        tooltipHideTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(AppTheme.lexiconTooltipFadeDuration))
            guard !Task.isCancelled, !isTooltipShown else { return }
            hoveredEntryID = nil
        }
    }

    private func clearHover() {
        hoverTask?.cancel()
        hoverTask = nil
        pendingEntryID = nil
        tooltipHideTask?.cancel()
        tooltipHideTask = nil
        hoveredEntryID = nil
        hoveredCellID = nil
        isTooltipShown = false
        // 不能清空 cellFrames / tooltipSize：它们是**布局结果**而不是悬停状态。
        // 清掉之后偏好值没有变化，网格不会再次上报，浮层会一直定位失败——
        // 表现就是"首次进入词库时浮层不出现，点一下分类才恢复"。
    }
}

#Preview {
    LexiconView(
        space: .english,
        repository: PreviewLexiconRepository(),
        wordBookRepository: PreviewWordBookRepository(),
        shuffle: ShuffleSeedController(),
        openDashboard: {}
    )
    .frame(width: 1080, height: 700)
}

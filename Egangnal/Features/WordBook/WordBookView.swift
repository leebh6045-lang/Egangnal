//
//  WordBookView.swift
//  Egangnal
//

import SwiftUI
import UniformTypeIdentifiers

struct WordBookView: View {
    @Environment(\.appPalette) private var palette
    @Environment(\.appPersonalization) private var personalization
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let space: LanguageSpace
    let repository: any WordBookRepository
    let settingsStore: AppSettingsStore
    let shuffle: ShuffleSeedController
    let openWorkspace: () -> Void

    @State private var entries: [WordBookEntrySnapshot] = []
    /// 默认分页的洗牌种子。按日期浏览是一种分组视图，不参与洗牌。
    @State private var shuffleSeed = 0
    @State private var browseMode: WordBookBrowseMode = .all
    @State private var currentPage = 0
    @State private var currentDatePage = 0
    @State private var isEditing = false
    @State private var isImporting = false
    @State private var isExporting = false
    @State private var exportDocument = WordBookTemplateDocument(
        text: WordBookTemplateGenerator.makeTemplate()
    )
    @State private var pendingExportFilename: String?
    @State private var editorDraft: WordBookEditorDraft?
    @State private var pendingDeletion: WordBookEntrySnapshot?
    @State private var notice: WordBookNotice?
    @State private var isToolbarExpanded = false
    @State private var isGuidePresented = false
    @State private var maskState = WordBookMaskState()
    /// 横格本所在滚动区的窗口位置，背景据此抠掉纸面下的网格。
    @State private var ruledSheetRegion: RuledSheetRegion?

    init(
        space: LanguageSpace,
        repository: any WordBookRepository,
        settingsStore: AppSettingsStore,
        shuffle: ShuffleSeedController,
        openWorkspace: @escaping () -> Void
    ) {
        self.space = space
        self.repository = repository
        self.settingsStore = settingsStore
        self.shuffle = shuffle
        self.openWorkspace = openWorkspace
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            WorkspaceBackground(
                page: .wordBook,
                showsLamp: personalization.wordBook.showsLamp,
                gridCutout: gridCutout
            )

            VStack(alignment: .leading, spacing: AppTheme.panelSpacing) {
                header
                noticeArea
                content
                navigation
                    .padding(.trailing, AppTheme.wordBookNavigationClearance)
            }
            .padding(.horizontal, AppTheme.contentPadding)
            .padding(.bottom, AppTheme.contentPadding)
            .padding(.top, contentTopPadding)

            readingControls
                .padding(AppTheme.contentPadding)
        }
        .onPreferenceChange(RuledSheetRegionPreferenceKey.self) { region in
            ruledSheetRegion = region
        }
        .onAppear {
            reloadEntries()
        }
        .onChange(of: browseMode) {
            currentPage = 0
            currentDatePage = 0
            resetMasking()
            // 默认分页始终只读，切换回来时不保留任何编辑状态。
            if browseMode == .all {
                isEditing = false
                editorDraft = nil
            }
        }
        .fileImporter(
            isPresented: $isImporting,
            allowedContentTypes: [WordBookFileType.markdown],
            allowsMultipleSelection: false,
            onCompletion: importDocument
        )
        .fileExporter(
            isPresented: $isExporting,
            document: exportDocument,
            contentType: WordBookFileType.markdown,
            defaultFilename: exportFilename,
            onCompletion: finishExport
        )
        .sheet(item: $editorDraft) { draft in
            WordBookEditorSheet(
                draft: draft,
                tint: palette.accent(for: space),
                save: saveEditorDraft,
                cancel: { editorDraft = nil }
            )
        }
        .alert(item: $pendingDeletion) { entry in
            Alert(
                title: Text("删除“\(entry.term)”？"),
                message: Text("该单词及其所有导入日期记录都会被删除，此操作无法撤销。"),
                primaryButton: .destructive(Text("删除")) {
                    delete(entry)
                },
                secondaryButton: .cancel(Text("取消"))
            )
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 16) {
                Button(action: openWorkspace) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 17, weight: .semibold))
                        .frame(width: 32, height: 32, alignment: .leading)
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.escape, modifiers: [])
                .help("返回总览")
                .accessibilityLabel("返回总览")
                .accessibilityIdentifier("wordBook.back")

                HStack(spacing: 8) {
                    Text("\(space.title)单词本")
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(palette.primaryText)
                        .accessibilityAddTraits(.isHeader)
                        .accessibilityIdentifier("wordBook.\(space.rawValue).title")

                    Button {
                        isGuidePresented.toggle()
                    } label: {
                        Image(systemName: "questionmark.circle")
                            .font(.system(size: 17, weight: .medium))
                            .foregroundStyle(palette.accent(for: space))
                            .frame(width: 28, height: 28)
                    }
                    .buttonStyle(.plain)
                    .help("查看单词本使用说明")
                    .accessibilityLabel("查看单词本使用说明")
                    .accessibilityValue(isGuidePresented ? "已展开" : "已收起")
                    .accessibilityIdentifier("wordBook.guide.toggle")
                    .popover(isPresented: $isGuidePresented, arrowEdge: .trailing) {
                        WordBookGuidePopover(accent: palette.accent(for: space))
                    }
                }

                Spacer(minLength: 16)

                Button(action: toggleToolbar) {
                    Image(systemName: isToolbarExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 14, weight: .semibold))
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(.plain)
                .help(isToolbarExpanded ? "收起功能栏" : "展开功能栏")
                .accessibilityLabel(isToolbarExpanded ? "收起功能栏" : "展开功能栏")
                .accessibilityValue(isToolbarExpanded ? "已展开" : "已收起")
                .accessibilityIdentifier("wordBook.toolbar.toggle")
            }

            if isToolbarExpanded {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 10) {
                        Button("导入", systemImage: "square.and.arrow.down") {
                            isImporting = true
                        }
                        .buttonStyle(.bordered)
                        .help("导入 Markdown 单词文档")
                        .accessibilityIdentifier("wordBook.import")

                        Button("导出模板", systemImage: "square.and.arrow.up") {
                            prepareExport()
                        }
                        .buttonStyle(.bordered)
                        .help("导出当天的空白 Markdown 模板")
                        .accessibilityIdentifier("wordBook.export")

                        if browseMode == .date {
                            Button(
                                isEditing ? "完成" : "编辑",
                                systemImage: isEditing ? "checkmark" : "pencil"
                            ) {
                                isEditing.toggle()
                                if !isEditing {
                                    editorDraft = nil
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(palette.accent(for: space))
                            .accessibilityIdentifier("wordBook.edit.toggle")
                        }

                        if browseMode == .all {
                            Button("换一批", systemImage: "arrow.triangle.2.circlepath") {
                                reshuffle()
                            }
                            .buttonStyle(.bordered)
                            .help("换一批单词")
                            .accessibilityIdentifier("wordBook.reshuffle")
                        }

                        Spacer(minLength: 12)

                        modePicker
                    }

                    if isEditing {
                        HStack {
                            Text("编辑模式")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(palette.secondaryText)
                            Spacer()
                            Button("新增单词", systemImage: "plus") {
                                editorDraft = .newEntry
                            }
                            .buttonStyle(.bordered)
                            .accessibilityIdentifier("wordBook.add")
                        }
                    }
                }
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .clipped()
    }

    private var contentTopPadding: CGFloat {
        // 顶部悬浮栏是覆盖层，功能页面保持原有顶部布局，不为悬浮栏让位。
        AppTheme.contentPadding
    }

    private var layoutStyle: WordBookLayoutStyle {
        personalization.wordBook.layout
    }

    private var gridCutout: RuledSheetRegion? {
        layoutStyle == .ruled ? ruledSheetRegion : nil
    }

    /// 只有默认分页需要手帐按日期分组；按日期浏览本身已是一天一页。
    private var groupsByDate: Bool {
        browseMode == .all
    }

    private var modePicker: some View {
        Picker("浏览方式", selection: $browseMode) {
            ForEach(WordBookBrowseMode.allCases) { mode in
                Text(mode.title).tag(mode)
            }
        }
        .pickerStyle(.segmented)
        .frame(maxWidth: 360)
        .accessibilityIdentifier("wordBook.mode")
    }

    private var noticeArea: some View {
        Group {
            if let notice {
                Label(notice.message, systemImage: notice.systemImage)
                    .font(.callout)
                    .foregroundStyle(notice.isError ? Color.red : palette.grammarAccent)
                    .lineLimit(2)
                    .accessibilityIdentifier("wordBook.notice")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var content: some View {
        switch browseMode {
        case .all:
            entryPanel(
                title: "全部单词",
                subtitle: entries.isEmpty ? nil : "共 \(entries.count) 个",
                displayedEntries: pagedEntries,
                emphasizesFrequency: true,
                emptyTitle: "单词本还是空的",
                emptyMessage: "可以先导出模板，填写后再导入。"
            )
        case .date:
            dateContent
        }
    }

    @ViewBuilder
    private var dateContent: some View {
        if let datePage = selectedDatePage {
            switch datePage {
            case let .date(date):
                entryPanel(
                    title: date.templateText,
                    subtitle: "当天导入 \(entries(on: date).count) 个",
                    displayedEntries: entries(on: date),
                    emphasizesFrequency: false,
                    emptyTitle: "当天没有单词",
                    emptyMessage: "删除后的日期页会自动消失。"
                )
            case .manual:
                entryPanel(
                    title: "未归档单词",
                    subtitle: "手动新增或集词阁收藏 \(manualEntries.count) 个",
                    displayedEntries: manualEntries,
                    emphasizesFrequency: false,
                    emptyTitle: "没有未归档单词",
                    emptyMessage: "手动新增或从集词阁收藏的单词会显示在这里。"
                )
            }
        } else {
            entryPanel(
                title: "按日期浏览",
                subtitle: nil,
                displayedEntries: [],
                emphasizesFrequency: false,
                emptyTitle: "还没有日期记录",
                emptyMessage: "导入符合格式的 Markdown 文档后，会按日期归档。"
            )
        }
    }

    private func entryPanel(
        title: String,
        subtitle: String?,
        displayedEntries: [WordBookEntrySnapshot],
        emphasizesFrequency: Bool,
        emptyTitle: String,
        emptyMessage: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(palette.primaryText)
                if let subtitle {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(palette.secondaryText)
                }
                Spacer()
            }
            .padding(.bottom, 12)

            if displayedEntries.isEmpty {
                WordBookEmptyState(title: emptyTitle, message: emptyMessage)
                    .frame(maxWidth: .infinity, minHeight: AppTheme.wordBookContentMinHeight)
            } else {
                entryContainer(
                    displayedEntries,
                    emphasizesFrequency: emphasizesFrequency,
                    groupsByDate: groupsByDate
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    /// 排版样式只决定词条被装进哪种容器；词条行本身通过 `EntryFieldArrangement` 适配。
    @ViewBuilder
    private func entryContainer(
        _ displayedEntries: [WordBookEntrySnapshot],
        emphasizesFrequency: Bool,
        groupsByDate: Bool
    ) -> some View {
        switch layoutStyle {
        case .standard:
            ScrollView {
                LazyVGrid(
                    columns: [
                        GridItem(
                            .flexible(minimum: 0),
                            spacing: AppTheme.entryGridColumnSpacing,
                            alignment: .top
                        ),
                        GridItem(
                            .flexible(minimum: 0),
                            spacing: AppTheme.entryGridColumnSpacing,
                            alignment: .top
                        )
                    ],
                    alignment: .center,
                    spacing: AppTheme.entryGridRowSpacing
                ) {
                    ForEach(displayedEntries) { entry in
                        entryRow(entry, emphasizesFrequency: emphasizesFrequency)
                    }
                }
                .padding(.top, 8)
                .padding(.bottom, AppTheme.wordBookReadingControlsClearance)
            }
        case .ruled:
            ScrollView {
                RuledEntrySheet(
                    items: displayedEntries,
                    lineStyle: personalization.wordBook.ruledLineStyle,
                    showsGrid: personalization.wordBook.backgroundPattern != .none,
                    horizontalInset: AppTheme.contentPadding,
                    bottomInset: AppTheme.ruledWordBookBottomInset
                ) { entry in
                    entryRow(entry, emphasizesFrequency: emphasizesFrequency)
                }
            }
            // 纸面要通到窗口两边：把滚动区拉出内容内边距，行内容再由纸面自己收回来。
            .padding(.horizontal, -AppTheme.contentPadding)
            .ruledSheetRegion(personalization.wordBook.ruledLineStyle)
        case .journal:
            ScrollView {
                JournalEntrySheet(
                    sections: journalSections(displayedEntries, groupsByDate: groupsByDate),
                    accent: palette.accent(for: space),
                    bottomInset: AppTheme.wordBookReadingControlsClearance
                ) { entry in
                    entryRow(entry, emphasizesFrequency: emphasizesFrequency)
                }
            }
        }
    }

    /// 默认分页按最近出现日期分组；按日期浏览时页面标题已是这一天，不再重复分组标题。
    private func journalSections(
        _ displayedEntries: [WordBookEntrySnapshot],
        groupsByDate: Bool
    ) -> [JournalSection<WordBookEntrySnapshot>] {
        if groupsByDate {
            return WordBookJournal.sections(
                for: displayedEntries,
                today: VocabularyDocumentDate(date: .now)
            )
        }
        return WordBookJournal.singleSection(displayedEntries, id: "page")
    }

    private func entryRow(
        _ entry: WordBookEntrySnapshot,
        emphasizesFrequency: Bool
    ) -> some View {
        WordBookEntryRow(
            entry: entry,
            arrangement: layoutStyle.fieldArrangement,
            frequencyColor: palette.frequencyAccent,
            emphasizesFrequency: emphasizesFrequency,
            isEditing: isEditing,
            isWordVisible: maskState.isWordVisible(entry.id),
            isMeaningVisible: maskState.isMeaningVisible(entry.id),
            toggleWord: {
                maskState.toggleWord(entry.id)
            },
            toggleMeaning: {
                maskState.toggleMeaning(entry.id)
            },
            edit: {
                editorDraft = .editing(entry)
            },
            delete: {
                pendingDeletion = entry
            }
        )
    }

    @ViewBuilder
    private var navigation: some View {
        switch browseMode {
        case .all:
            if pageCount > 0 {
                HStack {
                    Button("上一页", systemImage: "chevron.left") {
                        currentPage -= 1
                        resetMasking()
                    }
                    .disabled(currentPage == 0)
                    .accessibilityIdentifier("wordBook.page.previous")

                    Spacer()

                    Text("第 \(currentPage + 1) / \(pageCount) 页")
                        .font(.callout)
                        .foregroundStyle(palette.secondaryText)
                        .monospacedDigit()
                        .accessibilityLabel("第 \(currentPage + 1) / \(pageCount) 页")
                        .accessibilityValue("第 \(currentPage + 1) / \(pageCount) 页")
                        .accessibilityIdentifier("wordBook.page.status")

                    Spacer()

                    Button("下一页", systemImage: "chevron.right") {
                        currentPage += 1
                        resetMasking()
                    }
                    .disabled(currentPage >= pageCount - 1)
                    .accessibilityIdentifier("wordBook.page.next")
                }
            }
        case .date:
            if !datePages.isEmpty {
                HStack {
                    Button("较新", systemImage: "chevron.left") {
                        currentDatePage -= 1
                        resetMasking()
                    }
                    .disabled(currentDatePage == 0)
                    .accessibilityIdentifier("wordBook.date.previous")

                    Spacer()

                    Text(datePageStatus)
                        .font(.callout)
                        .foregroundStyle(palette.secondaryText)
                        .accessibilityLabel(datePageStatus)
                        .accessibilityValue(datePageStatus)
                        .accessibilityIdentifier("wordBook.date.status")

                    Spacer()

                    Button("较早", systemImage: "chevron.right") {
                        currentDatePage += 1
                        resetMasking()
                    }
                    .disabled(currentDatePage >= datePages.count - 1)
                    .accessibilityIdentifier("wordBook.date.next")
                }
            }
        }
    }

    private var readingControls: some View {
        VStack(spacing: 10) {
            Button(action: resetMasking) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 15, weight: .semibold))
                    .frame(width: AppTheme.toggleSize, height: AppTheme.toggleSize)
            }
            .buttonStyle(.plain)
            .help("显示全部单词和释义")
            .accessibilityLabel("显示全部单词和释义")
            .accessibilityIdentifier("wordBook.mask.reset")

            Button(action: cycleMaskMode) {
                Image(systemName: "eye.slash")
                    .font(.system(size: 15, weight: .semibold))
                    .frame(width: AppTheme.toggleSize, height: AppTheme.toggleSize)
            }
            .buttonStyle(.plain)
            .help(maskState.mode.helpText)
            .accessibilityLabel(maskState.mode.accessibilityLabel)
            .accessibilityValue(maskState.mode.accessibilityValue)
            .accessibilityIdentifier("wordBook.mask.toggle")
        }
        .foregroundStyle(palette.primaryText)
        .background(palette.panel.opacity(0.84), in: .rect(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(palette.border.opacity(0.7), lineWidth: 1)
        }
        .padding(4)
    }

    /// 默认分页使用的顺序：洗牌后每次进入换一批，避免总是从同一批词开始。
    private var browsableEntries: [WordBookEntrySnapshot] {
        WordBookPaging.shuffled(entries, seed: shuffleSeed)
    }

    private var pageCount: Int {
        WordBookPaging.pageCount(itemCount: browsableEntries.count)
    }

    private var pagedEntries: [WordBookEntrySnapshot] {
        WordBookPaging.items(in: browsableEntries, page: currentPage)
    }

    private func reshuffle() {
        shuffle.reshuffle()
        shuffleSeed = shuffle.seed
        currentPage = 0
        resetMasking()
    }

    private func cycleMaskMode() {
        maskState.cycleMode()
    }

    private func toggleToolbar() {
        let willExpand = !isToolbarExpanded
        let animation: Animation? = reduceMotion ? nil : .easeInOut(duration: 0.22)

        withAnimation(animation) {
            isToolbarExpanded = willExpand
            if !willExpand {
                // 功能栏隐藏后同步退出编辑，避免页面保留不可见的编辑状态。
                isEditing = false
                editorDraft = nil
            }
        }
    }

    private func resetMasking() {
        maskState.reset()
    }

    private var manualEntries: [WordBookEntrySnapshot] {
        entries.filter { $0.occurrenceDates.isEmpty }
    }

    private var datePages: [WordBookDatePage] {
        var pages = WordBookPaging.dates(in: entries).map(WordBookDatePage.date)
        if !manualEntries.isEmpty {
            pages.append(.manual)
        }
        return pages
    }

    private var selectedDatePage: WordBookDatePage? {
        guard !datePages.isEmpty else { return nil }
        let safeIndex = min(max(currentDatePage, 0), datePages.count - 1)
        return datePages[safeIndex]
    }

    private var datePageStatus: String {
        guard let selectedDatePage else { return "" }
        let title: String
        switch selectedDatePage {
        case let .date(date):
            title = date.templateText
        case .manual:
            title = "未归档单词"
        }
        return "\(title)  ·  \(currentDatePage + 1) / \(datePages.count)"
    }

    private var exportFilename: String {
        pendingExportFilename ?? filename(
            for: VocabularyDocumentDate(date: .now)
        )
    }

    private func filename(for date: VocabularyDocumentDate) -> String {
        "\(space.rawValue)-word-template-\(date.storageKey).md"
    }

    private func entries(on date: VocabularyDocumentDate) -> [WordBookEntrySnapshot] {
        entries.filter { $0.occurrenceDates.contains(date) }
    }

    private func reloadEntries() {
        resetMasking()
        do {
            shuffleSeed = shuffle.seedForEntry()
            entries = try repository.entries(in: space)
            currentPage = WordBookPaging.clampedPage(currentPage, itemCount: entries.count)
            currentDatePage = min(max(currentDatePage, 0), max(datePages.count - 1, 0))
        } catch {
            entries = []
            show(error: error)
        }
    }

    private func prepareExport() {
        // 同一次导出复用同一个时间点，避免跨午夜时正文和文件名日期不一致。
        let now = Date()
        let calendar = Calendar.current
        let documentDate = VocabularyDocumentDate(date: now, calendar: calendar)
        let template = WordBookTemplateGenerator.makeTemplate(
            for: now,
            calendar: calendar
        )
        let currentExportFilename = filename(for: documentDate)
        pendingExportFilename = currentExportFilename
        exportDocument = WordBookTemplateDocument(text: template)

        do {
            if let url = try settingsStore.exportToPreferredDirectory(
                data: Data(template.utf8),
                preferredFilename: currentExportFilename
            ) {
                notice = .success("模板已导出为 \(url.lastPathComponent)。")
                pendingExportFilename = nil
            } else {
                // 未配置或目录授权失效时，沿用系统保存面板让用户手动选择。
                isExporting = true
            }
        } catch {
            show(error: error)
        }
    }

    private func importDocument(_ result: Result<[URL], Error>) {
        switch result {
        case let .success(urls):
            guard let url = urls.first else { return }
            let canAccess = url.startAccessingSecurityScopedResource()
            defer {
                if canAccess {
                    url.stopAccessingSecurityScopedResource()
                }
            }

            do {
                // 文件完全解析成功后才交给仓储一次性提交。
                let data = try Data(contentsOf: url, options: .mappedIfSafe)
                let document = try WordBookMarkdownParser.parse(data)
                let importResult = try repository.importDocument(
                    document,
                    into: space,
                    sourceFilename: url.lastPathComponent,
                    importedAt: .now
                )
                notice = .success(importMessage(for: importResult))
                // 刷新失败时由 reloadEntries 覆盖成功提示，避免界面伪报可用。
                reloadEntries()
            } catch {
                show(error: error)
            }
        case let .failure(error):
            guard !isUserCancellation(error) else { return }
            show(error: error)
        }
    }

    private func finishExport(_ result: Result<URL, Error>) {
        defer { pendingExportFilename = nil }
        switch result {
        case let .success(url):
            notice = .success("模板已导出为 \(url.lastPathComponent)。")
        case let .failure(error):
            guard !isUserCancellation(error) else { return }
            show(error: error)
        }
    }

    private func saveEditorDraft(term: String, meaning: String) -> String? {
        guard let editorDraft else { return "编辑内容已失效，请重新打开。" }
        do {
            switch editorDraft.kind {
            case .new:
                _ = try repository.addManualEntry(term: term, meaning: meaning, in: space)
                notice = .success("已新增单词“\(term.trimmingCharacters(in: .whitespacesAndNewlines))”。")
            case let .existing(entryID):
                try repository.updateEntry(
                    id: entryID,
                    term: term,
                    meaning: meaning,
                    in: space
                )
                notice = .success("单词条目已更新。")
            }
            self.editorDraft = nil
            reloadEntries()
            return nil
        } catch {
            return errorMessage(for: error)
        }
    }

    private func delete(_ entry: WordBookEntrySnapshot) {
        do {
            try repository.deleteEntry(id: entry.id, in: space)
            notice = .success("已删除单词“\(entry.term)”。")
            reloadEntries()
        } catch {
            show(error: error)
        }
    }

    private func importMessage(for result: WordBookImportResult) -> String {
        if !result.madeChanges {
            return "没有新增内容，已跳过 \(result.skippedDuplicateCount) 条重复记录。"
        }
        return "导入完成：新增 \(result.insertedEntryCount) 个单词、\(result.insertedOccurrenceCount) 条日期记录，跳过 \(result.skippedDuplicateCount) 条重复记录。"
    }

    private func show(error: Error) {
        notice = .error(errorMessage(for: error))
    }

    private func errorMessage(for error: Error) -> String {
        if let localizedError = error as? LocalizedError,
           let description = localizedError.errorDescription {
            return description
        }
        return error.localizedDescription
    }

    private func isUserCancellation(_ error: Error) -> Bool {
        if error is CancellationError {
            return true
        }
        return (error as? CocoaError)?.code == .userCancelled
    }
}

private enum WordBookDatePage: Hashable {
    case date(VocabularyDocumentDate)
    case manual
}

private struct WordBookNotice: Identifiable {
    let id = UUID()
    let message: String
    let isError: Bool

    var systemImage: String {
        isError ? "exclamationmark.circle" : "checkmark.circle"
    }

    static func success(_ message: String) -> Self {
        WordBookNotice(message: message, isError: false)
    }

    static func error(_ message: String) -> Self {
        WordBookNotice(message: message, isError: true)
    }
}

private extension WordBookMaskMode {
    var helpText: String {
        switch self {
        case .normal, .hideMeanings:
            "隐藏本页全部单词"
        case .hideWords:
            "显示单词并隐藏本页全部释义"
        }
    }

    var accessibilityLabel: String {
        switch self {
        case .normal, .hideMeanings:
            "隐藏全部单词"
        case .hideWords:
            "隐藏全部释义"
        }
    }

    var accessibilityValue: String {
        switch self {
        case .normal:
            "全部显示"
        case .hideWords:
            "单词已隐藏"
        case .hideMeanings:
            "释义已隐藏"
        }
    }
}

#Preview("英语单词本") {
    WordBookView(
        space: .english,
        repository: PreviewWordBookRepository(),
        settingsStore: .preview,
        shuffle: ShuffleSeedController(),
        openWorkspace: {}
    )
    .environment(\.appPalette, AppAppearance.dark.palette)
    .frame(width: 1080, height: 700)
}

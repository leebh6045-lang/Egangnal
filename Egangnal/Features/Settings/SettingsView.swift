//
//  SettingsView.swift
//  Egangnal
//

import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @Environment(\.appPalette) private var palette

    let appearanceStore: AppearanceStore
    let settingsStore: AppSettingsStore
    let wordQuizSoundPlayer: any WordQuizSoundPlaying
    let appUpdateController: any AppUpdating
    let openDashboard: () -> Void

    @State private var isChoosingExportDirectory = false
    @State private var notice: SettingsNotice?

    var body: some View {
        ZStack {
            // 设置页是根页面，与首页共用一份背景偏好，不属于任何功能页。
            WorkspaceBackground(page: .dashboard)

            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    header
                    settingsContent
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(AppTheme.contentPadding)
            }
        }
        .fileImporter(
            isPresented: $isChoosingExportDirectory,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false,
            onCompletion: finishChoosingDirectory
        )
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 18) {
            Button(action: openDashboard) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 17, weight: .semibold))
                    .frame(width: 32, height: 32, alignment: .leading)
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.escape, modifiers: [])
            .help("返回总览")
            .accessibilityLabel("返回总览")
            .accessibilityIdentifier("settings.back")

            Text("设置")
                .font(.largeTitle.weight(.semibold))
                .foregroundStyle(palette.primaryText)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("settings.title")
        }
    }

    /// 分区顺序：先是整个应用的偏好，再按页面逐一列出，每个功能页的选项只出现在自己的分区里。
    private var settingsContent: some View {
        VStack(alignment: .leading, spacing: 26) {
            exportSection
            sectionDivider
            personalizationSection
            sectionDivider
            wordBookSection
            sectionDivider
            lexiconSection
            sectionDivider
            wordQuizSection
            sectionDivider
            updateSection
        }
        .frame(maxWidth: 760, alignment: .leading)
        .padding(24)
        .workspacePanel()
    }

    private var sectionDivider: some View {
        Divider()
            .overlay(palette.border.opacity(0.65))
    }

    private var exportSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionTitle("模板导出")

            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("默认导出文件夹")
                        .font(.body.weight(.medium))
                        .foregroundStyle(palette.primaryText)

                    Text(settingsStore.exportDirectoryPath ?? "未设置")
                        .font(.callout)
                        .foregroundStyle(palette.secondaryText)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .help(settingsStore.exportDirectoryPath ?? "尚未设置默认导出文件夹")
                        .accessibilityIdentifier("settings.exportDirectory.path")
                }

                Spacer(minLength: 16)

                if settingsStore.hasExportDirectory {
                    Button {
                        settingsStore.clearExportDirectory()
                        notice = .message("已清除默认导出文件夹。")
                    } label: {
                        Image(systemName: "xmark")
                            .frame(width: AppTheme.toggleSize, height: AppTheme.toggleSize)
                    }
                    .buttonStyle(.bordered)
                    .help("清除默认导出文件夹")
                    .accessibilityLabel("清除默认导出文件夹")
                    .accessibilityIdentifier("settings.exportDirectory.clear")
                }

                Button {
                    isChoosingExportDirectory = true
                } label: {
                    Image(systemName: "folder")
                        .frame(width: AppTheme.toggleSize, height: AppTheme.toggleSize)
                }
                .buttonStyle(.borderedProminent)
                .tint(palette.calendarAccent)
                .help("选择默认导出文件夹")
                .accessibilityLabel("选择默认导出文件夹")
                .accessibilityIdentifier("settings.exportDirectory.choose")
            }

            if let notice {
                Text(notice.message)
                    .font(.callout)
                    .foregroundStyle(notice.isError ? Color.red : palette.secondaryText)
                    .accessibilityIdentifier("settings.notice")
            }
        }
    }

    // MARK: - 应用与首页

    private var personalizationSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            sectionTitle("个性化")

            choiceRow("主题", identifier: "settings.appearance", selection: appearanceBinding)

            Toggle(
                "语言卡片封面图",
                isOn: Binding(
                    get: { settingsStore.showsLanguageCardArtwork },
                    set: { settingsStore.setLanguageCardArtwork($0) }
                )
            )
            .toggleStyle(.switch)
            .accessibilityIdentifier("settings.personalization.cardArtwork")

            choiceRow(
                "首页背景",
                identifier: "settings.personalization.dashboardBackground",
                selection: backgroundBinding(for: .dashboard)
            )

            sectionCaption("首页与设置页共用这一份背景；单词本、集词阁和单词刷在下方各自设置，互不影响。")
        }
        .foregroundStyle(palette.primaryText)
    }

    // MARK: - 单词本

    private var wordBookSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            sectionTitle("单词本")

            choiceRow(
                "排版",
                identifier: "settings.layout.wordBook",
                selection: Binding(
                    get: { settingsStore.wordBook.layout },
                    set: { settingsStore.setWordBookLayout($0) }
                )
            )

            choiceRow(
                "横格线样式",
                identifier: "settings.layout.wordBookRuledLineStyle",
                selection: Binding(
                    get: { settingsStore.wordBook.ruledLineStyle },
                    set: { settingsStore.setWordBookRuledLineStyle($0) }
                )
            )
            // 不用横格本时线条样式没有可见效果，禁用而不是隐藏：用户仍能看到选项存在。
            .disabled(settingsStore.wordBook.layout != .ruled)

            choiceRow(
                "背景",
                identifier: "settings.background.wordBook",
                selection: backgroundBinding(for: .wordBook)
            )

            Toggle(
                "台灯光",
                isOn: Binding(
                    get: { settingsStore.wordBook.showsLamp },
                    set: { settingsStore.setWordBookLamp($0) }
                )
            )
            .toggleStyle(.switch)
            .accessibilityIdentifier("settings.atmosphere.wordBookLamp")

            sectionCaption("横格本把词条排成纸上的行，线条样式决定横格线如何与背景区分；手帐按日期分组，用荧光笔标记高频词。台灯光在左上角打一片暖光。")
        }
        .foregroundStyle(palette.primaryText)
    }

    // MARK: - 集词阁

    private var lexiconSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            sectionTitle("集词阁")

            choiceRow(
                "排版",
                identifier: "settings.layout.lexicon",
                selection: Binding(
                    get: { settingsStore.lexicon.layout },
                    set: { settingsStore.setLexiconLayout($0) }
                )
            )

            choiceRow(
                "横格线样式",
                identifier: "settings.layout.lexiconRuledLineStyle",
                selection: Binding(
                    get: { settingsStore.lexicon.ruledLineStyle },
                    set: { settingsStore.setLexiconRuledLineStyle($0) }
                )
            )
            .disabled(settingsStore.lexicon.layout != .ruled)

            choiceRow(
                "背景",
                identifier: "settings.background.lexicon",
                selection: backgroundBinding(for: .lexicon)
            )

            Toggle(
                "页眉词",
                isOn: Binding(
                    get: { settingsStore.lexicon.showsGuideWords },
                    set: { settingsStore.setLexiconGuideWords($0) }
                )
            )
            .toggleStyle(.switch)
            .accessibilityIdentifier("settings.atmosphere.lexiconGuideWords")

            Toggle(
                "藏书章",
                isOn: Binding(
                    get: { settingsStore.lexicon.showsStamp },
                    set: { settingsStore.setLexiconStamp($0) }
                )
            )
            .toggleStyle(.switch)
            .accessibilityIdentifier("settings.atmosphere.lexiconStamp")

            sectionCaption("页眉词标出本页的首尾词条，藏书章是右下角的一枚水印。")
        }
        .foregroundStyle(palette.primaryText)
    }

    // MARK: - 单词刷

    private var wordQuizSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionTitle("单词刷")

            choiceRow(
                "背景",
                identifier: "settings.background.wordQuiz",
                selection: backgroundBinding(for: .wordQuiz)
            )

            HStack(spacing: 14) {
                Text("答题音效")
                    .font(.body)
                    .foregroundStyle(palette.primaryText)
                    .frame(width: Self.choiceLabelWidth, alignment: .leading)

                Picker("答题音效", selection: soundEffectBinding) {
                    ForEach(WordQuizSoundEffect.allCases) { effect in
                        Text(effect.title).tag(effect)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .controlSize(.large)
                .accessibilityIdentifier("settings.wordQuiz.soundEffect")

                Button {
                    wordQuizSoundPlayer.play(settingsStore.wordQuizSoundEffect)
                } label: {
                    Image(systemName: "speaker.wave.2")
                        .frame(width: AppTheme.toggleSize, height: AppTheme.toggleSize)
                }
                .buttonStyle(.bordered)
                .disabled(settingsStore.wordQuizSoundEffect == .off)
                .help("试听答题音效")
                .accessibilityLabel("试听答题音效")
                .accessibilityIdentifier("settings.wordQuiz.soundPreview")
            }
        }
        .foregroundStyle(palette.primaryText)
    }

    // MARK: - 更新

    private var updateSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionTitle("应用更新")

            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("检查 Egangnal 的最新版本")
                        .font(.body.weight(.medium))
                        .foregroundStyle(palette.primaryText)
                    Text(
                        appUpdateController.isConfigured
                            ? "更新源已配置"
                            : "更新源尚未配置，完成发布配置后即可使用"
                    )
                    .font(.callout)
                    .foregroundStyle(palette.secondaryText)
                }

                Spacer(minLength: 12)

                Button {
                    appUpdateController.checkForUpdates()
                } label: {
                    Label("检查更新", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.borderedProminent)
                .tint(palette.calendarAccent)
                .disabled(!appUpdateController.isConfigured || !appUpdateController.canCheckForUpdates)
                .help("检查 Egangnal 是否有新版本")
                .accessibilityIdentifier("settings.appUpdate.check")
            }
        }
    }

    // MARK: - 共享控件

    private static let choiceLabelWidth: CGFloat = 96

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.title3.weight(.semibold))
            .foregroundStyle(palette.primaryText)
    }

    private func sectionCaption(_ text: String) -> some View {
        Text(text)
            .font(.callout)
            .foregroundStyle(palette.secondaryText)
    }

    /// 标题在左、分段选择器在右的一行，供主题、排版、背景这类少量互斥选项复用。
    private func choiceRow<Choice: SettingsChoice>(
        _ title: String,
        identifier: String,
        selection: Binding<Choice>
    ) -> some View {
        HStack(spacing: 14) {
            Text(title)
                .font(.body)
                .foregroundStyle(palette.primaryText)
                .frame(width: Self.choiceLabelWidth, alignment: .leading)

            Picker(title, selection: selection) {
                ForEach(Choice.allCases) { choice in
                    Text(choice.title).tag(choice)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .controlSize(.large)
            .frame(maxWidth: 360, alignment: .leading)
            .accessibilityIdentifier(identifier)
        }
    }

    private func backgroundBinding(for page: PageBackgroundScope) -> Binding<PageBackgroundPattern> {
        Binding(
            get: { settingsStore.personalization.backgroundPattern(for: page) },
            set: { settingsStore.setBackgroundPattern($0, for: page) }
        )
    }

    private var appearanceBinding: Binding<AppAppearance> {
        Binding(
            get: { appearanceStore.mode },
            set: { appearanceStore.select($0) }
        )
    }

    private var soundEffectBinding: Binding<WordQuizSoundEffect> {
        Binding(
            get: { settingsStore.wordQuizSoundEffect },
            set: { settingsStore.setWordQuizSoundEffect($0) }
        )
    }

    private func finishChoosingDirectory(_ result: Result<[URL], Error>) {
        switch result {
        case let .success(urls):
            guard let directoryURL = urls.first else { return }
            do {
                try settingsStore.selectExportDirectory(directoryURL)
                notice = .message("默认导出文件夹已更新。")
            } catch {
                notice = .error(errorMessage(for: error))
            }
        case let .failure(error):
            guard !isUserCancellation(error) else { return }
            notice = .error(errorMessage(for: error))
        }
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

private struct SettingsNotice {
    let message: String
    let isError: Bool

    static func message(_ message: String) -> Self {
        SettingsNotice(message: message, isError: false)
    }

    static func error(_ message: String) -> Self {
        SettingsNotice(message: message, isError: true)
    }
}

/// 设置页里用分段控件表达的少量互斥选项：能枚举、有标题、可作标签。
protocol SettingsChoice: CaseIterable, Identifiable, Hashable
where AllCases: RandomAccessCollection {
    var title: String { get }
}

extension AppAppearance: SettingsChoice {}
extension WordBookLayoutStyle: SettingsChoice {}
extension LexiconLayoutStyle: SettingsChoice {}
extension RuledLineStyle: SettingsChoice {}
extension PageBackgroundPattern: SettingsChoice {}

#Preview {
    SettingsView(
        appearanceStore: .preview,
        settingsStore: .preview,
        wordQuizSoundPlayer: SilentWordQuizSoundPlayer(),
        appUpdateController: DisabledAppUpdateController(),
        openDashboard: {}
    )
        .environment(\.appPalette, AppAppearance.dark.palette)
        .environment(\.appPersonalization, AppPersonalization.enabled)
        .frame(width: 1080, height: 700)
}

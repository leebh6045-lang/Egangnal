//
//  SettingsView.swift
//  Egangnal
//

import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @Environment(\.appPalette) private var palette

    let settingsStore: AppSettingsStore
    let wordQuizSoundPlayer: any WordQuizSoundPlaying
    let appUpdateController: any AppUpdating
    let openDashboard: () -> Void

    @State private var isChoosingExportDirectory = false
    @State private var notice: SettingsNotice?

    var body: some View {
        ZStack {
            WorkspaceBackground()

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

    private var settingsContent: some View {
        VStack(alignment: .leading, spacing: 26) {
            exportSection

            Divider()
                .overlay(palette.border.opacity(0.65))

            personalizationSection

            Divider()
                .overlay(palette.border.opacity(0.65))

            quizFeedbackSection

            Divider()
                .overlay(palette.border.opacity(0.65))

            updateSection
        }
        .frame(maxWidth: 760, alignment: .leading)
        .padding(24)
        .workspacePanel()
    }

    private var exportSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("模板导出")
                .font(.title3.weight(.semibold))
                .foregroundStyle(palette.primaryText)

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

    private var personalizationSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("个性化")
                .font(.title3.weight(.semibold))
                .foregroundStyle(palette.primaryText)

            Toggle(
                "语言卡片封面图",
                isOn: Binding(
                    get: { settingsStore.showsLanguageCardArtwork },
                    set: { isEnabled in
                        settingsStore.setLanguageCardArtwork(isEnabled)
                    }
                )
            )
            .toggleStyle(.switch)
            .accessibilityIdentifier("settings.personalization.cardArtwork")

            Toggle(
                "页面细网格背景",
                isOn: Binding(
                    get: { settingsStore.showsGridBackground },
                    set: { isEnabled in
                        settingsStore.setGridBackground(isEnabled)
                    }
                )
            )
            .toggleStyle(.switch)
            .accessibilityIdentifier("settings.personalization.gridBackground")
        }
        .foregroundStyle(palette.primaryText)
    }

    private var quizFeedbackSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("答题反馈")
                .font(.title3.weight(.semibold))
                .foregroundStyle(palette.primaryText)

            HStack(spacing: 14) {
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
    }

    private var updateSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("应用更新")
                .font(.title3.weight(.semibold))
                .foregroundStyle(palette.primaryText)

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

#Preview {
    SettingsView(
        settingsStore: .preview,
        wordQuizSoundPlayer: SilentWordQuizSoundPlayer(),
        appUpdateController: DisabledAppUpdateController(),
        openDashboard: {}
    )
        .environment(\.appPalette, AppAppearance.dark.palette)
        .environment(\.appPersonalization, AppPersonalization.enabled)
        .frame(width: 1080, height: 700)
}

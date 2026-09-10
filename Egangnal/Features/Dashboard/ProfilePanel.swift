//
//  ProfilePanel.swift
//  Egangnal
//

import SwiftUI

struct ProfilePanel: View {
    @Environment(\.appPalette) private var palette

    @Bindable var profileStore: ProfileStore

    @State private var isEditing = false
    @State private var draftNickname = ""
    @FocusState private var isNicknameFieldFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("个人信息")
                    .font(.headline)
                    .foregroundStyle(palette.primaryText)
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                if isEditing {
                    Button("保存", systemImage: "checkmark", action: save)
                        .labelStyle(.iconOnly)
                        .buttonStyle(.borderless)
                        .frame(width: 28, height: 28)
                        .contentShape(.rect)
                        .help("保存昵称")
                        .accessibilityIdentifier("profile.saveNickname")

                    Button("取消", systemImage: "xmark", action: cancel)
                        .labelStyle(.iconOnly)
                        .buttonStyle(.borderless)
                        .frame(width: 28, height: 28)
                        .contentShape(.rect)
                        .help("取消编辑")
                        .accessibilityIdentifier("profile.cancelNickname")
                } else {
                    Button("编辑昵称", systemImage: "pencil") {
                        beginEditing()
                    }
                    .labelStyle(.iconOnly)
                    .buttonStyle(.borderless)
                    .frame(width: 28, height: 28)
                    .contentShape(.rect)
                    .help("编辑昵称")
                    .accessibilityIdentifier("profile.editNickname")
                }
            }

            HStack(spacing: 14) {
                Image(systemName: "person.crop.circle.fill")
                    .resizable()
                    .scaledToFit()
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(palette.secondaryText)
                    .frame(width: 56, height: 56)
                    .accessibilityHidden(true)

                if isEditing {
                    editor
                } else {
                    Text(profileStore.nickname)
                        .font(.title3.weight(.medium))
                        .foregroundStyle(palette.primaryText)
                        .lineLimit(2)
                        .accessibilityIdentifier("profile.nickname")
                }
            }

            if let message = profileStore.message ?? profileStore.persistenceWarning {
                Label(message, systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(palette.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("profile.message")
            }
        }
        .frame(maxWidth: .infinity, minHeight: 152, alignment: .topLeading)
        .padding(18)
        .workspacePanel()
    }

    private var editor: some View {
        TextField("昵称", text: $draftNickname)
            .textFieldStyle(.plain)
            .foregroundStyle(palette.primaryText)
            .padding(.horizontal, 8)
            .frame(minHeight: 28)
            .background(palette.panelRaised, in: .rect(cornerRadius: 6))
            .overlay {
                RoundedRectangle(cornerRadius: 6)
                    .stroke(palette.border, lineWidth: 1)
            }
            .focused($isNicknameFieldFocused)
            .onSubmit(save)
            .accessibilityIdentifier("profile.nicknameField")
    }

    private func beginEditing() {
        draftNickname = profileStore.nickname
        profileStore.clearMessage()
        isEditing = true
        isNicknameFieldFocused = true
    }

    private func save() {
        // 先结束输入法组合态，下一次主线程调度才能读取到用户刚确认的文本。
        isNicknameFieldFocused = false
        Task { @MainActor in
            await Task.yield()
            finishSaving()
        }
    }

    private func finishSaving() {
        if profileStore.saveNickname(draftNickname) {
            isEditing = false
        }
    }

    private func cancel() {
        isNicknameFieldFocused = false
        draftNickname = profileStore.nickname
        profileStore.clearMessage()
        isEditing = false
    }
}

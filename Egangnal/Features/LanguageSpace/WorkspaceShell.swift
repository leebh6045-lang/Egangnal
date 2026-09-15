//
//  WorkspaceShell.swift
//  Egangnal
//

import AppKit
import SwiftUI

private enum WorkspaceNavigationHoverRegion {
    case activationArea
    case functionBar
    case studyTime
}

/// 统一拦截工作区导航，让有未完成状态的功能决定是否允许离开。
@MainActor
final class WorkspaceExitCoordinator {
    typealias NavigationAction = () -> Void
    typealias Interceptor = (@escaping NavigationAction) -> Void

    private var interceptor: (id: UUID, action: Interceptor)?

    @discardableResult
    func install(_ action: @escaping Interceptor) -> UUID {
        let id = UUID()
        interceptor = (id, action)
        return id
    }

    func remove(id: UUID) {
        guard interceptor?.id == id else { return }
        interceptor = nil
    }

    func perform(_ action: @escaping NavigationAction) {
        if let interceptor {
            interceptor.action(action)
        } else {
            action()
        }
    }

}

struct WorkspaceShell<Content: View>: View {
    @Environment(\.appPalette) private var palette
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let space: LanguageSpace
    let selectedFeature: WorkspaceFeature
    let studyTimeController: StudyTimeController
    let selectFeature: (WorkspaceFeature) -> Void
    let entryRevealID: Int
    private let content: (WorkspaceExitCoordinator) -> Content

    @State private var isNavigationVisible = false
    @State private var hideTask: Task<Void, Never>?
    @State private var entryRevealTask: Task<Void, Never>?
    @State private var isEntryRevealActive = false
    @State private var isActivationAreaHovered = false
    @State private var isFunctionBarHovered = false
    @State private var isStudyTimeHovered = false
    @State private var handledEntryRevealID = 0
    @State private var exitCoordinator = WorkspaceExitCoordinator()
    @Namespace private var selectionNamespace

    init(
        space: LanguageSpace,
        selectedFeature: WorkspaceFeature,
        studyTimeController: StudyTimeController,
        selectFeature: @escaping (WorkspaceFeature) -> Void,
        entryRevealID: Int = 0,
        @ViewBuilder content: @escaping (WorkspaceExitCoordinator) -> Content
    ) {
        self.space = space
        self.selectedFeature = selectedFeature
        self.studyTimeController = studyTimeController
        self.selectFeature = selectFeature
        self.entryRevealID = entryRevealID
        self.content = content
    }

    var body: some View {
        ZStack(alignment: .top) {
            ZStack {
                content(exitCoordinator)
                    .id(selectedFeature)
                    .transition(featurePageTransition)
            }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .animation(featurePageAnimation, value: selectedFeature)

            if !isNavigationVisible {
                topActivationArea
            }

            if isNavigationVisible {
                // 材质带与功能栏同进同出：它只是功能栏的“影子”，不单独存在。
                WorkspaceNavigationBackdrop()
                    .frame(maxHeight: .infinity, alignment: .top)
                    .ignoresSafeArea()
                    .transition(backdropTransition)
                    .zIndex(1)

                floatingNavigation
                    .padding(.top, AppTheme.workspaceNavigationTopInset)
                    .transition(navigationTransition)
                    .zIndex(2)
            }
        }
        .onReceive(
            NotificationCenter.default.publisher(
                for: NSApplication.willResignActiveNotification
            )
        ) { _ in
            hideImmediately()
        }
        .onReceive(
            NotificationCenter.default.publisher(
                for: .workspaceFeatureNavigationRequested
            )
        ) { notification in
            guard
                let request = notification.object
                    as? WorkspaceFeatureNavigationRequest,
                request.space == space,
                request.feature != selectedFeature
            else { return }

            // 快捷键与顶部栏共用同一个离开协调器，不能绕过答题保护。
            exitCoordinator.perform {
                selectFeature(request.feature)
            }
        }
        .onAppear {
            revealForEntryIfNeeded()
        }
        .onChange(of: entryRevealID) { _, _ in
            revealForEntryIfNeeded()
        }
        .onDisappear {
            hideTask?.cancel()
            entryRevealTask?.cancel()
        }
    }

    private var topActivationArea: some View {
        Color.clear
            // 唤出区只覆盖居中功能栏的水平范围，避免经过页面返回箭头时误触发。
            .frame(
                width: AppTheme.workspaceNavigationWidth,
                height: AppTheme.workspaceNavigationActivationHeight
            )
            .contentShape(.rect)
            .onHover { isHovered in
                if isHovered {
                    pointerEntered(.activationArea)
                } else {
                    pointerExited(.activationArea)
                }
            }
            .accessibilityHidden(true)
            .zIndex(1)
    }

    private var floatingNavigation: some View {
        HStack(spacing: 0) {
            // 两侧占用相同宽度，使中间功能栏始终相对整个窗口居中。
            Color.clear
                .frame(width: workspaceNavigationSideWidth)
                .allowsHitTesting(false)

            functionBar
                .onHover { isHovered in
                    if isHovered {
                        pointerEntered(.functionBar)
                    } else {
                        pointerExited(.functionBar)
                    }
                }

            studyTimeBadge
                .padding(.leading, AppTheme.workspaceStudyTimeGap)
                .frame(width: workspaceNavigationSideWidth, alignment: .leading)
                .onHover { isHovered in
                    if isHovered {
                        pointerEntered(.studyTime)
                    } else {
                        pointerExited(.studyTime)
                    }
                }
        }
        .frame(maxWidth: .infinity)
        .frame(height: AppTheme.workspaceNavigationHeight)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("workspace.navigation")
    }

    private var workspaceNavigationSideWidth: CGFloat {
        AppTheme.workspaceStudyTimeGap + AppTheme.workspaceStudyTimeWidth
    }

    private var functionBar: some View {
        HStack(spacing: 8) {
            ForEach(WorkspaceFeature.allCases) { feature in
                featureButton(feature)
            }
        }
        .padding(.horizontal, 10)
        .frame(
            width: AppTheme.workspaceNavigationWidth,
            height: AppTheme.workspaceNavigationHeight
        )
        .background { WorkspaceNavigationCapsuleBackground() }
        .clipShape(.capsule)
        .overlay {
            Capsule()
                .stroke(palette.border.opacity(0.82), lineWidth: 1)
                // 描边只负责视觉，不能覆盖并截获下方功能按钮的点击。
                .allowsHitTesting(false)
        }
        .shadow(color: palette.panelShadow, radius: 14, y: 6)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("功能选择")
    }

    private func featureButton(_ feature: WorkspaceFeature) -> some View {
        Button {
            guard feature != selectedFeature else { return }
            exitCoordinator.perform {
                selectFeature(feature)
            }
        } label: {
            Text(feature.title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(
                    feature == selectedFeature
                        ? palette.accentForeground
                        : palette.primaryText
                )
                .frame(maxWidth: .infinity)
                .frame(height: 38)
                .background {
                    if feature == selectedFeature {
                        Capsule()
                            .fill(palette.accent(for: space))
                            .matchedGeometryEffect(
                                id: "workspace-feature-selection",
                                in: selectionNamespace
                            )
                    }
                }
                .contentShape(.capsule)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(feature.title)
        .accessibilityValue(feature == selectedFeature ? "已选择" : "未选择")
        .accessibilityIdentifier(
            "workspace.navigation.feature.\(feature.rawValue)"
        )
    }

    private var studyTimeBadge: some View {
        let hours = studyTimeController.displayedHours(for: space)
        let formattedHours = String(
            format: "%.1f",
            locale: Locale(identifier: "en_US_POSIX"),
            hours
        )

        return HStack(spacing: 2) {
            Text("学习时长：")
                .foregroundStyle(palette.secondaryText)
            Text("\(formattedHours)小时")
                .foregroundStyle(studyTimeColor)
                .monospacedDigit()
        }
        .font(.system(size: 15, weight: .semibold))
        .lineLimit(1)
        .frame(width: AppTheme.workspaceStudyTimeWidth, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(space.title)累计学习时长")
        .accessibilityValue("\(formattedHours) 小时")
        .accessibilityIdentifier("workspace.navigation.studyTime")
    }

    private var studyTimeColor: Color {
        switch studyTimeController.displayTier(for: space) {
        case .default:
            palette.primaryText
        case .blue:
            .blue
        case .purple:
            .purple
        case .orange:
            .orange
        }
    }

    private var navigationTransition: AnyTransition {
        guard !reduceMotion else { return .identity }
        return .offset(y: -10).combined(with: .opacity)
    }

    /// 材质带只淡入淡出，不随功能栏位移：位移会让模糊边界肉眼可见地滑动。
    private var backdropTransition: AnyTransition {
        reduceMotion ? .identity : .opacity
    }

    private var featurePageTransition: AnyTransition {
        reduceMotion ? .identity : .opacity
    }

    private var featurePageAnimation: Animation? {
        reduceMotion
            ? nil
            : .easeInOut(duration: AppTheme.pageFadeDuration)
    }

    private func showNavigation() {
        hideTask?.cancel()
        hideTask = nil
        guard !isNavigationVisible else { return }
        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.22)) {
            isNavigationVisible = true
        }
    }

    private func revealForEntryIfNeeded() {
        guard entryRevealID > 0, handledEntryRevealID != entryRevealID else {
            return
        }
        handledEntryRevealID = entryRevealID
        entryRevealTask?.cancel()
        isEntryRevealActive = true
        showNavigation()
        entryRevealTask = Task { @MainActor in
            do {
                try await Task.sleep(for: .seconds(3))
            } catch {
                return
            }
            guard !Task.isCancelled else { return }
            entryRevealTask = nil
            isEntryRevealActive = false
            guard !isPointerInsideNavigation else { return }
            hideNavigation()
        }
    }

    private func scheduleHide(after delay: Duration = .milliseconds(650)) {
        guard !isEntryRevealActive else { return }
        hideTask?.cancel()
        hideTask = Task { @MainActor in
            do {
                try await Task.sleep(for: delay)
            } catch {
                return
            }
            guard !Task.isCancelled,
                  !isEntryRevealActive,
                  !isPointerInsideNavigation else { return }
            hideTask = nil
            hideNavigation()
        }
    }

    private var isPointerInsideNavigation: Bool {
        isActivationAreaHovered || isFunctionBarHovered || isStudyTimeHovered
    }

    private func pointerEntered(_ region: WorkspaceNavigationHoverRegion) {
        setHovered(true, for: region)
        showNavigation()
    }

    private func pointerExited(_ region: WorkspaceNavigationHoverRegion) {
        setHovered(false, for: region)
        guard !isPointerInsideNavigation else { return }
        scheduleHide()
    }

    private func setHovered(
        _ isHovered: Bool,
        for region: WorkspaceNavigationHoverRegion
    ) {
        switch region {
        case .activationArea:
            guard isActivationAreaHovered != isHovered else { return }
            isActivationAreaHovered = isHovered
        case .functionBar:
            guard isFunctionBarHovered != isHovered else { return }
            isFunctionBarHovered = isHovered
        case .studyTime:
            guard isStudyTimeHovered != isHovered else { return }
            isStudyTimeHovered = isHovered
        }
    }

    private func hideNavigation() {
        withAnimation(reduceMotion ? nil : .easeIn(duration: 0.18)) {
            isNavigationVisible = false
        }
    }

    private func hideImmediately() {
        hideTask?.cancel()
        hideTask = nil
        entryRevealTask?.cancel()
        entryRevealTask = nil
        isEntryRevealActive = false
        isActivationAreaHovered = false
        isFunctionBarHovered = false
        isStudyTimeHovered = false
        withTransaction(Transaction(animation: nil)) {
            isNavigationVisible = false
        }
    }
}

struct WorkspaceFeatureNavigationRequest: Sendable {
    let space: LanguageSpace
    let feature: WorkspaceFeature
}

extension Notification.Name {
    static let workspaceFeatureNavigationRequested = Notification.Name(
        "Egangnal.workspaceFeatureNavigationRequested"
    )
}

struct WorkspaceLexiconPlaceholder: View {
    @Environment(\.appPalette) private var palette

    let openDashboard: () -> Void

    var body: some View {
        ZStack(alignment: .topLeading) {
            WorkspaceBackground(page: .lexicon)

            VStack(spacing: 14) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 34, weight: .light))
                Text("功能监修中")
                    .font(.system(size: 34, weight: .semibold, design: .rounded))
            }
            // 返回按钮独立贴左上角，占位水印仍以整个功能页面为基准居中。
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .foregroundStyle(palette.watermark)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("注意，功能监修中")
            .accessibilityIdentifier("workspace.lexicon.placeholder")

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
            .accessibilityIdentifier("workspace.lexicon.back")
            .padding(AppTheme.contentPadding)
        }
    }
}

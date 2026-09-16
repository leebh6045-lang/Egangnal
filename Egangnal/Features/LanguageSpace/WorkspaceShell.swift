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
    @Environment(\.appPersonalization) private var personalization
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let space: LanguageSpace
    let selectedFeature: WorkspaceFeature
    let studyTimeController: StudyTimeController
    let selectFeature: (WorkspaceFeature) -> Void
    let entryRevealID: Int
    /// 本次进入要播的启动页样式；nil 表示不播，只做常驻的强化过渡。
    let entryCeremony: WorkspaceEntryCeremonyStyle?
    private let content: (WorkspaceExitCoordinator) -> Content

    @State private var isNavigationVisible = false
    @State private var hideTask: Task<Void, Never>?
    @State private var isActivationAreaHovered = false
    @State private var isFunctionBarHovered = false
    @State private var isStudyTimeHovered = false
    @State private var handledEntryRevealID = 0
    @State private var isCeremonyPlaying = false
    /// 上一次渲染时的功能，用来决定滑移方向；只在 body 里读、在 onChange 里写。
    @State private var previousFeature: WorkspaceFeature?
    /// 横格本所在滚动区，由功能页通过偏好值上报，壳层据此在背景里抠掉网格。
    @State private var ruledSheetRegion: RuledSheetRegion?
    @State private var exitCoordinator = WorkspaceExitCoordinator()
    @Namespace private var selectionNamespace

    init(
        space: LanguageSpace,
        selectedFeature: WorkspaceFeature,
        studyTimeController: StudyTimeController,
        selectFeature: @escaping (WorkspaceFeature) -> Void,
        entryRevealID: Int = 0,
        entryCeremony: WorkspaceEntryCeremonyStyle? = nil,
        @ViewBuilder content: @escaping (WorkspaceExitCoordinator) -> Content
    ) {
        self.space = space
        self.selectedFeature = selectedFeature
        self.studyTimeController = studyTimeController
        self.selectFeature = selectFeature
        self.entryRevealID = entryRevealID
        self.entryCeremony = entryCeremony
        self.content = content
    }

    var body: some View {
        ZStack(alignment: .top) {
            // 背景只在这里画一次：切换功能页时只有内容交叉，底色与网格不会被淡两次。
            WorkspaceBackground(
                page: selectedFeature.backgroundScope,
                showsLamp: selectedFeature == .wordBook && personalization.wordBook.showsLamp,
                gridCutout: ruledSheetRegion
            )
            .animation(featurePageAnimation, value: selectedFeature)

            ZStack {
                content(exitCoordinator)
                    .id(selectedFeature)
                    .transition(featurePageTransition)
            }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .animation(featurePageAnimation, value: selectedFeature)
                .onPreferenceChange(RuledSheetRegionPreferenceKey.self) { region in
                    ruledSheetRegion = region
                }

            if !isNavigationVisible {
                topActivationArea
            }

            if isNavigationVisible {
                // 玻璃板只包住功能栏，与它同进同出；学习时长留在板外，不参与这块玻璃。
                WorkspaceNavigationGlass(
                    horizontalPadding: AppTheme.workspaceNavigationGlassPadding,
                    verticalPadding: AppTheme.workspaceNavigationGlassVerticalPadding
                )
                .frame(width: AppTheme.workspaceNavigationWidth)
                .padding(.top, AppTheme.workspaceNavigationTopInset)
                .transition(backdropTransition)
                .zIndex(1)

                floatingNavigation
                    .padding(.top, AppTheme.workspaceNavigationTopInset)
                    .transition(navigationTransition)
                    .zIndex(2)
            }

            if isCeremonyPlaying, let entryCeremony {
                // 启动页盖在最上层；功能页已在它底下就位，幕布淡出露出的就是页面本身。
                WorkspaceEntryCeremonyView(
                    space: space,
                    feature: selectedFeature,
                    hours: studyTimeController.displayedHours(for: space),
                    style: entryCeremony,
                    finish: finishCeremony
                )
                .zIndex(3)
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
        .onChange(of: selectedFeature) { _, newFeature in
            // 切换后功能页重建，旧页登记的区域已失效；新页会重新上报。
            ruledSheetRegion = nil
            previousFeature = newFeature
        }
        .onDisappear {
            hideTask?.cancel()
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
        // 选中胶囊在按钮之间滑动：位移由 matchedGeometryEffect 给出，节奏由这一条动画统一。
        .animation(selectionAnimation, value: selectedFeature)
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

    /// 胶囊滑动用略带回弹的弹簧，与功能栏本身 0.22 s 的出现节奏接近。
    private var selectionAnimation: Animation? {
        reduceMotion ? nil : .spring(response: 0.34, dampingFraction: 0.82)
    }

    private var navigationTransition: AnyTransition {
        guard !reduceMotion else { return .identity }
        return .offset(y: -10).combined(with: .opacity)
    }

    /// 材质带只淡入淡出，不随功能栏位移：位移会让模糊边界肉眼可见地滑动。
    private var backdropTransition: AnyTransition {
        reduceMotion ? .identity : .opacity
    }

    /// 按功能栏的左右顺序决定方向：向右切换时新页从右侧进、旧页向左退。
    private var featureDirection: CGFloat {
        let all = WorkspaceFeature.allCases
        guard let previousFeature,
              let from = all.firstIndex(of: previousFeature),
              let to = all.firstIndex(of: selectedFeature),
              from != to else { return 1 }
        return to > from ? 1 : -1
    }

    private var featurePageTransition: AnyTransition {
        guard !reduceMotion else { return .identity }
        switch personalization.featureTransition {
        case .crossfade:
            return .opacity
        case .slide:
            let distance = AppTheme.featureSlideDistance * featureDirection
            return .asymmetric(
                insertion: .offset(x: distance).combined(with: .opacity),
                removal: .offset(x: -distance).combined(with: .opacity)
            )
        case .float:
            return .asymmetric(
                insertion: .modifier(
                    active: WorkspaceFeatureFloatModifier(scale: AppTheme.featureFloatScale, isActive: true),
                    identity: WorkspaceFeatureFloatModifier(scale: AppTheme.featureFloatScale, isActive: false)
                ),
                removal: .modifier(
                    active: WorkspaceFeatureFloatModifier(scale: 2 - AppTheme.featureFloatScale, isActive: true),
                    identity: WorkspaceFeatureFloatModifier(scale: 2 - AppTheme.featureFloatScale, isActive: false)
                )
            )
        }
    }

    private var featurePageAnimation: Animation? {
        guard !reduceMotion else { return nil }
        return personalization.featureTransition == .crossfade
            ? .easeInOut(duration: AppTheme.pageFadeDuration)
            : .easeOut(duration: AppTheme.featureTransitionDuration)
    }

    private func showNavigation() {
        hideTask?.cancel()
        hideTask = nil
        guard !isNavigationVisible else { return }
        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.22)) {
            isNavigationVisible = true
        }
    }

    /// 每次从首页进入只做一件事：有启动页就播；功能栏不再自动唤出（2026-09-16 用户决定，
    /// 它与"灯亮"启动页的光线冲突），仍靠鼠标靠近顶部或快捷键唤出。
    private func revealForEntryIfNeeded() {
        guard entryRevealID > 0, handledEntryRevealID != entryRevealID else {
            return
        }
        handledEntryRevealID = entryRevealID
        if entryCeremony != nil {
            isCeremonyPlaying = true
        }
    }

    private func finishCeremony() {
        guard isCeremonyPlaying else { return }
        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.18)) {
            isCeremonyPlaying = false
        }
    }

    private func scheduleHide(after delay: Duration = AppTheme.workspaceNavigationHideDelay) {
        hideTask?.cancel()
        hideTask = Task { @MainActor in
            do {
                try await Task.sleep(for: delay)
            } catch {
                return
            }
            guard !Task.isCancelled,
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
        isCeremonyPlaying = false
        isActivationAreaHovered = false
        isFunctionBarHovered = false
        isStudyTimeHovered = false
        withTransaction(Transaction(animation: nil)) {
            isNavigationVisible = false
        }
    }
}

/// 功能页"浮现"切换的起止状态：进来的从略大略糊到清晰，出去的反之。
private struct WorkspaceFeatureFloatModifier: ViewModifier {
    let scale: CGFloat
    let isActive: Bool

    func body(content: Content) -> some View {
        content
            .opacity(isActive ? 0 : 1)
            .scaleEffect(isActive ? scale : 1)
            .blur(radius: isActive ? AppTheme.featureFloatBlur : 0)
    }
}

private extension WorkspaceFeature {
    var backgroundScope: PageBackgroundScope {
        switch self {
        case .wordBook: .wordBook
        case .lexicon: .lexicon
        case .wordQuiz: .wordQuiz
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

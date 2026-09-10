//
//  DashboardView.swift
//  Egangnal
//

import AppKit
import SwiftUI

struct DashboardView: View {
    @Environment(\.appPalette) private var palette
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let appearanceStore: AppearanceStore
    let studyTimeController: StudyTimeController
    let openLanguage: (LanguageSpace) -> Void
    let openSettings: () -> Void

    @State private var rippleSnapshot: NSImage?
    @State private var rippleOrigin: CGPoint = .zero
    @State private var rippleProgress: CGFloat = 0
    @State private var isChangingAppearance = false
    @State private var isAnimatingBrand = false

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                WorkspaceBackground()

                dashboardContent(in: proxy.size)
                    .padding(.horizontal, AppTheme.contentPadding)
                    .padding(.top, AppTheme.dashboardTopPadding)
                    .padding(.bottom, AppTheme.contentPadding)

                dashboardControls(in: proxy.size)
                    .padding(AppTheme.contentPadding)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)

            }
            .overlay {
                if let rippleSnapshot {
                    ThemeRippleOverlay(
                        snapshot: rippleSnapshot,
                        origin: rippleOrigin,
                        progress: rippleProgress,
                        size: rippleSnapshot.size
                    )
                    // 波纹只负责绘制，并覆盖透明标题栏，不参与主界面布局。
                    .ignoresSafeArea()
                }
            }
        }
    }

    private func dashboardContent(in size: CGSize) -> some View {
        ZStack(alignment: .topLeading) {
            headerRow

            launcherRow(in: size)
                .frame(width: launcherColumnWidth(in: size), alignment: .topLeading)
                // 入口使用独立坐标，挂历展开时不能参与其纵向排版。
                .offset(y: AppTheme.dashboardLauncherTopOffset)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var headerRow: some View {
        HStack(alignment: .top, spacing: AppTheme.dashboardHeaderSpacing) {
            VStack(alignment: .leading, spacing: 18) {
                brandWatermark

                Text("今天想从哪里开始？")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(palette.primaryText)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityIdentifier("dashboard.title")
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            CalendarPanel(studyTimeController: studyTimeController)
                .frame(width: AppTheme.dashboardCalendarWidth)
        }
        .frame(maxWidth: .infinity, alignment: .top)
    }

    private func launcherRow(in size: CGSize) -> some View {
        LanguageLauncher(
            availableWidth: launcherColumnWidth(in: size),
            openLanguage: openLanguage
        )
    }

    private func launcherColumnWidth(in size: CGSize) -> CGFloat {
        max(
            0,
            size.width
                - AppTheme.contentPadding * 2
                - AppTheme.dashboardCalendarWidth
                - AppTheme.dashboardHeaderSpacing
        )
    }

    private var brandWatermark: some View {
        VStack(alignment: .leading, spacing: 8) {
            BrandWordmark(
                isEnabled: !isChangingAppearance,
                onAnimationStateChanged: { isAnimatingBrand = $0 }
            )
            Text("属于自己的语言学习空间")
                .font(.subheadline)
                .foregroundStyle(palette.secondaryText)
                .accessibilityIdentifier("dashboard.brand.subtitle")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func toggleCenter(in size: CGSize) -> CGPoint {
        CGPoint(
            x: size.width - AppTheme.contentPadding - AppTheme.toggleSize / 2,
            y: size.height - AppTheme.contentPadding - AppTheme.toggleSize / 2
        )
    }

    private func dashboardControls(in size: CGSize) -> some View {
        HStack(spacing: 10) {
            Button(action: openSettings) {
                Image(systemName: "gearshape")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(palette.calendarAccent)
                    .frame(width: AppTheme.toggleSize, height: AppTheme.toggleSize)
                    .background(palette.panel, in: .rect(cornerRadius: 8))
                    .overlay {
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(palette.border, lineWidth: 1)
                    }
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .disabled(isChangingAppearance || isAnimatingBrand)
            .help("打开设置")
            .accessibilityLabel("打开设置")
            .accessibilityIdentifier("dashboard.settings")

            AppearanceToggle(
                appearanceStore: appearanceStore,
                isEnabled: !isChangingAppearance && !isAnimatingBrand
            ) {
                changeAppearance(
                    from: toggleCenter(in: size),
                    contentSize: size
                )
            }
        }
    }

    private func changeAppearance(from origin: CGPoint, contentSize: CGSize) {
        guard !isChangingAppearance else { return }

        guard !reduceMotion,
              let snapshot = WindowSnapshotter.captureKeyWindowContent() else {
            appearanceStore.toggle()
            return
        }

        isChangingAppearance = true
        rippleSnapshot = snapshot
        rippleOrigin = ThemeRippleGeometry.windowOrigin(
            contentOrigin: origin,
            contentSize: contentSize,
            windowSize: snapshot.size
        )
        rippleProgress = 0
        withTransaction(Transaction(animation: nil)) {
            appearanceStore.toggle()
        }

        withAnimation(.easeInOut(duration: AppTheme.rippleDuration)) {
            rippleProgress = 1
        }

        Task { @MainActor in
            try? await Task.sleep(for: AppTheme.rippleCleanupDelay)
            rippleSnapshot = nil
            isChangingAppearance = false
        }
    }
}

#Preview {
    DashboardView(
        appearanceStore: .preview,
        studyTimeController: .preview,
        openLanguage: { _ in },
        openSettings: {}
    )
        .frame(width: 1080, height: 700)
}

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
    let dashboardStore: DashboardStore
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
                WorkspaceBackground(page: .dashboard)

                dashboardContent(in: proxy.size)

                dashboardControls(in: proxy.size)
                    .padding(DashboardMetrics(size: proxy.size).controlInset)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)

            }
            .onAppear(perform: dashboardStore.reload)
            .overlay {
                if let rippleSnapshot {
                    ThemeRippleOverlay(
                        snapshot: rippleSnapshot,
                        origin: rippleOrigin,
                        progress: rippleProgress,
                        size: rippleSnapshot.size
                    )
                    // 波纹只负责绘制并覆盖透明标题栏，不参与主界面布局。
                    .ignoresSafeArea()
                }
            }
        }
    }

    private func dashboardContent(in size: CGSize) -> some View {
        let metrics = DashboardMetrics(size: size)

        return VStack(spacing: 0) {
            headerRow
                .frame(height: metrics.headerHeight, alignment: .top)
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(palette.border.opacity(0.55))
                        .frame(height: 1)
                }

            HStack(alignment: .top, spacing: metrics.columnSpacing) {
                launcherColumn(
                    availableWidth: metrics.launcherColumnWidth,
                    isCompact: metrics.isCompact
                )
                .frame(width: metrics.launcherColumnWidth, alignment: .topLeading)
                .fixedSize(horizontal: false, vertical: true)

                CalendarPanel(
                    studyTimeController: studyTimeController,
                    isCompact: metrics.isCompact
                )
                .frame(width: metrics.calendarWidth)
                .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.top, metrics.mainContentTopInset)
            .frame(maxHeight: .infinity, alignment: .top)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(.horizontal, metrics.horizontalPadding)
        .padding(.top, metrics.topPadding)
        .padding(.bottom, metrics.bottomPadding)
    }

    private var headerRow: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            HStack(alignment: .top, spacing: 24) {
                brandWatermark
                    .frame(maxWidth: .infinity, alignment: .leading)

                VStack(alignment: .trailing, spacing: 3) {
                    Text(context.date, format: .dateTime.month().day())
                        .font(.system(size: 29, weight: .medium, design: .serif))
                        .foregroundStyle(palette.primaryText)
                    Text(context.date, format: .dateTime.weekday(.wide))
                        .font(.subheadline)
                        .foregroundStyle(palette.tertiaryText)
                }
                .environment(\.locale, Locale(identifier: "zh_Hans_CN"))
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("dashboard.date")
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private func launcherColumn(
        availableWidth: CGFloat,
        isCompact: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("今天想学点什么？")
                .font(.system(.title3, design: .serif).weight(.medium))
                .foregroundStyle(palette.secondaryText)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("dashboard.title")

            LanguageLauncher(
                availableWidth: availableWidth,
                isCompact: isCompact,
                openLanguage: openLanguage
            )
            .padding(.top, 12)

            DashboardRecentPages(
                state: dashboardStore.state,
                availableWidth: availableWidth
            )
            .padding(.top, isCompact ? 10 : 16)
        }
    }

    private var brandWatermark: some View {
        BrandWordmark(
            isEnabled: !isChangingAppearance,
            onAnimationStateChanged: { isAnimatingBrand = $0 }
        )
    }

    private func toggleCenter(in size: CGSize) -> CGPoint {
        let inset = DashboardMetrics(size: size).controlInset
        return CGPoint(
            x: size.width - inset - AppTheme.toggleSize / 2,
            y: size.height - inset - AppTheme.toggleSize / 2
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
            appearanceStore.cycle()
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
            appearanceStore.cycle()
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
        dashboardStore: .preview,
        studyTimeController: .preview,
        openLanguage: { _ in },
        openSettings: {}
    )
        .frame(width: 1080, height: 700)
}

/// 首页在默认与最小窗口间只有两套经过验收的几何，
/// 避免视图里散落补偿偏移。
private struct DashboardMetrics {
    private let size: CGSize
    let isCompact: Bool

    init(size: CGSize) {
        self.size = size
        isCompact = size.width < 1_000 || size.height < 650
    }

    var horizontalPadding: CGFloat {
        max((size.width - contentWidth) / 2, minimumHorizontalPadding)
    }
    var topPadding: CGFloat { isCompact ? 40 : 46 }
    var bottomPadding: CGFloat { isCompact ? 12 : 28 }
    var controlInset: CGFloat { isCompact ? 16 : 28 }
    var headerHeight: CGFloat { isCompact ? 86 : 108 }
    var mainContentTopInset: CGFloat { isCompact ? 10 : 52 }
    var columnSpacing: CGFloat { isCompact ? 28 : 30 }
    var calendarWidth: CGFloat {
        guard !isCompact else { return 260 }
        return min(max(contentWidth * 4 / 15, 274), 320)
    }

    var launcherColumnWidth: CGFloat {
        contentWidth - calendarWidth - columnSpacing
    }

    private var contentWidth: CGFloat {
        min(size.width - minimumHorizontalPadding * 2, isCompact ? 752 : 1_200)
    }

    private var minimumHorizontalPadding: CGFloat {
        isCompact ? 34 : 58
    }
}

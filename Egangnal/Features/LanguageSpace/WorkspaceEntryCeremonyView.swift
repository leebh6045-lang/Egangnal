//
//  WorkspaceEntryCeremonyView.swift
//  Egangnal
//

import SwiftUI

/// 从首页进入语言空间时盖在功能页上的启动页。
///
/// 两条硬约束：① 任何元素都从完全透明的状态开始动画，绝不能先以最终状态闪现一帧再淡入；
/// ② 到 `inputUnlockFraction` 之后不再截获输入，点击可随时跳过。总时长见 `WorkspaceEntryCeremonyPolicy`。
struct WorkspaceEntryCeremonyView: View {
    @Environment(\.appPalette) private var palette

    let space: LanguageSpace
    let feature: WorkspaceFeature
    let hours: Double
    let style: WorkspaceEntryCeremonyStyle
    let finish: () -> Void

    /// 启动时刻；进度按真实经过时间计算，不依赖 SwiftUI 动画事务：
    /// 视图是在根路由转场中插入的，onAppear 里的 withAnimation 会被父级事务吞掉而瞬间跳到终点。
    @State private var startDate: Date?
    @State private var acceptsInput = false
    @State private var finishTask: Task<Void, Never>?

    var body: some View {
        TimelineView(.animation(paused: startDate == nil)) { context in
            GeometryReader { proxy in
                let progress = progress(at: context.date)
                ZStack {
                    switch style {
                    case .title:
                        titleCeremony(progress: progress)
                    case .lamp:
                        lampCeremony(progress: progress, size: proxy.size)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(!acceptsInput)
        .contentShape(.rect)
        .onTapGesture(perform: complete)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("正在进入\(space.title)\(feature.title)")
        .accessibilityIdentifier("workspace.entryCeremony")
        .onAppear(perform: start)
        .onDisappear { finishTask?.cancel() }
    }

    // MARK: - 扉页

    private func titleCeremony(progress: Double) -> some View {
        let stage = TitleStage(progress: progress)
        return ZStack {
            Rectangle()
                .fill(palette.canvasTop)
                .opacity(stage.veilOpacity)

            VStack(spacing: 14) {
                nativeTitle
                    .foregroundStyle(palette.primaryText)
                subtitle
                    .foregroundStyle(palette.tertiaryText)
                Rectangle()
                    .fill(palette.border.opacity(0.8))
                    .frame(width: stage.lineWidth, height: 1)
                    .padding(.top, 8)
            }
            .opacity(stage.textOpacity)
            .offset(y: stage.textOffset)
        }
    }

    /// 扉页各元素在 0…1 进度下的状态；分段用线性插值，曲线由外层动画统一给出。
    private struct TitleStage {
        let progress: Double

        var veilOpacity: Double { 1 - Self.ramp(progress, from: 0.62, to: 1) }
        var textOpacity: Double {
            Self.ramp(progress, from: 0, to: 0.22) * (1 - Self.ramp(progress, from: 0.58, to: 0.82))
        }
        var textOffset: CGFloat {
            10 - 10 * Self.ramp(progress, from: 0, to: 0.22) - 14 * Self.ramp(progress, from: 0.58, to: 0.82)
        }
        var lineWidth: CGFloat { 220 * Self.ramp(progress, from: 0.1, to: 0.48) }

        static func ramp(_ value: Double, from start: Double, to end: Double) -> Double {
            min(max((value - start) / (end - start), 0), 1)
        }
    }

    // MARK: - 灯亮

    private func lampCeremony(progress: Double, size: CGSize) -> some View {
        let stage = LampStage(progress: progress)
        // 光圈以窗口对角线为半径，任何时刻都从左上角那个点开始铺开，角落不会先空着。
        let radius = hypot(size.width, size.height)
        return ZStack {
            Rectangle()
                .fill(Color(red: 0.027, green: 0.031, blue: 0.039))
                .opacity(stage.veilOpacity)

            RadialGradient(
                stops: [
                    .init(color: palette.lampLight.opacity(stage.glowStrength * 0.55), location: 0),
                    .init(color: palette.lampLight.opacity(stage.glowStrength * 0.18), location: 0.26),
                    .init(color: .clear, location: 0.62)
                ],
                center: .topLeading,
                startRadius: 0,
                endRadius: radius * stage.glowScale
            )
            .opacity(stage.glowOpacity)

            VStack(spacing: 14) {
                nativeTitle
                    .foregroundStyle(Color(red: 0.949, green: 0.953, blue: 0.961))
                subtitle
                    .foregroundStyle(Color(red: 0.949, green: 0.953, blue: 0.961).opacity(0.6))
            }
            .opacity(stage.textOpacity)
            .blur(radius: stage.textBlur)
        }
    }

    private struct LampStage {
        let progress: Double

        var veilOpacity: Double { 1 - TitleStage.ramp(progress, from: 0.3, to: 1) }
        var glowOpacity: Double {
            TitleStage.ramp(progress, from: 0, to: 0.35) * (1 - TitleStage.ramp(progress, from: 0.35, to: 1))
        }
        /// 光的"亮度"与半径分开：半径从 0.6 起步，亮度同步起来，所以第一帧就是一个很小但完整的光斑。
        var glowStrength: Double { 1 }
        var glowScale: Double { 0.6 + 0.55 * TitleStage.ramp(progress, from: 0, to: 1) }
        var textOpacity: Double {
            TitleStage.ramp(progress, from: 0, to: 0.26) * (1 - TitleStage.ramp(progress, from: 0.54, to: 0.84))
        }
        var textBlur: CGFloat {
            6 * (1 - TitleStage.ramp(progress, from: 0, to: 0.26)) + 4 * TitleStage.ramp(progress, from: 0.54, to: 0.84)
        }
    }

    // MARK: - 共享文字

    private var nativeTitle: some View {
        Text(space.nativeTitle)
            .font(.system(size: 72, weight: .bold, design: .rounded))
            .kerning(-1.4)
    }

    private var subtitle: some View {
        let formattedHours = String(format: "%.1f", locale: Locale(identifier: "en_US_POSIX"), hours)
        return Text("\(feature.title) · 累计 \(formattedHours) 小时")
            .font(.system(size: 14))
            .kerning(1.6)
            .monospacedDigit()
    }

    // MARK: - 时间线

    /// 0 → 1 的单一进度值，所有元素都由它派生；各分段的缓动已写进 ramp 的起止点里。
    private func progress(at date: Date) -> Double {
        guard let startDate else { return 0 }
        return min(max(date.timeIntervalSince(startDate) / WorkspaceEntryCeremonyPolicy.duration, 0), 1)
    }

    private func start() {
        let duration = WorkspaceEntryCeremonyPolicy.duration
        startDate = .now
        finishTask = Task { @MainActor in
            let unlock = duration * WorkspaceEntryCeremonyPolicy.inputUnlockFraction
            try? await Task.sleep(for: .seconds(unlock))
            guard !Task.isCancelled else { return }
            acceptsInput = true
            try? await Task.sleep(for: .seconds(duration - unlock))
            guard !Task.isCancelled else { return }
            finish()
        }
    }

    private func complete() {
        finishTask?.cancel()
        finish()
    }
}

#Preview("扉页") {
    ZStack {
        WorkspaceBackground(page: .wordBook)
        WorkspaceEntryCeremonyView(space: .english, feature: .wordBook, hours: 120.1, style: .title) {}
    }
    .environment(\.appPalette, AppAppearance.warm.palette)
    .frame(width: 1080, height: 700)
}

#Preview("灯亮") {
    ZStack {
        WorkspaceBackground(page: .wordBook)
        WorkspaceEntryCeremonyView(space: .japanese, feature: .wordQuiz, hours: 36.4, style: .lamp) {}
    }
    .environment(\.appPalette, AppAppearance.dark.palette)
    .frame(width: 1080, height: 700)
}

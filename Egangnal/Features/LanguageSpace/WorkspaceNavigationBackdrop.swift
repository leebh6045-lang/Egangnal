//
//  WorkspaceNavigationBackdrop.swift
//  Egangnal
//

import SwiftUI

/// 功能栏唤出时覆盖在页面顶部的渐进材质带。
///
/// 两层系统材质各用不同长度的渐变遮罩叠在一起，模糊从顶端向下减弱到零；
/// 再叠一层面板色着色，浅色主题下材质不会发灰，深色主题下文字仍有足够对比。
/// 材质跟随 SwiftUI 的 `colorScheme` 环境值（根视图已按应用主题设置），不读系统外观。
///
/// 系统材质的模糊半径固定、无法调节；设计定稿（2026-09-13）选择了系统材质，
/// 顶端比 4 pt 的示意稿更糊，由着色与遮罩长度把观感压回来。
struct WorkspaceNavigationBackdrop: View {
    @Environment(\.appPalette) private var palette
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        ZStack {
            if !reduceTransparency {
                Rectangle()
                    .fill(.regularMaterial)
                    .mask {
                        LinearGradient(
                            stops: [
                                .init(color: .black, location: 0),
                                .init(color: .black, location: 0.30),
                                .init(color: .clear, location: 1)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    }

                Rectangle()
                    .fill(.regularMaterial)
                    .mask {
                        LinearGradient(
                            stops: [
                                .init(color: .black, location: 0),
                                .init(color: .black, location: 0.10),
                                .init(color: .clear, location: 0.55)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    }
            }

            // 减少透明度时只保留着色：层次弱一些，但不会出现看不清的文字。
            LinearGradient(
                stops: [
                    .init(
                        color: palette.panel.opacity(AppTheme.workspaceNavigationBackdropTint),
                        location: 0
                    ),
                    .init(
                        color: palette.panel.opacity(AppTheme.workspaceNavigationBackdropTint * 0.45),
                        location: 0.45
                    ),
                    .init(color: .clear, location: 1)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .frame(height: AppTheme.workspaceNavigationBackdropHeight)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// 功能栏胶囊的背景：材质 + 轻着色 + 顶缘高光；减少透明度时退回不透明面板。
///
/// 着色只有 0.38（2026-09-16 定稿，原 0.62）：着色一重材质就像一块实板，
/// 透出来的模糊内容才是"毛玻璃"的来源。顶缘一道 1 pt 高光模拟玻璃受光的边。
struct WorkspaceNavigationCapsuleBackground: View {
    @Environment(\.appPalette) private var palette
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        ZStack {
            if reduceTransparency {
                Capsule().fill(palette.panel)
            } else {
                Capsule().fill(.thinMaterial)
                Capsule().fill(palette.panel.opacity(AppTheme.workspaceNavigationCapsuleTint))
                // 从顶缘往下的一层薄光，让玻璃有厚度感；下半部保持透明。
                Capsule().fill(
                    LinearGradient(
                        colors: [
                            .white.opacity(AppTheme.workspaceNavigationCapsuleSheen),
                            .clear
                        ],
                        startPoint: .top,
                        endPoint: .center
                    )
                )
                Capsule()
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                .white.opacity(AppTheme.workspaceNavigationCapsuleSheen * 2),
                                .clear
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 1
                    )
            }
        }
    }
}

//
//  WorkspaceNavigationGlass.swift
//  Egangnal
//

import SwiftUI

/// 功能栏的玻璃板：只比胶囊外扩一圈很窄的边，跟随功能栏一起显隐。
///
/// 2026-09-16 由"通栏渐变材质带"改为本形状。原实现从窗口顶边向下铺 192 pt 的
/// 材质渐变，把整页顶部都糊掉；用户的预期是 Launchpad 那种**小面积、高模糊**的玻璃，
/// 因此改成贴合功能栏的一块板，面积只比胶囊大一圈。
///
/// 质感的三条来源：厚的系统材质（模糊重）、极淡的面板色着色（透出内容）、
/// 顶缘一道 1 pt 高光加自上而下的薄光（玻璃受光的厚度感）。
struct WorkspaceNavigationGlass: View {
    @Environment(\.appPalette) private var palette
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    /// 玻璃板相对内容外扩的尺寸，由调用方给出以贴合功能栏的实际大小。
    let horizontalPadding: CGFloat
    let verticalPadding: CGFloat

    private var shape: RoundedRectangle {
        RoundedRectangle(
            cornerRadius: (AppTheme.workspaceNavigationHeight + verticalPadding * 2) / 2,
            style: .continuous
        )
    }

    var body: some View {
        ZStack {
            if reduceTransparency {
                // 减少透明度时退回不透明面板：没有模糊，文字仍要清楚。
                shape.fill(palette.panel)
            } else {
                shape.fill(.thickMaterial)
                shape.fill(palette.panel.opacity(AppTheme.workspaceNavigationGlassTint))
                // 自顶向下的薄光，只覆盖上半部，下半部保持透明。
                shape.fill(
                    LinearGradient(
                        colors: [
                            .white.opacity(AppTheme.workspaceNavigationGlassSheen),
                            .clear
                        ],
                        startPoint: .top,
                        endPoint: .center
                    )
                )
                shape.strokeBorder(
                    LinearGradient(
                        colors: [
                            .white.opacity(AppTheme.workspaceNavigationGlassSheen * 2),
                            .clear
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 1
                )
            }
        }
        .padding(.horizontal, horizontalPadding)
        .padding(.vertical, verticalPadding)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// 功能栏自身的底色。
///
/// 2026-09-16：玻璃质感移交给背后的 `WorkspaceNavigationGlass`，这里不再画材质——
/// 否则会在同一块区域叠两层材质加两层着色，又变回"实板"。现在它只负责
/// "减少透明度时给一个不透明底面"，其余情况保持透明，让玻璃板透出来。
struct WorkspaceNavigationCapsuleBackground: View {
    @Environment(\.appPalette) private var palette
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        ZStack {
            if reduceTransparency {
                Capsule().fill(palette.panel)
            }
        }
    }
}

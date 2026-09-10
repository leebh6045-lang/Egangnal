//
//  ThemeRippleTransition.swift
//  Egangnal
//

import AppKit
import SwiftUI

@MainActor
enum WindowSnapshotter {
    static func captureKeyWindowContent() -> NSImage? {
        guard let window = NSApp.keyWindow ?? NSApp.mainWindow,
              let contentView = window.contentView else {
            return nil
        }

        let bounds = contentView.bounds
        guard bounds.width > 0,
              bounds.height > 0,
              let representation = contentView.bitmapImageRepForCachingDisplay(in: bounds) else {
            return nil
        }

        contentView.cacheDisplay(in: bounds, to: representation)
        let image = NSImage(size: bounds.size)
        image.addRepresentation(representation)
        return image
    }
}

struct ThemeRippleOverlay: View {
    let snapshot: NSImage
    let origin: CGPoint
    let progress: CGFloat
    let size: CGSize

    var body: some View {
        Image(nsImage: snapshot)
            .resizable()
            .frame(width: size.width, height: size.height, alignment: .topLeading)
            .clipped()
            .mask {
                RippleInverseMask(origin: origin, progress: progress)
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

private struct RippleInverseMask: View, @preconcurrency Animatable {
    let origin: CGPoint
    var progress: CGFloat

    // 显式暴露进度，确保 withAnimation 会逐帧插值圆形半径。
    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let radius = ThemeRippleGeometry.revealRadius(
                in: size,
                from: origin,
                progress: progress
            )
            let endRadius = max(radius + AppTheme.rippleFeather, 1)
            let revealStop = min(max(radius / endRadius, 0), 1)
            let center = UnitPoint(
                x: size.width > 0 ? origin.x / size.width : 0.5,
                y: size.height > 0 ? origin.y / size.height : 0.5
            )

            // 透明圆心露出新主题，边缘渐变到不透明以保留旧快照。
            RadialGradient(
                stops: [
                    .init(color: .clear, location: 0),
                    .init(color: .clear, location: revealStop),
                    .init(color: .white, location: 1)
                ],
                center: center,
                startRadius: 0,
                endRadius: endRadius
            )
        }
    }
}

enum ThemeRippleGeometry {
    static func windowOrigin(
        contentOrigin: CGPoint,
        contentSize: CGSize,
        windowSize: CGSize
    ) -> CGPoint {
        // macOS 的内容安全区位于标题栏下方，波纹原点需转换到完整窗口坐标。
        CGPoint(
            x: contentOrigin.x + max((windowSize.width - contentSize.width) / 2, 0),
            y: contentOrigin.y + max(windowSize.height - contentSize.height, 0)
        )
    }

    static func requiredRadius(in size: CGSize, from origin: CGPoint) -> CGFloat {
        let horizontalDistance = max(origin.x, size.width - origin.x)
        let verticalDistance = max(origin.y, size.height - origin.y)
        return hypot(horizontalDistance, verticalDistance)
    }

    static func clampedProgress(_ progress: CGFloat) -> CGFloat {
        min(max(progress, 0), 1)
    }

    static func revealRadius(
        in size: CGSize,
        from origin: CGPoint,
        progress: CGFloat
    ) -> CGFloat {
        requiredRadius(in: size, from: origin) * clampedProgress(progress)
    }
}

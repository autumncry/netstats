import CoreGraphics
import Foundation

/// Screen and notch rectangles use AppKit's global, point-based coordinate space.
package struct NotchGeometry: Equatable {
    package let screenFrame: CGRect
    package let notchFrame: CGRect
    package let triggerFrame: CGRect
    private let visibleFrame: CGRect

    package static func detect(
        screenFrame: CGRect,
        visibleFrame: CGRect,
        safeAreaTop: CGFloat,
        auxiliaryLeft: CGRect,
        auxiliaryRight: CGRect,
        isBuiltIn: Bool
    ) -> NotchGeometry? {
        guard isBuiltIn,
              safeAreaTop.isFinite, safeAreaTop > 0,
              valid(screenFrame), valid(visibleFrame),
              valid(auxiliaryLeft), valid(auxiliaryRight),
              safeAreaTop < screenFrame.height,
              screenFrame.contains(visibleFrame)
        else { return nil }

        let notchBottom = screenFrame.maxY - safeAreaTop
        // Auxiliary areas must describe the two sides of this screen's top band.
        let tolerance: CGFloat = 0.001
        guard abs(auxiliaryLeft.minX - screenFrame.minX) <= tolerance,
              abs(auxiliaryRight.maxX - screenFrame.maxX) <= tolerance,
              abs(auxiliaryLeft.minY - notchBottom) <= tolerance,
              abs(auxiliaryRight.minY - notchBottom) <= tolerance,
              abs(auxiliaryLeft.maxY - screenFrame.maxY) <= tolerance,
              abs(auxiliaryRight.maxY - screenFrame.maxY) <= tolerance,
              auxiliaryLeft.maxX < auxiliaryRight.minX,
              auxiliaryLeft.maxX > screenFrame.minX,
              auxiliaryRight.minX < screenFrame.maxX,
              visibleFrame.width > 16,
              visibleFrame.minY + 8 < min(notchBottom, visibleFrame.maxY)
        else { return nil }

        let notch = CGRect(
            x: auxiliaryLeft.maxX,
            y: notchBottom,
            width: auxiliaryRight.minX - auxiliaryLeft.maxX,
            height: safeAreaTop
        )
        return NotchGeometry(
            screenFrame: screenFrame,
            notchFrame: notch,
            triggerFrame: notch.insetBy(dx: -4, dy: -4).intersection(screenFrame),
            visibleFrame: visibleFrame
        )
    }

    package func containsTrigger(_ point: CGPoint) -> Bool {
        point.x.isFinite && point.y.isFinite
            && point.x >= triggerFrame.minX && point.x <= triggerFrame.maxX
            && point.y >= triggerFrame.minY && point.y <= triggerFrame.maxY
    }

    package func cardFrame(height: CGFloat, width: CGFloat = 420) -> CGRect {
        let usableLeft = visibleFrame.minX + 8
        let usableRight = visibleFrame.maxX - 8
        let usableBottom = visibleFrame.minY + 8
        // Some MacBooks reserve menu-bar points below the physical notch.
        let bodyTop = min(notchFrame.minY, visibleFrame.maxY)
        let cardWidth = min(width.isFinite ? max(0, width) : 420, usableRight - usableLeft)
        let cardHeight = min(height.isFinite ? max(0, height) : 0, bodyTop - usableBottom)
        let centeredX = notchFrame.midX - cardWidth / 2
        let x = min(max(centeredX, usableLeft), usableRight - cardWidth)
        return CGRect(x: x, y: bodyTop - cardHeight, width: cardWidth, height: cardHeight)
    }

    private static func valid(_ frame: CGRect) -> Bool {
        frame.origin.x.isFinite && frame.origin.y.isFinite
            && frame.width.isFinite && frame.height.isFinite
            && frame.width > 0 && frame.height > 0
            && frame.maxX.isFinite && frame.maxY.isFinite
    }
}

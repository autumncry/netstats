import CoreGraphics
import Foundation

enum StatusItemAnchor {
    struct Screen {
        let frame: CGRect
        let visibleFrame: CGRect

        fileprivate func menuBand(height: CGFloat) -> CGRect? {
            guard StatusItemAnchor.isValid(frame), StatusItemAnchor.isValid(visibleFrame),
                  frame.contains(visibleFrame), height.isFinite, height > 0 else { return nil }
            // On notched displays the reserved area can be taller than the
            // status bar's nominal thickness. With auto-hide it can be zero.
            let bandHeight = max(height, frame.maxY - visibleFrame.maxY)
            guard bandHeight < frame.height else { return nil }
            return CGRect(x: frame.minX, y: frame.maxY - bandHeight, width: frame.width, height: bandHeight)
        }
    }

    /// Supply NSScreen.screens order (primary first). Only call when opening
    /// a panel; an arbitrary desktop mouse move is never an activation.
    static func resolve(buttonFrame: CGRect?, pointer: CGPoint, screens: [Screen], menuBarHeight: CGFloat) -> CGRect? {
        let bands = screens.compactMap { $0.menuBand(height: menuBarHeight) }
        guard let primary = bands.first else { return nil }
        let pointerBand = bands.first {
            $0.minX <= pointer.x && pointer.x < $0.maxX && $0.minY <= pointer.y && pointer.y <= $0.maxY
        }
        if let buttonFrame, isValid(buttonFrame),
           let buttonBand = bands.first(where: { $0.contains(buttonFrame) && buttonFrame.width < $0.width * 0.75 }),
           pointerBand == nil || pointerBand == buttonBand {
            return buttonFrame
        }
        let band = pointerBand ?? primary
        let width = min(menuBarHeight, band.width)
        let x = pointerBand == nil ? band.maxX - width : pointer.x - width / 2
        return CGRect(x: min(max(x, band.minX), band.maxX - width), y: band.minY, width: width, height: band.height)
    }

    private static func isValid(_ rect: CGRect) -> Bool {
        rect.origin.x.isFinite && rect.origin.y.isFinite && rect.size.width.isFinite && rect.size.height.isFinite
            && rect.size.width > 0 && rect.size.height > 0 && rect.maxX.isFinite && rect.maxY.isFinite
    }
}

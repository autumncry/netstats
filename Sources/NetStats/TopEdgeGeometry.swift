import CoreGraphics
import Foundation

enum TopEdgeMode: String, CaseIterable, Identifiable {
    case automatic, notch, topBar
    var id: String { rawValue }
    func title(_ language: AppLanguage) -> String {
        switch self {
        case .automatic: language == .simplifiedChinese ? "自动" : "Automatic"
        case .notch: language == .simplifiedChinese ? "刘海" : "Notch"
        case .topBar: language == .simplifiedChinese ? "顶栏" : "Top bar"
        }
    }
}

struct TopEdgeScreen {
    let displayID: UInt32
    let name: String
    let frame: CGRect
    var visibleFrame: CGRect
    let safeAreaTop: CGFloat
    let auxiliaryLeft: CGRect?
    let auxiliaryRight: CGRect?
    let isBuiltIn: Bool
}

struct TopEdgeGeometry {
    let mode: TopEdgeMode
    let displayID: UInt32
    let screenName: String
    let anchorFrame: CGRect
    let triggerFrame: CGRect
    private let visibleFrame: CGRect
    private let physicalNotch: NotchGeometry?

    static func resolve(mode: TopEdgeMode, screens: [TopEdgeScreen], preferredDisplayID: UInt32?) -> Self? {
        if mode != .topBar {
            for screen in screens {
                guard let left = screen.auxiliaryLeft, let right = screen.auxiliaryRight,
                      let notch = NotchGeometry.detect(screenFrame: screen.frame, visibleFrame: screen.visibleFrame,
                                                       safeAreaTop: screen.safeAreaTop, auxiliaryLeft: left,
                                                       auxiliaryRight: right, isBuiltIn: screen.isBuiltIn) else { continue }
                return Self(mode: .notch, displayID: screen.displayID, screenName: screen.name,
                            anchorFrame: notch.notchFrame, triggerFrame: notch.triggerFrame,
                            visibleFrame: screen.visibleFrame, physicalNotch: notch)
            }
            if mode == .notch { return nil }
        }
        let ordered = screens.filter { $0.displayID == preferredDisplayID }
            + screens.filter { $0.displayID != preferredDisplayID }
        for screen in ordered {
            let visible = screen.visibleFrame
            guard valid(screen.frame), valid(visible), screen.frame.contains(visible),
                  visible.width > 32, visible.height > 32 else { continue }
            let width = min(360, visible.width - 16)
            let anchor = CGRect(x: visible.midX - width / 2, y: visible.maxY - 8, width: width, height: 8)
            return Self(mode: .topBar, displayID: screen.displayID, screenName: screen.name,
                        anchorFrame: anchor, triggerFrame: anchor.insetBy(dx: -4, dy: -4).intersection(visible),
                        visibleFrame: visible, physicalNotch: nil)
        }
        return nil
    }

    func containsTrigger(_ point: CGPoint) -> Bool {
        point.x.isFinite && point.y.isFinite && point.x >= triggerFrame.minX && point.x <= triggerFrame.maxX
            && point.y >= triggerFrame.minY && point.y <= triggerFrame.maxY
    }

    func cardFrame(height: CGFloat, width: CGFloat = 360) -> CGRect {
        if let physicalNotch { return physicalNotch.cardFrame(height: height, width: width) }
        let cardWidth = min(width.isFinite ? max(0, width) : 360, visibleFrame.width - 16)
        let cardHeight = min(height.isFinite ? max(0, height) : 0, anchorFrame.minY - visibleFrame.minY - 8)
        let x = min(max(anchorFrame.midX - cardWidth / 2, visibleFrame.minX + 8), visibleFrame.maxX - 8 - cardWidth)
        return CGRect(x: x, y: anchorFrame.minY - cardHeight, width: cardWidth, height: cardHeight)
    }

    private static func valid(_ frame: CGRect) -> Bool {
        frame.origin.x.isFinite && frame.origin.y.isFinite && frame.width.isFinite && frame.height.isFinite
            && frame.width > 0 && frame.height > 0 && frame.maxX.isFinite && frame.maxY.isFinite
    }
}

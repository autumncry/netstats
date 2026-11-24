import AppKit
import XCTest
@testable import NetStatsCore

final class StatusItemContextMenuTests: XCTestCase {
    @MainActor
    func testMenuRefreshesMetricsAndLanguageWhenOpenedAgain() throws {
        _ = NSApplication.shared
        var language: AppLanguage = .english
        var lines: [String] = []
        var tracking: [Bool] = []
        let controller = StatusItemContextMenu(language: { language }, overviewLines: { lines },
                                               onTrackingChanged: { tracking.append($0) },
                                               showCard: {}, showDetails: {}, settings: {}, quit: {})
        let menu = controller.menu
        XCTAssertTrue(menu.delegate === controller)
        menu.delegate?.menuNeedsUpdate?(menu)
        XCTAssertEqual(menu.items.first?.title, "Open Card")
        controller.menuWillOpen(menu)
        controller.menuDidClose(menu)

        language = .simplifiedChinese
        lines = ["CPU: 18%", "内存: 45%"]
        menu.delegate?.menuNeedsUpdate?(menu)
        XCTAssertEqual(Array(menu.items.prefix(2).map(\.title)), lines)
        XCTAssertTrue(menu.items.prefix(2).allSatisfy { !$0.isEnabled && $0.action == nil })
        XCTAssertTrue(menu.items[2].isSeparatorItem)
        XCTAssertEqual(menu.item(withTag: StatusItemContextMenu.Command.quit.rawValue)?.title, "退出 NetStats")
        controller.menuWillOpen(menu)
        controller.menuDidClose(menu)

        lines = []
        menu.delegate?.menuNeedsUpdate?(menu)
        XCTAssertEqual(menu.items.first?.title, "打开卡片")
        XCTAssertEqual(tracking, [true, false, true, false])
    }

    @MainActor
    func testTopBarAccessibilitySurvivesNativeTooltipSuppression() {
        _ = NSApplication.shared
        let anchor = NotchDropDestinationView(frame: .zero)
        var presses = 0
        anchor.onClick = { presses += 1 }
        anchor.setTopBarAppearance(true, language: .simplifiedChinese)
        if StatusItemTooltipPolicy.usesNativeTooltips {
            XCTAssertNotNil(anchor.toolTip)
        } else {
            XCTAssertNil(anchor.toolTip)
        }
        XCTAssertEqual(anchor.accessibilityLabel(), "打开 NetStats 屏顶卡片")
        XCTAssertTrue(anchor.accessibilityPerformPress())
        XCTAssertEqual(presses, 1)
        anchor.setTopBarAppearance(false, language: .simplifiedChinese)
        XCTAssertNil(anchor.toolTip)
    }

    @MainActor
    func testModernMenuDispatchRequiresASecondaryClickInsideTheItemsOwnWindow() throws {
        _ = NSApplication.shared
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 200, height: 30),
                              styleMask: .borderless, backing: .buffered, defer: false)
        let other = NSWindow(contentRect: window.frame, styleMask: .borderless, backing: .buffered, defer: false)
        let button = NSButton(frame: NSRect(x: 100, y: 0, width: 40, height: 30))
        try XCTUnwrap(window.contentView).addSubview(button)
        func action(_ type: NSEvent.EventType, x: CGFloat = 120, modifiers: NSEvent.ModifierFlags = [],
                    in target: NSWindow? = nil, expanded: Bool = false) throws -> StatusItemClickAction? {
            let event = try XCTUnwrap(NSEvent.mouseEvent(with: type, location: NSPoint(x: x, y: 15),
                                                         modifierFlags: modifiers, timestamp: 0,
                                                         windowNumber: (target ?? window).windowNumber,
                                                         context: nil, eventNumber: 0, clickCount: 1, pressure: 1))
            return StatusItemClickAction.sessionAction(for: event, button: button, expanded: expanded)
        }
        XCTAssertEqual(try action(.rightMouseDown), .contextMenu)
        XCTAssertEqual(try action(.leftMouseDown, modifiers: .control), .contextMenu)
        XCTAssertNil(try action(.rightMouseDown, x: 20))
        XCTAssertNil(try action(.rightMouseDown, in: other))
        XCTAssertNil(try action(.leftMouseDown), "AppKit starts the expanded-interface session")
        XCTAssertEqual(try action(.leftMouseDown, expanded: true), .toggleCard)
    }

    func testSecondaryClicksOpenMenuAndOrdinaryLeftClickKeepsCardToggle() {
        XCTAssertEqual(StatusItemClickAction.resolve(type: .rightMouseUp, modifiers: []), .contextMenu)
        XCTAssertEqual(StatusItemClickAction.resolve(type: .leftMouseUp, modifiers: .control), .contextMenu)
        XCTAssertEqual(StatusItemClickAction.resolve(type: .leftMouseUp, modifiers: []), .toggleCard)
        XCTAssertEqual(StatusItemClickAction.resolve(type: .leftMouseUp, modifiers: .command), .toggleCard)
        XCTAssertEqual(StatusItemClickAction.resolve(type: nil, modifiers: []), .toggleCard)
    }

    @MainActor
    func testLocalizedMenuActionsOpenRequestedSurfaceAndQuit() throws {
        _ = NSApplication.shared
        for language in AppLanguage.allCases {
            var visibleSurface: String?
            var didQuit = false
            let controller = StatusItemContextMenu(language: { language }, overviewLines: { [] },
                                                   onTrackingChanged: { _ in },
                                                   showCard: { visibleSurface = "card" },
                                                   showDetails: { visibleSurface = "details" },
                                                   settings: { visibleSurface = "settings" },
                                                   quit: { didQuit = true })
            func select(_ command: StatusItemContextMenu.Command) throws {
                let item = try XCTUnwrap(controller.menu.item(withTag: command.rawValue))
                XCTAssertTrue(item.isEnabled)
                controller.menu.performActionForItem(at: controller.menu.index(of: item))
            }
            try select(.showCard)
            XCTAssertEqual(visibleSurface, "card")
            try select(.showDetails)
            XCTAssertEqual(visibleSurface, "details")
            try select(.settings)
            XCTAssertEqual(visibleSurface, "settings")
            XCTAssertFalse(didQuit)
            try select(.quit)
            XCTAssertTrue(didQuit, "The menu must dispatch the real quit action, not merely close a panel")
            XCTAssertEqual(visibleSurface, "settings")
        }
    }
}

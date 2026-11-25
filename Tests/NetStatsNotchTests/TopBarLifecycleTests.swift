import AppKit
import XCTest
@testable import NetStatsCore

final class TopBarLifecycleTests: XCTestCase {
    @MainActor func testTopBarSurvivesDisabledShelfAndTracksPresentationAndStop() throws {
        _ = NSApplication.shared
        guard !NSScreen.screens.isEmpty else { throw XCTSkip("Requires an AppKit display") }
        let suite = "netstats-topbar-lifecycle-\(UUID())"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(suite)
        defer { defaults.removePersistentDomain(forName: suite); try? FileManager.default.removeItem(at: directory) }
        let display = DisplaySettings(defaults: defaults)
        display.notchEnabled = true
        display.topEdgeMode = .topBar
        let settings = HubSettings(defaults: defaults)
        settings.enabledFeatures = [.network, .device]
        let store = HubStore(metricsStore: MetricsStore(), displaySettings: display, settings: settings,
                             defaults: defaults, storageDirectory: directory)
        let controller = NotchPanelController(hubStore: store, displaySettings: display)
        defer { controller.stop(); store.stop() }
        controller.start()
        let anchor = try XCTUnwrap(NSApp.windows.first { window in
            (window.contentView as? NotchDropDestinationView)?.onClick != nil
        })
        let destination = try XCTUnwrap(anchor.contentView as? NotchDropDestinationView)
        XCTAssertTrue(anchor.isVisible, "Top bar remains useful even when Shelf is disabled")
        XCTAssertFalse(destination.acceptsFiles())
        XCTAssertTrue(destination.accessibilityPerformPress())
        let card = try XCTUnwrap(NSApp.windows.first { $0 !== anchor && $0 is HubPanel && $0.isVisible })
        let grip = try XCTUnwrap(destination.subviews.compactMap { $0 as? NSVisualEffectView }.first)
        XCTAssertTrue(grip.isHidden, "The expanded card has one visible contour; the collapsed grip remains only as a drop target")

        controller.togglePin()
        XCTAssertTrue(controller.isPinned)
        let hubPanel = try XCTUnwrap(card as? HubPanel)
        XCTAssertTrue(hubPanel.onNavigatePage?(.next) == true)
        XCTAssertEqual(store.selected, .device)
        XCTAssertFalse(hubPanel.suppressesPageNavigation, "Pinning must not count as a field or drag hold")
        NSWorkspace.shared.notificationCenter.post(name: NSWorkspace.didActivateApplicationNotification, object: nil)
        XCTAssertTrue(card.isVisible, "A pinned card survives switching to another app")
        XCTAssertTrue(controller.isPinned)
        controller.togglePin()
        XCTAssertFalse(controller.isPinned)
        NSWorkspace.shared.notificationCenter.post(name: NSWorkspace.didActivateApplicationNotification, object: nil)
        XCTAssertFalse(card.isVisible)
        XCTAssertFalse(grip.isHidden, "The collapsed grip returns when the card closes")

        XCTAssertTrue(destination.accessibilityPerformPress())
        controller.togglePin()
        controller.setDetailsVisible(true)
        XCTAssertFalse(controller.isPinned, "An explicit dismissal clears the pin before the card can reopen")
        XCTAssertFalse(anchor.isVisible, "Other monitoring panels suppress the top-edge entrance")
        controller.setDetailsVisible(false)
        XCTAssertTrue(anchor.isVisible)
        XCTAssertTrue(destination.accessibilityPerformPress())
        controller.togglePin()
        NSWorkspace.shared.notificationCenter.post(name: NSWorkspace.sessionDidResignActiveNotification, object: nil)
        XCTAssertFalse(card.isVisible)
        XCTAssertFalse(anchor.isVisible)
        XCTAssertFalse(controller.isPinned)
        NSWorkspace.shared.notificationCenter.post(name: NSWorkspace.sessionDidBecomeActiveNotification, object: nil)
        XCTAssertTrue(anchor.isVisible)
        XCTAssertFalse(card.isVisible, "Restoring the session requires a fresh activation")
        controller.stop()
        XCTAssertFalse(anchor.isVisible)
    }
}

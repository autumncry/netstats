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
        settings.enabledFeatures = [.network]
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
        XCTAssertTrue(NSApp.windows.contains { $0 !== anchor && $0 is HubPanel && $0.isVisible })
        controller.setDetailsVisible(true)
        XCTAssertFalse(anchor.isVisible, "Other monitoring panels suppress the top-edge entrance")
        controller.setDetailsVisible(false)
        XCTAssertTrue(anchor.isVisible)
        controller.stop()
        XCTAssertFalse(anchor.isVisible)
    }
}

import AppKit
import XCTest
@testable import NetStatsCore

final class MonitorPresentationCoordinatorTests: XCTestCase {
    @MainActor
    func testSettingsMayRemainOpenWithoutDisablingNotchHover() throws {
        _ = NSApplication.shared
        let suite = "netstats-coordinator-\(UUID())"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(suite)
        defer {
            defaults.removePersistentDomain(forName: suite)
            try? FileManager.default.removeItem(at: folder)
        }
        let display = DisplaySettings(defaults: defaults)
        display.publicIPLookupEnabled = false
        let metrics = MetricsStore()
        let hub = HubStore(metricsStore: metrics, displaySettings: display,
                           settings: HubSettings(defaults: defaults), defaults: defaults, storageDirectory: folder)
        let coordinator = MonitorPresentationCoordinator(metricsStore: metrics, hubStore: hub,
                                                         displaySettings: display, ipGeolocationStore: IPGeolocationStore(),
                                                         clashStatusStore: ClashStatusStore())
        defer { coordinator.stop(); hub.stop() }
        XCTAssertFalse(coordinator.isHoverSuppressed)
        coordinator.showSettings(activate: false)
        XCTAssertTrue(coordinator.isSettingsPresented)
        XCTAssertFalse(coordinator.isHoverSuppressed, "A persistent Settings window must not disable hover")

        coordinator.showDetails()
        XCTAssertTrue(coordinator.isHoverSuppressed, "The detailed monitoring panel still excludes the notch card")
        coordinator.showSettings(activate: false)
        XCTAssertTrue(coordinator.isSettingsPresented)
        XCTAssertFalse(coordinator.isHoverSuppressed, "Returning from monitoring to Settings must restore hover")
    }
}

import XCTest
@testable import NetStatsCore

final class TopEdgeSettingsTests: XCTestCase {
    @MainActor func testModePersistsWithoutChangingExistingEnabledChoice() throws {
        let suite = "netstats-topedge-\(UUID())"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(true, forKey: "display.notchEnabled")
        let settings = DisplaySettings(defaults: defaults)
        XCTAssertEqual(settings.topEdgeMode, .automatic)
        XCTAssertTrue(settings.notchEnabled)
        settings.topEdgeMode = .topBar
        let restored = DisplaySettings(defaults: defaults)
        XCTAssertEqual(restored.topEdgeMode, .topBar)
        XCTAssertTrue(restored.notchEnabled)
        restored.notchAvailable = false
        restored.activeTopEdgeMode = .topBar
        XCTAssertTrue(restored.notchEnabled)
    }

    @MainActor func testUnknownModeDefaultsToAutomaticAndFreshInstallRemainsOptIn() throws {
        let suite = "netstats-topedge-\(UUID())"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set("future-mode", forKey: "display.topEdgeMode")
        let settings = DisplaySettings(defaults: defaults)
        XCTAssertEqual(settings.topEdgeMode, .automatic)
        XCTAssertFalse(settings.notchEnabled)
    }
}

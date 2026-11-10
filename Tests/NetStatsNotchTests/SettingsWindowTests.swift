import AppKit
import XCTest
@testable import NetStatsCore

final class SettingsWindowTests: XCTestCase {
    @MainActor
    func testSettingsUsesOneRegularWindowAndSurvivesLossOfFocus() throws {
        _ = NSApplication.shared
        let name = "netstats-settings-window-\(UUID())"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        defer { defaults.removePersistentDomain(forName: name); try? FileManager.default.removeItem(at: directory) }
        let display = DisplaySettings(defaults: defaults)
        let metrics = MetricsStore()
        let hub = HubStore(metricsStore: metrics, displaySettings: display,
                           settings: HubSettings(defaults: defaults), defaults: defaults, storageDirectory: directory)
        let controller = SettingsWindowController(hubStore: hub, displaySettings: display, metricsStore: metrics)
        defer { controller.stop(); hub.stop() }
        let window = try XCTUnwrap(controller.window)
        XCTAssertTrue(window.styleMask.contains([.titled, .closable, .resizable]))
        XCTAssertFalse(window.styleMask.contains(.nonactivatingPanel))
        XCTAssertTrue(window.canBecomeKey)
        var visibility: [Bool] = []
        controller.onVisibilityChange = { visibility.append($0) }
        controller.showSettings(activate: false)
        controller.showSettings(activate: false)
        XCTAssertTrue(controller.window === window)
        XCTAssertTrue(controller.isPresented)
        XCTAssertTrue(window.canBecomeMain, "The visible Settings window must support main-window status")
        window.resignKey()
        XCTAssertTrue(controller.isPresented, "Losing focus must not dismiss Settings")
        window.close()
        XCTAssertFalse(controller.isPresented)
        controller.showSettings(activate: false)
        XCTAssertTrue(controller.window === window, "Closing and reopening reuses the same Settings instance")
        XCTAssertEqual(visibility, [true, false, true])
    }

    func testSettingsSectionsCoverBothHubAndExistingDisplayControls() {
        XCTAssertEqual(SettingsSection.allCases.map(\.rawValue), ["general", "features", "display", "calendar", "weather", "clipboard", "shelf", "about"])
        XCTAssertEqual(SettingsSection.display.title(.simplifiedChinese), "显示与监控")
        XCTAssertEqual(SettingsSection.clipboard.title(.english), "Clipboard")
    }
}

import XCTest
@testable import NetStatsCore

final class HubSettingsTests: XCTestCase {
    func testDefaultAndExplicitEmptyFeaturesSurviveReload() async throws {
        try await MainActor.run {
            let name = "netstats-hub-test-\(UUID())"
            let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
            defer { defaults.removePersistentDomain(forName: name) }
            let settings = HubSettings(defaults: defaults)
            XCTAssertEqual(settings.enabledFeatures, [.network, .device, .shelf])
            settings.enabledFeatures = []
            XCTAssertEqual(HubSettings(defaults: defaults).enabledFeatures, [])
        }
    }

    func testSelectionFallsBackInDockOrderAndHeightsStayCompact() {
        XCTAssertEqual(HubFeature.defaultSelection(in: [.weather, .network]), .network)
        XCTAssertEqual(HubFeature.defaultSelection(in: [.clipboard, .device]), .device)
        XCTAssertNil(HubFeature.defaultSelection(in: []))
        XCTAssertEqual(HubFeature.network.cardHeight, 208)
        XCTAssertEqual(HubFeature.calendar.cardHeight, 248)
        XCTAssertEqual(HubFeature.device.cardHeight, 232)
    }

    func testInvalidGPUValuesAreUnavailable() {
        XCTAssertNil(GPUReading.normalizedUtilization(nil))
        XCTAssertNil(GPUReading.normalizedUtilization(-1))
        XCTAssertNil(GPUReading.normalizedUtilization(101))
        XCTAssertEqual(GPUReading.normalizedUtilization(42), 0.42)
    }

    @MainActor
    func testDisablingSelectedFeatureFallsBackAndAllOffKeepsSettingsReachable() async throws {
        let name = "netstats-hub-select-\(UUID())"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        defer {
            defaults.removePersistentDomain(forName: name)
            try? FileManager.default.removeItem(at: folder)
        }
        let settings = HubSettings(defaults: defaults)
        let display = DisplaySettings(defaults: defaults)
        let store = HubStore(metricsStore: MetricsStore(), displaySettings: display,
                             settings: settings, defaults: defaults, storageDirectory: folder)
        store.select(feature: .device)
        XCTAssertEqual(store.selected, .device)
        settings.set(false, feature: .device)
        try await Task.sleep(for: .milliseconds(30))
        XCTAssertEqual(store.selected, .network)
        settings.enabledFeatures = []
        try await Task.sleep(for: .milliseconds(30))
        XCTAssertNil(store.selected)
        XCTAssertEqual(store.currentHeight, 208)
        settings.set(true, feature: .shelf)
        try await Task.sleep(for: .milliseconds(30))
        XCTAssertEqual(store.selected, .shelf)
        store.stop()
    }
}

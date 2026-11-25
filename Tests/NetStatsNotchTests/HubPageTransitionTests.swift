import XCTest
@testable import NetStatsCore

final class HubPageTransitionTests: XCTestCase {
    @MainActor
    func testUserSelectionMovesInFeatureOrderIncludingSkippedFeatures() throws {
        try withStore { store, _ in
            store.select(feature: .clipboard, animated: true)
            XCTAssertEqual(store.selected, .clipboard)
            XCTAssertEqual(store.pageTransitionDirection, .next)
            store.select(feature: .device, animated: true)
            XCTAssertEqual(store.selected, .device)
            XCTAssertEqual(store.pageTransitionDirection, .previous)
        }
    }

    @MainActor
    func testSwipesRetargetSynchronouslyAndStopAtEdges() throws {
        try withStore { store, settings in
            settings.enabledFeatures = [.network, .weather, .shelf]
            let firstVisit = store.selectionRevision
            XCTAssertTrue(store.selectAdjacent(.next))
            XCTAssertEqual(store.selected, .weather)
            XCTAssertEqual(store.pageTransitionDirection, .next)
            XCTAssertTrue(store.selectAdjacent(.previous))
            XCTAssertEqual(store.selected, .network)
            XCTAssertEqual(store.pageTransitionDirection, .previous)
            XCTAssertNotEqual(store.selectionRevision, firstVisit, "A returning page must not accept callbacks from its departing instance")
            XCTAssertFalse(store.selectAdjacent(.previous))
            XCTAssertEqual(store.selected, .network)
            XCTAssertEqual(store.pageTransitionDirection, .previous)
        }
    }

    @MainActor
    func testProgrammaticSelectionAndReopeningDoNotAnimate() throws {
        try withStore { store, _ in
            XCTAssertNil(store.pageTransitionDirection)
            store.select(feature: .device, animated: true)
            XCTAssertNotNil(store.pageTransitionDirection)
            store.select(feature: .shelf)
            XCTAssertNil(store.pageTransitionDirection, "File-drop selection should be immediate")
            store.select(feature: .device, animated: true)
            store.selectDefault()
            XCTAssertEqual(store.selected, .network)
            XCTAssertNil(store.pageTransitionDirection, "Reopening should not replay a page transition")
        }
    }

    @MainActor
    func testSelectingCurrentOrDisabledFeatureDoesNotRestartNavigation() throws {
        try withStore { store, settings in
            store.select(feature: .device, animated: true)
            let direction = store.pageTransitionDirection
            let revision = store.selectionRevision
            store.select(feature: .device, animated: true)
            XCTAssertEqual(store.pageTransitionDirection, direction)
            XCTAssertEqual(store.selectionRevision, revision)
            settings.enabledFeatures.remove(.calendar)
            store.select(feature: .calendar, animated: true)
            XCTAssertEqual(store.selected, .device)
            XCTAssertEqual(store.pageTransitionDirection, direction)
            XCTAssertEqual(store.selectionRevision, revision)
        }
    }

    @MainActor private func withStore(_ perform: (HubStore, HubSettings) throws -> Void) throws {
        let suite = "netstats-transition-\(UUID())"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(suite)
        defer { defaults.removePersistentDomain(forName: suite); try? FileManager.default.removeItem(at: folder) }
        let settings = HubSettings(defaults: defaults)
        settings.enabledFeatures = Set(HubFeature.allCases)
        let store = HubStore(metricsStore: MetricsStore(), displaySettings: DisplaySettings(defaults: defaults),
                             settings: settings, defaults: defaults, storageDirectory: folder)
        defer { store.stop() }
        try perform(store, settings)
    }
}

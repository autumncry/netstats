import Foundation
import XCTest
@testable import NetStatsCore

final class HubPageSwipeTests: XCTestCase {
    func testHorizontalGestureNavigatesOnceAndIgnoresItsMomentum() {
        var swipe = HubPageSwipe()
        XCTAssertNil(swipe.update(x: -12, y: 1, phase: .began).direction)
        XCTAssertEqual(swipe.update(x: -30, y: 2, phase: .changed).direction, .next)
        XCTAssertNil(swipe.update(x: -120, y: 0, phase: .changed).direction)
        XCTAssertTrue(swipe.update(x: 0, y: 0, phase: .ended).consumed)
        let momentum = swipe.update(x: -200, y: 0, phase: .none, momentum: true)
        XCTAssertNil(momentum.direction)
        XCTAssertTrue(momentum.consumed)
        XCTAssertEqual(swipe.update(x: 48, y: 1, phase: .began).direction, .previous)
    }

    func testVerticalScrollRemainsAvailableEvenAfterHorizontalDrift() {
        var swipe = HubPageSwipe()
        XCTAssertFalse(swipe.update(x: 1, y: -20, phase: .began).consumed)
        let drift = swipe.update(x: -90, y: -2, phase: .changed)
        XCTAssertFalse(drift.consumed)
        XCTAssertNil(drift.direction)
        XCTAssertFalse(swipe.update(x: 0, y: 0, phase: .ended).consumed)
    }

    func testMouseWheelAndUnphasedScrollNeverNavigate() {
        var swipe = HubPageSwipe()
        XCTAssertNil(swipe.update(x: -200, y: 0, phase: .began, precise: false).direction)
        XCTAssertNil(swipe.update(x: -200, y: 0, phase: .none).direction)
        XCTAssertNil(swipe.update(x: -200, y: 0, phase: .changed).direction)
    }

    func testSmallOrDiagonalGesturesDoNotChangePages() {
        var swipe = HubPageSwipe()
        XCTAssertNil(swipe.update(x: -20, y: 0, phase: .began).direction)
        XCTAssertNil(swipe.update(x: -19, y: 0, phase: .changed).direction)
        _ = swipe.update(x: 0, y: 0, phase: .ended)
        XCTAssertNil(swipe.update(x: -30, y: -28, phase: .began).direction)
        XCTAssertNil(swipe.update(x: -30, y: -28, phase: .changed).direction)
    }

    func testEditingOrDraggingBlocksTheEntireGestureUntilTheNextBegin() {
        var swipe = HubPageSwipe()
        XCTAssertFalse(swipe.update(x: -50, y: 0, phase: .began, suppressed: true).consumed)
        XCTAssertNil(swipe.update(x: -60, y: 0, phase: .changed).direction)
        _ = swipe.update(x: 0, y: 0, phase: .ended)
        XCTAssertEqual(swipe.update(x: -50, y: 0, phase: .began).direction, .next)
        _ = swipe.update(x: 0, y: 0, phase: .ended)
        _ = swipe.update(x: -10, y: 0, phase: .began)
        _ = swipe.update(x: -10, y: 0, phase: .changed, suppressed: true)
        XCTAssertNil(swipe.update(x: -100, y: 0, phase: .changed).direction)
    }

    func testCancelledOrDismissedGesturesCannotCompleteLater() {
        var swipe = HubPageSwipe()
        _ = swipe.update(x: -30, y: 0, phase: .began)
        _ = swipe.update(x: 0, y: 0, phase: .cancelled)
        XCTAssertNil(swipe.update(x: -100, y: 0, phase: .changed).direction)
        _ = swipe.update(x: -30, y: 0, phase: .began)
        swipe.reset()
        XCTAssertNil(swipe.update(x: -100, y: 0, phase: .changed).direction)
        XCTAssertEqual(swipe.update(x: -50, y: 0, phase: .began).direction, .next)
    }

    @MainActor
    func testStoreNavigationSkipsDisabledFeaturesAndStopsAtBothEnds() throws {
        let suite = "netstats-swipe-\(UUID())"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(suite)
        defer {
            defaults.removePersistentDomain(forName: suite)
            try? FileManager.default.removeItem(at: directory)
        }
        let settings = HubSettings(defaults: defaults)
        settings.enabledFeatures = [.network, .calendar, .shelf]
        let store = HubStore(metricsStore: MetricsStore(), displaySettings: DisplaySettings(defaults: defaults),
                             settings: settings, defaults: defaults, storageDirectory: directory)
        defer { store.stop() }
        XCTAssertFalse(store.selectAdjacent(.previous))
        XCTAssertEqual(store.selected, .network)
        XCTAssertTrue(store.selectAdjacent(.next))
        XCTAssertEqual(store.selected, .calendar)
        XCTAssertTrue(store.selectAdjacent(.next))
        XCTAssertEqual(store.selected, .shelf)
        XCTAssertFalse(store.selectAdjacent(.next))
        XCTAssertEqual(store.selected, .shelf)
        XCTAssertTrue(store.selectAdjacent(.previous))
        XCTAssertEqual(store.selected, .calendar)
        settings.enabledFeatures = []
        XCTAssertFalse(store.selectAdjacent(.next))
    }
}

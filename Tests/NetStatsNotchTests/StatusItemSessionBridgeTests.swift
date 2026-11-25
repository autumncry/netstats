import Foundation
import XCTest
@testable import NetStatsCore

final class StatusItemSessionBridgeTests: XCTestCase {
    @MainActor func testUnsupportedStatusItemLeavesLegacyPathAvailable() {
        XCTAssertNil(StatusItemSessionBridge(statusItem: NSObject(), onBegin: {}, onEnd: { _ in }))
    }

    @MainActor func testDocumentedCallbacksTrackOneSessionAndIgnoreDuplicates() throws {
        let item = SessionBridgeTestItem()
        var begins = 0
        var endings: [Bool] = []
        let bridge = try XCTUnwrap(StatusItemSessionBridge(statusItem: item, onBegin: { begins += 1 },
                                                          onEnd: { endings.append($0) }))
        defer { bridge.stop() }
        XCTAssertTrue(item.expandedInterfaceDelegate === bridge)
        XCTAssertFalse(bridge.isActive)
        let session = SessionBridgeTestSession()
        item.expandedInterfaceSession = session
        XCTAssertTrue(bridge.isActive)
        bridge.statusItem(SessionBridgeTestItem(), didBegin: session)
        XCTAssertEqual(begins, 0, "A callback for another status item must not open this one")
        bridge.statusItem(item, didBegin: session)
        bridge.statusItem(item, didBegin: session)
        XCTAssertEqual(begins, 1)
        bridge.statusItemDidEndExpandedInterfaceSession(item, animated: true)
        XCTAssertTrue(endings.isEmpty, "AppKit clears the session before an end callback")
        item.expandedInterfaceSession = nil
        bridge.statusItemDidEndExpandedInterfaceSession(item, animated: true)
        bridge.statusItemDidEndExpandedInterfaceSession(item, animated: true)
        XCTAssertEqual(endings, [true])
        XCTAssertFalse(bridge.isActive)
    }

    @MainActor func testCancelDispatchesToTheCurrentSessionOnlyOnce() throws {
        let item = SessionBridgeTestItem()
        var ended = 0
        let bridge = try XCTUnwrap(StatusItemSessionBridge(statusItem: item, onBegin: {}, onEnd: { _ in ended += 1 }))
        defer { bridge.stop() }
        let session = SessionBridgeTestSession()
        item.expandedInterfaceSession = session
        bridge.statusItem(item, didBegin: session)
        bridge.cancel()
        bridge.cancel()
        XCTAssertEqual(session.cancelCount, 1)
        XCTAssertEqual(ended, 0, "Cancellation requests do not invent an AppKit end notification")
        item.expandedInterfaceSession = nil
        bridge.statusItemDidEndExpandedInterfaceSession(item, animated: false)
        XCTAssertEqual(ended, 1)
    }

    @MainActor func testStopSilencesSynchronousCancellationAndDetachesItself() throws {
        let item = SessionBridgeTestItem()
        var callbacks = 0
        let bridge = try XCTUnwrap(StatusItemSessionBridge(statusItem: item, onBegin: { callbacks += 1 },
                                                          onEnd: { _ in callbacks += 1 }))
        let session = SessionBridgeTestSession()
        item.expandedInterfaceSession = session
        bridge.statusItem(item, didBegin: session)
        session.onCancel = { [weak item, weak bridge] in
            guard let item, let bridge else { return }
            item.expandedInterfaceSession = nil
            bridge.statusItemDidEndExpandedInterfaceSession(item, animated: false)
        }
        bridge.stop()
        bridge.stop()
        XCTAssertEqual(session.cancelCount, 1)
        XCTAssertEqual(callbacks, 1)
        XCTAssertNil(item.expandedInterfaceDelegate)
        XCTAssertFalse(bridge.isActive)
    }

    @MainActor func testStopDoesNotCancelOrDetachANewerDelegateOwner() throws {
        let item = SessionBridgeTestItem()
        let bridge = try XCTUnwrap(StatusItemSessionBridge(statusItem: item, onBegin: {}, onEnd: { _ in }))
        let replacement = NSObject()
        let session = SessionBridgeTestSession()
        item.expandedInterfaceDelegate = replacement
        item.expandedInterfaceSession = session
        XCTAssertFalse(bridge.isActive)
        bridge.stop()
        XCTAssertTrue(item.expandedInterfaceDelegate === replacement)
        XCTAssertEqual(session.cancelCount, 0)
    }

    @MainActor func testBridgeDoesNotKeepTheStatusItemAlive() throws {
        weak var weakItem: SessionBridgeTestItem?
        let bridge = try autoreleasepool {
            let item = SessionBridgeTestItem()
            weakItem = item
            return try XCTUnwrap(StatusItemSessionBridge(statusItem: item, onBegin: {}, onEnd: { _ in }))
        }
        XCTAssertNil(weakItem)
        XCTAssertFalse(bridge.isActive)
        bridge.cancel()
        bridge.stop()
    }
}

@MainActor private final class SessionBridgeTestItem: NSObject {
    @objc dynamic weak var expandedInterfaceDelegate: NSObject?
    @objc dynamic var expandedInterfaceSession: NSObject?
}

@MainActor private final class SessionBridgeTestSession: NSObject {
    private(set) var cancelCount = 0
    var onCancel: (() -> Void)?
    @objc func cancel() {
        cancelCount += 1
        onCancel?()
    }
}

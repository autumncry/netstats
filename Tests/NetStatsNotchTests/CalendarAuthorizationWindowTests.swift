import AppKit
import EventKit
import XCTest
@testable import NetStatsCore

@MainActor
final class CalendarAuthorizationWindowTests: XCTestCase {
    func testDialogCanReturnToPreviousForegroundApplicationBeforeEventKitCompletes() {
        let focus = CalendarPromptFocus(previousPID: 42)
        focus.didActivate(.permissionDialog, at: 10)
        XCTAssertTrue(focus.shouldReturn(to: .permissionDialog, at: 11))
        XCTAssertTrue(focus.shouldReturn(to: .other(42), at: 11))
        focus.didActivate(.other(42), at: 11)
        XCTAssertTrue(focus.shouldReturn(to: .other(42), at: 11.005))
        XCTAssertFalse(focus.shouldReturn(to: .other(42), at: 12), "Leave a previous app the user switched back to in front")
    }

    func testAnotherApplicationOrNoPermissionPromptDoesNotTakeFocus() {
        let focus = CalendarPromptFocus(previousPID: 42)
        XCTAssertFalse(focus.shouldReturn(to: .other(42), at: 1))
        focus.didActivate(.permissionDialog, at: 2)
        XCTAssertFalse(focus.shouldReturn(to: .other(56), at: 3))
        focus.didActivate(.other(56), at: 3)
        XCTAssertFalse(focus.shouldReturn(to: .other(42), at: 3.1))
        XCTAssertFalse(focus.shouldReturn(to: .unknown, at: 3.2))
    }

    func testBothAuthorizationResultsReturnToTheExistingSettingsContent() async throws {
        for result in [EKAuthorizationStatus.fullAccess, .denied] {
            try await withSettings { controller, window in
                let content = try XCTUnwrap(window.contentViewController)
                var authorization = EKAuthorizationStatus.notDetermined
                let calendar = CalendarStore(currentAuthorization: { authorization }, requestFullAccess: { _ in
                    window.orderOut(nil)
                    authorization = result
                    return result == .fullAccess
                })
                await controller.requestCalendarAccess(calendar, frontmost: { NSRunningApplication.current })
                XCTAssertEqual(calendar.authorization, result)
                XCTAssertTrue(controller.isPresented)
                XCTAssertTrue(controller.window === window)
                XCTAssertTrue(window.contentViewController === content)
            }
        }
    }

    func testClosedSettingsAreNotReopenedByAnAuthorizationCompletion() async throws {
        try await withSettings { controller, window in
            let calendar = CalendarStore(currentAuthorization: { .notDetermined }, requestFullAccess: { _ in
                window.close()
                await Task.yield()
                return false
            })
            await controller.requestCalendarAccess(calendar, frontmost: { NSRunningApplication.current })
            XCTAssertFalse(controller.isPresented)
        }
    }

    func testMinimizedSettingsAreNotRestoredByAnAuthorizationCompletion() async throws {
        try await withSettings { controller, window in
            let calendar = CalendarStore(currentAuthorization: { .notDetermined }, requestFullAccess: { _ in
                // AppKit sends the delegate callback before finishing the
                // minimize animation; the authorization may return mid-animation.
                controller.windowWillMiniaturize(Notification(name: NSWindow.willMiniaturizeNotification, object: window))
                window.orderOut(nil)
                await Task.yield()
                return false
            })
            await controller.requestCalendarAccess(calendar, frontmost: { NSRunningApplication.current })
            XCTAssertFalse(controller.isPresented)
        }
    }

    private func withSettings(_ body: @MainActor (SettingsWindowController, NSWindow) async throws -> Void) async throws {
        _ = NSApplication.shared
        let name = "netstats-calendar-window-\(UUID())"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        defer { defaults.removePersistentDomain(forName: name); try? FileManager.default.removeItem(at: directory) }
        let settings = DisplaySettings(defaults: defaults)
        let metrics = MetricsStore()
        let hub = HubStore(metricsStore: metrics, displaySettings: settings,
                           settings: HubSettings(defaults: defaults), defaults: defaults, storageDirectory: directory)
        let controller = SettingsWindowController(hubStore: hub, displaySettings: settings, metricsStore: metrics)
        defer { controller.stop(); hub.stop() }
        controller.showSettings(activate: false)
        let window = try XCTUnwrap(controller.window)
        try await body(controller, window)
    }
}

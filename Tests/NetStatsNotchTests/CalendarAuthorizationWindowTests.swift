import AppKit
import EventKit
import XCTest
@testable import NetStatsCore

@MainActor
final class CalendarAuthorizationWindowTests: XCTestCase {
    func testEventKitDecisionCannotRestoreUntilTheSecureDialogHasDismissed() {
        let focus = CalendarPromptFocus(previousPID: 42)
        focus.didActivate(.permissionDialog)
        focus.decisionReceived()
        XCTAssertEqual(focus.dismissalAction(front: .permissionDialog), .wait)
        focus.didActivate(.other(42))
        XCTAssertEqual(focus.dismissalAction(front: .other(42)), .restore)
    }

    func testSystemMayHandBackFocusBeforeEventKitReportsTheDecision() {
        let focus = CalendarPromptFocus(previousPID: 42)
        focus.didActivate(.permissionDialog)
        focus.didActivate(.other(42))
        focus.decisionReceived()
        XCTAssertEqual(focus.dismissalAction(front: .other(42)), .restore)
        XCTAssertEqual(focus.dismissalAction(front: .settings), .restore)
    }

    func testAnotherAppTakesPrecedenceOverPendingPermissionRestoration() {
        let focus = CalendarPromptFocus(previousPID: 42)
        focus.didActivate(.permissionDialog)
        focus.didActivate(.other(56))
        focus.decisionReceived()
        XCTAssertEqual(focus.dismissalAction(front: .other(56)), .abandon)
        XCTAssertEqual(focus.dismissalAction(front: .other(42)), .abandon)
        let withoutPrompt = CalendarPromptFocus(previousPID: nil)
        withoutPrompt.decisionReceived()
        XCTAssertEqual(withoutPrompt.dismissalAction(front: .other(999)), .abandon)
    }

    func testPromptMayReturnToTheActualInitiatingApplicationInsteadOfTheOriginalOne() {
        let focus = CalendarPromptFocus(previousPID: 7, initiatingOwner: .other(42))
        focus.decisionReceived()
        XCTAssertEqual(focus.dismissalAction(front: .other(42)), .restore,
                       "Workspace need not deliver an activation notification for a system dialog")
    }

    func testDecisionThenSystemDialogDismissalCanRevealAnUnanticipatedPreviousOwner() {
        let focus = CalendarPromptFocus(previousPID: nil)
        focus.didActivate(.permissionDialog)
        focus.decisionReceived()
        XCTAssertEqual(focus.dismissalAction(front: .permissionDialog), .wait)
        XCTAssertEqual(focus.dismissalAction(front: .other(42)), .restore)
        focus.didActivate(.other(56))
        XCTAssertEqual(focus.dismissalAction(front: .other(56)), .abandon)
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
                await controller.requestCalendarAccess(calendar, frontmost: { .settings })
                XCTAssertEqual(calendar.authorization, result)
                XCTAssertTrue(controller.isPresented)
                XCTAssertTrue(controller.window === window)
                XCTAssertTrue(window.contentViewController === content)
            }
        }
    }

    func testControllerWaitsForSecureFocusToEndBeforeBringingBackTheSameWindow() async throws {
        try await withSettings { controller, window in
            var granted = false
            var readsDuringDismissal = 0
            let calendar = CalendarStore(currentAuthorization: { granted ? .fullAccess : .notDetermined },
                                         requestFullAccess: { _ in
                window.orderOut(nil)
                granted = true
                return true
            })
            await controller.requestCalendarAccess(calendar, frontmost: {
                guard granted else { return .settings }
                readsDuringDismissal += 1
                if readsDuringDismissal <= 2 {
                    XCTAssertFalse(window.isVisible, "Do not order Settings over the secure prompt")
                    return .permissionDialog
                }
                return .settings
            })
            XCTAssertGreaterThanOrEqual(readsDuringDismissal, 3)
            XCTAssertTrue(window.isVisible)
            XCTAssertTrue(controller.window === window)
        }
    }

    func testClosedSettingsAreNotReopenedByAnAuthorizationCompletion() async throws {
        try await withSettings { controller, window in
            let calendar = CalendarStore(currentAuthorization: { .notDetermined }, requestFullAccess: { _ in
                window.close()
                await Task.yield()
                return false
            })
            await controller.requestCalendarAccess(calendar, frontmost: { .settings })
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
            await controller.requestCalendarAccess(calendar, frontmost: { .settings })
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

import AppKit
import XCTest
@testable import NetStatsCore

final class HubPanelFrameAnimationTests: XCTestCase {
    private let compact = CGRect(x: -10000, y: -10000, width: 360, height: 208)
    private var expanded: CGRect { CGRect(x: compact.minX, y: compact.minY - 40, width: 360, height: 248) }

    @MainActor
    func testReversingBeforeFirstFrameFinishesAtLatestTarget() async throws {
        let panel = try makePanel()
        defer { panel.close() }
        panel.setCardFrame(expanded, animated: true)
        panel.setCardFrame(compact, animated: true)
        try await Task.sleep(for: .milliseconds(450))
        XCTAssertEqual(panel.frame, compact)
    }

    @MainActor
    func testImmediateResizeCancelsAnInFlightPageResize() async throws {
        let panel = try makePanel()
        defer { panel.close() }
        panel.setCardFrame(expanded, animated: true)
        try await Task.sleep(for: .milliseconds(50))
        panel.setCardFrame(compact, animated: false)
        try await Task.sleep(for: .milliseconds(450))
        XCTAssertEqual(panel.frame, compact)
    }

    @MainActor
    func testReopeningDoesNotInheritTheHiddenPanelsResizeTarget() async throws {
        let panel = try makePanel()
        defer { panel.close() }
        panel.setCardFrame(expanded, animated: true)
        panel.orderOut(nil)
        panel.endInteraction()
        panel.setCardFrame(compact, animated: false)
        panel.orderFrontRegardless()
        try await Task.sleep(for: .milliseconds(450))
        XCTAssertEqual(panel.frame, compact)
    }

    @MainActor private func makePanel() throws -> HubPanel {
        _ = NSApplication.shared
        guard !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion else {
            throw XCTSkip("Window animation is disabled by Reduce Motion")
        }
        let panel = HubPanel()
        panel.setFrame(compact, display: true)
        panel.orderFrontRegardless()
        XCTAssertTrue(panel.isVisible)
        return panel
    }
}

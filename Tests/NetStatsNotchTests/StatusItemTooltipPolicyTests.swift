import AppKit
import XCTest
@testable import NetStatsCore

final class StatusItemTooltipPolicyTests: XCTestCase {
    func testDisabledHoverMetricsDoNotRegisterAppNameTooltip() {
        XCTAssertNil(StatusItemTooltipPolicy.text(lines: [], macOSMajorVersion: 26))
        XCTAssertNil(StatusItemTooltipPolicy.text(lines: [], macOSMajorVersion: 27))
    }

    func testMacOS27DoesNotUseTheMisplacedNativeTooltipPath() {
        XCTAssertNil(StatusItemTooltipPolicy.text(lines: ["CPU: 30%"], macOSMajorVersion: 27))
        XCTAssertEqual(StatusItemTooltipPolicy.text(lines: ["CPU: 30%", "Memory: 50%"], macOSMajorVersion: 26), "CPU: 30%\nMemory: 50%")
    }

    @MainActor func testRepeatedSamplesDoNotReassignUnchangedTooltip() {
        _ = NSApplication.shared
        let view = TooltipTrackingView()
        StatusItemTooltipPolicy.update(view, lines: ["CPU: 30%"], macOSMajorVersion: 26)
        StatusItemTooltipPolicy.update(view, lines: ["CPU: 30%"], macOSMajorVersion: 26)
        XCTAssertEqual(view.assignments, 1)
        StatusItemTooltipPolicy.update(view, lines: ["CPU: 31%"], macOSMajorVersion: 27)
        XCTAssertNil(view.toolTip)
        XCTAssertEqual(view.assignments, 2)
        StatusItemTooltipPolicy.update(view, lines: ["CPU: 32%"], macOSMajorVersion: 27)
        XCTAssertEqual(view.assignments, 2)
    }
}

@MainActor private final class TooltipTrackingView: NSView {
    var assignments = 0
    override var toolTip: String? {
        get { super.toolTip }
        set { assignments += 1; super.toolTip = newValue }
    }
}

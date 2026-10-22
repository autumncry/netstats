import CoreGraphics
import XCTest
@testable import NetStatsCore

final class NotchSummaryLayoutTests: XCTestCase {
    func testHardwareAndNetworkShowBothRowsAtFullHeight() {
        for extras: Set<MonitorModule> in [[], [.disk], [.clash], [.disk, .clash]] {
            let layout = NotchSummaryLayout(modules: extras.union([.hardware, .network]))

            XCTAssertTrue(layout.hardwareEnabled)
            XCTAssertTrue(layout.networkEnabled)
            XCTAssertEqual(layout.contentHeight, 220)
        }
    }

    func testHardwareAloneShowsOnlyHardwareRowAtCompactHeight() {
        for extras: Set<MonitorModule> in [[], [.disk], [.clash], [.disk, .clash]] {
            let layout = NotchSummaryLayout(modules: extras.union([.hardware]))

            XCTAssertTrue(layout.hardwareEnabled)
            XCTAssertFalse(layout.networkEnabled)
            XCTAssertEqual(layout.contentHeight, 144)
        }
    }

    func testNetworkAloneShowsOnlyNetworkRowAtCompactHeight() {
        for extras: Set<MonitorModule> in [[], [.disk], [.clash], [.disk, .clash]] {
            let layout = NotchSummaryLayout(modules: extras.union([.network]))

            XCTAssertFalse(layout.hardwareEnabled)
            XCTAssertTrue(layout.networkEnabled)
            XCTAssertEqual(layout.contentHeight, 144)
        }
    }

    func testNoSummaryModulesShowsEmptyStateAtMinimumHeight() {
        for modules: Set<MonitorModule> in [[], [.disk], [.clash], [.disk, .clash]] {
            let layout = NotchSummaryLayout(modules: modules)

            XCTAssertFalse(layout.hardwareEnabled)
            XCTAssertFalse(layout.networkEnabled)
            XCTAssertEqual(layout.contentHeight, 112)
        }
    }
}

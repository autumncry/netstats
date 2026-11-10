import CoreGraphics
import XCTest
@testable import NetStatsCore

final class TopEdgeGeometryTests: XCTestCase {
    func testAutomaticPrefersPhysicalNotchOverExternalMainScreen() throws {
        let result = try XCTUnwrap(TopEdgeGeometry.resolve(mode: .automatic, screens: [external(), notched()], preferredDisplayID: 2))
        XCTAssertEqual(result.mode, .notch)
        XCTAssertEqual(result.displayID, 1)
        XCTAssertEqual(result.anchorFrame, CGRect(x: 640, y: 868, width: 160, height: 32))
    }

    func testAutomaticFallsBackToTopBarWithoutPhysicalNotch() throws {
        let screen = external()
        let result = try XCTUnwrap(TopEdgeGeometry.resolve(mode: .automatic, screens: [screen], preferredDisplayID: 2))
        XCTAssertEqual(result.mode, .topBar)
        XCTAssertEqual(result.displayID, 2)
        XCTAssertEqual(result.anchorFrame.maxY, screen.visibleFrame.maxY)
        XCTAssertEqual(result.anchorFrame.height, 8)
        XCTAssertTrue(screen.visibleFrame.contains(result.anchorFrame))
        XCTAssertEqual(result.cardFrame(height: 248, width: 360).maxY, result.anchorFrame.minY)
    }

    func testExplicitTopBarUsesPreferredDisplayEvenWhenNotchExists() throws {
        let result = try XCTUnwrap(TopEdgeGeometry.resolve(mode: .topBar, screens: [notched(), external()], preferredDisplayID: 2))
        XCTAssertEqual(result.mode, .topBar)
        XCTAssertEqual(result.displayID, 2)
    }

    func testExplicitNotchWithoutHardwareAndNoScreensStayUnavailable() {
        XCTAssertNil(TopEdgeGeometry.resolve(mode: .notch, screens: [external()], preferredDisplayID: 2))
        XCTAssertNil(TopEdgeGeometry.resolve(mode: .automatic, screens: [], preferredDisplayID: nil))
    }

    func testTopBarWithNegativeCoordinatesAndSideDockStaysInUsableArea() throws {
        let screen = external(origin: CGPoint(x: -1920, y: -500))
        let result = try XCTUnwrap(TopEdgeGeometry.resolve(mode: .topBar, screens: [screen], preferredDisplayID: 2))
        XCTAssertTrue(screen.visibleFrame.contains(result.triggerFrame))
        XCTAssertTrue(result.containsTrigger(CGPoint(x: result.anchorFrame.midX, y: result.anchorFrame.maxY)))
        XCTAssertFalse(result.containsTrigger(CGPoint(x: result.anchorFrame.midX, y: result.anchorFrame.maxY + 1)))
        let card = result.cardFrame(height: 5000, width: 5000)
        XCTAssertTrue(screen.visibleFrame.contains(card))
        XCTAssertLessThanOrEqual(card.maxY, result.anchorFrame.minY)
    }

    func testInvalidVisibleFrameIsRejected() {
        var screen = external()
        screen.visibleFrame = CGRect(x: 0, y: 0, width: 0, height: 10)
        XCTAssertNil(TopEdgeGeometry.resolve(mode: .topBar, screens: [screen], preferredDisplayID: 2))
        screen.visibleFrame = CGRect(x: CGFloat.nan, y: 0, width: 500, height: 500)
        XCTAssertNil(TopEdgeGeometry.resolve(mode: .automatic, screens: [screen], preferredDisplayID: 2))
    }

    func testDisconnectingBuiltInDisplayRecomputesFallbackAndReconnectingRestoresNotch() throws {
        XCTAssertEqual(TopEdgeGeometry.resolve(mode: .automatic, screens: [external(), notched()], preferredDisplayID: 2)?.mode, .notch)
        XCTAssertEqual(TopEdgeGeometry.resolve(mode: .automatic, screens: [external()], preferredDisplayID: 2)?.mode, .topBar)
        XCTAssertEqual(TopEdgeGeometry.resolve(mode: .automatic, screens: [external(), notched()], preferredDisplayID: 2)?.mode, .notch)
    }

    private func notched() -> TopEdgeScreen {
        TopEdgeScreen(displayID: 1, name: "Built-in", frame: CGRect(x: 0, y: 0, width: 1440, height: 900),
                      visibleFrame: CGRect(x: 0, y: 40, width: 1440, height: 828), safeAreaTop: 32,
                      auxiliaryLeft: CGRect(x: 0, y: 868, width: 640, height: 32),
                      auxiliaryRight: CGRect(x: 800, y: 868, width: 640, height: 32), isBuiltIn: true)
    }

    private func external(origin: CGPoint = CGPoint(x: 1440, y: 0)) -> TopEdgeScreen {
        TopEdgeScreen(displayID: 2, name: "External", frame: CGRect(origin: origin, size: CGSize(width: 1920, height: 1080)),
                      visibleFrame: CGRect(x: origin.x + 60, y: origin.y, width: 1860, height: 1055), safeAreaTop: 0,
                      auxiliaryLeft: nil, auxiliaryRight: nil, isBuiltIn: false)
    }
}

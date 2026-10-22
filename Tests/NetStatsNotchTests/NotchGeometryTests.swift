import CoreGraphics
import XCTest
@testable import NetStatsCore

final class NotchGeometryTests: XCTestCase {
    func testDetectsPhysicalNotchAndClippedTrigger() throws {
        let geometry = try XCTUnwrap(detect())
        XCTAssertEqual(geometry.notchFrame, CGRect(x: 640, y: 868, width: 160, height: 32))
        XCTAssertEqual(geometry.triggerFrame, CGRect(x: 636, y: 864, width: 168, height: 36))
        XCTAssertEqual(geometry.cardFrame(height: 300), CGRect(x: 510, y: 568, width: 420, height: 300))
    }

    func testTriggerIncludesTopAndMaxEdges() throws {
        let geometry = try XCTUnwrap(detect())
        for point in [CGPoint(x: 636, y: 900), CGPoint(x: 804, y: 900), CGPoint(x: 804, y: 864)] {
            XCTAssertTrue(geometry.containsTrigger(point))
        }
        XCTAssertFalse(geometry.containsTrigger(CGPoint(x: 805, y: 900)))
        XCTAssertFalse(geometry.containsTrigger(CGPoint(x: 720, y: 901)))
        XCTAssertFalse(geometry.containsTrigger(CGPoint(x: CGFloat.nan, y: 900)))
    }

    func testExternalDisplayOrMissingSafeAreaHasNoNotch() {
        XCTAssertNil(detect(isBuiltIn: false))
        XCTAssertNil(detect(safeAreaTop: 0))
        XCTAssertNil(detect(safeAreaTop: -1))
    }

    func testInvalidFramesAndNonfiniteInputsAreRejected() {
        XCTAssertNil(detect(safeAreaTop: .nan))
        XCTAssertNil(detect(safeAreaTop: .infinity))
        XCTAssertNil(detect(screen: CGRect(x: 0, y: 0, width: 0, height: 900)))
        XCTAssertNil(detect(screen: CGRect(x: CGFloat.infinity, y: 0, width: 1440, height: 900)))
        XCTAssertNil(detect(visible: CGRect(x: 0, y: 0, width: 0, height: 868)))
        XCTAssertNil(detect(left: .zero))
        XCTAssertNil(detect(right: .null))
    }

    func testAbsentOverlappingOrOutOfBandAuxiliaryAreasAreRejected() {
        XCTAssertNil(detect(left: CGRect(x: 0, y: 868, width: 720, height: 32), right: CGRect(x: 720, y: 868, width: 720, height: 32)))
        XCTAssertNil(detect(left: CGRect(x: 0, y: 868, width: 900, height: 32)))
        XCTAssertNil(detect(left: CGRect(x: 0, y: 800, width: 640, height: 32)))
        XCTAssertNil(detect(right: CGRect(x: 800, y: 868, width: 700, height: 32)))
        XCTAssertNil(detect(safeAreaTop: 950))
    }

    func testNonzeroAndNegativeScreenOriginsRemainInGlobalCoordinates() throws {
        for origin in [CGPoint(x: 1800, y: 200), CGPoint(x: -1440, y: -300)] {
            let geometry = try XCTUnwrap(detect(
                screen: CGRect(origin: origin, size: CGSize(width: 1440, height: 900)),
                visible: CGRect(x: origin.x, y: origin.y + 40, width: 1440, height: 828),
                left: CGRect(x: origin.x, y: origin.y + 868, width: 640, height: 32),
                right: CGRect(x: origin.x + 800, y: origin.y + 868, width: 640, height: 32)
            ))
            XCTAssertEqual(geometry.notchFrame.origin, CGPoint(x: origin.x + 640, y: origin.y + 868))
            XCTAssertEqual(geometry.cardFrame(height: 300), CGRect(x: origin.x + 510, y: origin.y + 568, width: 420, height: 300))
        }
    }

    func testDifferentPointSizedDisplayDoesNotApplyPixelScaling() throws {
        let geometry = try XCTUnwrap(detect(
            screen: CGRect(x: 0, y: 0, width: 1728, height: 1117),
            visible: CGRect(x: 0, y: 40, width: 1728, height: 1039),
            safeAreaTop: 38,
            left: CGRect(x: 0, y: 1079, width: 764, height: 38),
            right: CGRect(x: 964, y: 1079, width: 764, height: 38)
        ))
        XCTAssertEqual(geometry.notchFrame, CGRect(x: 764, y: 1079, width: 200, height: 38))
        XCTAssertEqual(geometry.cardFrame(height: 300), CGRect(x: 654, y: 779, width: 420, height: 300))
    }

    func testRealMacBookVisibleTopBelowNotchKeepsCardBelowMenuBar() throws {
        let geometry = try XCTUnwrap(detect(
            screen: CGRect(x: 0, y: 0, width: 1800, height: 1169),
            visible: CGRect(x: 0, y: 75, width: 1800, height: 1054),
            safeAreaTop: 38,
            left: CGRect(x: 0, y: 1131, width: 790, height: 38),
            right: CGRect(x: 1010, y: 1131, width: 790, height: 38)
        ))
        XCTAssertEqual(geometry.notchFrame, CGRect(x: 790, y: 1131, width: 220, height: 38))
        XCTAssertEqual(geometry.cardFrame(height: 300), CGRect(x: 690, y: 829, width: 420, height: 300))
        XCTAssertEqual(geometry.cardFrame(height: 2000, width: 2000), CGRect(x: 8, y: 83, width: 1784, height: 1046))
    }

    func testOversizedCardClampsToUsableScreenBounds() throws {
        let geometry = try XCTUnwrap(detect())
        XCTAssertEqual(geometry.cardFrame(height: 2000, width: 2000), CGRect(x: 8, y: 48, width: 1424, height: 820))
    }

    func testSideDockClampsCardOriginWithinVisibleFrame() throws {
        let geometry = try XCTUnwrap(detect(visible: CGRect(x: 600, y: 40, width: 840, height: 828)))
        XCTAssertEqual(geometry.cardFrame(height: 300), CGRect(x: 608, y: 568, width: 420, height: 300))
    }

    func testTriggerExpansionClipsAtScreenSide() throws {
        let geometry = try XCTUnwrap(detect(
            left: CGRect(x: 0, y: 868, width: 2, height: 32),
            right: CGRect(x: 162, y: 868, width: 1278, height: 32)
        ))
        XCTAssertEqual(geometry.triggerFrame, CGRect(x: 0, y: 864, width: 166, height: 36))
        XCTAssertEqual(geometry.cardFrame(height: 300).minX, 8)
    }

    private func detect(
        screen: CGRect = CGRect(x: 0, y: 0, width: 1440, height: 900),
        visible: CGRect = CGRect(x: 0, y: 40, width: 1440, height: 828),
        safeAreaTop: CGFloat = 32,
        left: CGRect = CGRect(x: 0, y: 868, width: 640, height: 32),
        right: CGRect = CGRect(x: 800, y: 868, width: 640, height: 32),
        isBuiltIn: Bool = true
    ) -> NotchGeometry? {
        NotchGeometry.detect(screenFrame: screen, visibleFrame: visible, safeAreaTop: safeAreaTop, auxiliaryLeft: left, auxiliaryRight: right, isBuiltIn: isBuiltIn)
    }
}

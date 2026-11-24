import CoreGraphics
import XCTest
@testable import NetStatsCore

final class StatusItemAnchorTests: XCTestCase {
    private let main = StatusItemAnchor.Screen(frame: CGRect(x: 0, y: 0, width: 1440, height: 900),
                                               visibleFrame: CGRect(x: 0, y: 40, width: 1440, height: 835))

    func testRealButtonFrameWinsOverUnrelatedPointer() {
        let button = CGRect(x: 1200, y: 875, width: 28, height: 25)
        XCTAssertEqual(StatusItemAnchor.resolve(buttonFrame: button, pointer: CGPoint(x: 100, y: 200),
                                                screens: [main], menuBarHeight: 25), button)
    }

    func testPlaceholderAndWholeMenuBarFramesUseValidatedClickLocation() throws {
        for invalid in [CGRect(x: 0, y: 0, width: 28, height: 25), CGRect(x: 0, y: 875, width: 1440, height: 25)] {
            let result = try XCTUnwrap(StatusItemAnchor.resolve(buttonFrame: invalid, pointer: CGPoint(x: 1220, y: 890),
                                                               screens: [main], menuBarHeight: 25))
            XCTAssertEqual(result.midX, 1220)
            XCTAssertEqual(result.minY, 875)
            XCTAssertLessThan(result.width, 100)
        }
    }

    func testKeyboardFallbackStaysInMenuBarAndNeverUsesDesktopPointer() throws {
        let result = try XCTUnwrap(StatusItemAnchor.resolve(buttonFrame: nil, pointer: CGPoint(x: 400, y: 200),
                                                           screens: [main], menuBarHeight: 25))
        XCTAssertEqual(result.minY, 875)
        XCTAssertTrue(main.frame.contains(result))
        XCTAssertGreaterThan(result.minX, 1300)
    }

    func testNegativeCoordinateScreenUsesItsOwnMenuBar() throws {
        let other = StatusItemAnchor.Screen(frame: CGRect(x: -1920, y: -300, width: 1920, height: 1080),
                                            visibleFrame: CGRect(x: -1920, y: -300, width: 1920, height: 1055))
        let result = try XCTUnwrap(StatusItemAnchor.resolve(buttonFrame: nil, pointer: CGPoint(x: -1500, y: 770),
                                                           screens: [main, other], menuBarHeight: 25))
        XCTAssertEqual(result.midX, -1500)
        XCTAssertEqual(result.minY, 755)
        XCTAssertNil(StatusItemAnchor.resolve(buttonFrame: nil, pointer: .zero, screens: [], menuBarHeight: 25))
    }

    func testMirroredItemOnOtherScreenDoesNotOverridePointerInNotchedMenuBand() throws {
        let other = StatusItemAnchor.Screen(frame: CGRect(x: -1440, y: 0, width: 1440, height: 900),
                                            visibleFrame: CGRect(x: -1440, y: 40, width: 1440, height: 822))
        let result = try XCTUnwrap(StatusItemAnchor.resolve(buttonFrame: CGRect(x: 1200, y: 875, width: 28, height: 25),
                                                           pointer: CGPoint(x: -100, y: 865), screens: [main, other],
                                                           menuBarHeight: 25))
        XCTAssertEqual(result.midX, -100)
        XCTAssertEqual(result.minY, 862)
    }

    func testAutoHiddenMenuAndInvalidInputs() throws {
        let hidden = StatusItemAnchor.Screen(frame: main.frame, visibleFrame: main.frame)
        let result = try XCTUnwrap(StatusItemAnchor.resolve(buttonFrame: .null, pointer: CGPoint(x: 0, y: 900),
                                                           screens: [hidden], menuBarHeight: 25))
        XCTAssertEqual(result.minY, 875)
        XCTAssertTrue(main.frame.contains(result))
        XCTAssertNil(StatusItemAnchor.resolve(buttonFrame: nil, pointer: .zero, screens: [main], menuBarHeight: .nan))
        XCTAssertNil(StatusItemAnchor.resolve(buttonFrame: nil, pointer: .zero,
                                               screens: [.init(frame: .zero, visibleFrame: .zero)], menuBarHeight: 25))
    }
}

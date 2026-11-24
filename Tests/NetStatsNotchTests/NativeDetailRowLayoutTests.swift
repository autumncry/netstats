import AppKit
import SwiftUI
import XCTest
@testable import NetStatsCore

final class NativeDetailRowLayoutTests: XCTestCase {
    @MainActor
    func testDifferentSymbolsLeaveTheTitleInTheSameColumn() throws {
        // Use the same title so differences in its rendered position can
        // only come from the icon. The value is at the far right of each row.
        var titleEnds: [Int] = []
        for symbol in ["chart.pie", "externaldrive", "archivebox", "arrow.left.arrow.right", "bolt"] {
            let row = CompactValueRow(title: "MMMMM", systemImage: symbol, value: "1 GB")
                .frame(width: 320, height: 24)
                .foregroundStyle(.black).background(.white)
                .environment(\.colorScheme, .light)
            let renderer = ImageRenderer(content: row)
            renderer.scale = 2
            let image = NSBitmapImageRep(cgImage: try XCTUnwrap(renderer.cgImage))
            let lastInk = (48..<220).last { x in
                (0..<image.pixelsHigh).contains { y in
                    guard let color = image.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB) else { return false }
                    return color.redComponent < 0.5
                }
            }
            titleEnds.append(try XCTUnwrap(lastInk))
        }
        XCTAssertLessThanOrEqual(try XCTUnwrap(titleEnds.max()) - XCTUnwrap(titleEnds.min()), 1,
                                 "Title should stay aligned within one rendered pixel: \(titleEnds)")
    }
}

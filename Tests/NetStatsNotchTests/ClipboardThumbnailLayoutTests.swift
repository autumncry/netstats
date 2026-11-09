import AppKit
import SwiftUI
import XCTest
@testable import NetStatsCore

final class ClipboardThumbnailLayoutTests: XCTestCase {
    @MainActor
    func testWideTallAndSquareImagesNeverDrawIntoTitleOrTimestamp() throws {
        for size in [CGSize(width: 240, height: 30), CGSize(width: 30, height: 240), CGSize(width: 60, height: 60)] {
            let context = try XCTUnwrap(CGContext(data: nil, width: Int(size.width), height: Int(size.height),
                                                 bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
                                                 bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
            context.setFillColor(CGColor(red: 0, green: 1, blue: 0, alpha: 1))
            context.fill(CGRect(origin: .zero, size: size))
            let image = NSImage(cgImage: try XCTUnwrap(context.makeImage()), size: size)
            let view = HStack(spacing: 8) {
                ClipboardThumbnailContent(image: image)
                VStack(alignment: .leading, spacing: 2) {
                    Text("图片").font(.system(size: 11, weight: .medium))
                    Text("18:05").font(.system(size: 9))
                }
                Spacer(minLength: 0)
            }
            .padding(20).frame(width: 180, height: 70, alignment: .topLeading)
            .background(Color.white).environment(\.colorScheme, .light)
            let renderer = ImageRenderer(content: view)
            renderer.scale = 1
            let bitmap = NSBitmapImageRep(cgImage: try XCTUnwrap(renderer.cgImage))
            var outside = 0
            var inside = 0
            for y in 0..<bitmap.pixelsHigh {
                for x in 0..<bitmap.pixelsWide {
                    let color = try XCTUnwrap(bitmap.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB))
                    if color.greenComponent > 0.7 && color.redComponent < 0.3 && color.blueComponent < 0.3 {
                        if (20..<50).contains(x) && (20..<50).contains(y) { inside += 1 }
                        else { outside += 1 }
                    }
                }
            }
            XCTAssertGreaterThan(inside, 0, "The image should remain visible: \(size)")
            XCTAssertEqual(outside, 0, "Thumbnail pixels escaped the 30pt cell: \(size)")
            if let path = ProcessInfo.processInfo.environment["NETSTATS_THUMBNAIL_RENDER_OUTPUT"] {
                let folder = URL(fileURLWithPath: path)
                try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
                try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
                    .write(to: folder.appendingPathComponent("\(Int(size.width))x\(Int(size.height)).png"))
            }
        }
    }
}

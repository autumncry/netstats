import AppKit
import SwiftUI
import XCTest
@testable import NetStatsCore

final class NotchRenderingTests: XCTestCase {
    func testBothLanguagesRenderAllSummaryLayoutsAtTheirDeclaredSize() async throws {
        try await MainActor.run {
            let suite = "netstats-notch-render-\(UUID().uuidString)"
            let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
            defer { defaults.removePersistentDomain(forName: suite) }
            let settings = DisplaySettings(defaults: defaults)
            let metrics = MetricsStore()
            if ProcessInfo.processInfo.environment["NETSTATS_RENDER_OUTPUT"] != nil {
                metrics.start()
            }
            defer { metrics.stop() }
            let groups: [Set<MonitorModule>] = [
                [.hardware, .network], [.hardware], [.network], []
            ]

            for language in AppLanguage.allCases {
                settings.language = language
                for (index, modules) in groups.enumerated() {
                    settings.monitorModules = modules
                    let layout = NotchSummaryLayout(modules: modules)
                    let content = NotchSummaryView(
                        metricsStore: metrics,
                        displaySettings: settings,
                        openDetails: {}, openSettings: {}
                    )
                    .frame(width: 420, height: layout.contentHeight)
                    .preferredColorScheme(.dark)
                    let renderer = ImageRenderer(content: content)
                    renderer.scale = 2
                    let image = try XCTUnwrap(renderer.cgImage, "Summary should render without a visible window")
                    XCTAssertEqual(image.width, 840)
                    XCTAssertEqual(image.height, Int(layout.contentHeight * 2))
                    let representation = NSBitmapImageRep(cgImage: image)
                    XCTAssertLessThan(try XCTUnwrap(representation.colorAt(x: 0, y: 0)).alphaComponent, 0.01)
                    XCTAssertGreaterThan(try XCTUnwrap(representation.colorAt(x: 420, y: 80)).alphaComponent, 0.99)

                    // Optional render output supports visual QA; values are the
                    // test store's current sample, not a live app screenshot.
                    if let destination = ProcessInfo.processInfo.environment["NETSTATS_RENDER_OUTPUT"] {
                        let folder = URL(fileURLWithPath: destination, isDirectory: true)
                        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
                        let png = try XCTUnwrap(representation.representation(using: .png, properties: [:]))
                        try png.write(to: folder.appendingPathComponent("\(language.rawValue)-\(index).png"))
                    }
                }
            }
        }
    }
}

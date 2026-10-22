import AppKit
import SwiftUI
import XCTest
@testable import NetStatsCore

final class HubRenderingTests: XCTestCase {
    func testSixFeaturesAndSettingsRenderAtDeclaredSizesInBothAppearances() async throws {
        try await MainActor.run {
            let suite = "netstats-hub-render-\(UUID())"
            let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
            let folder = FileManager.default.temporaryDirectory.appendingPathComponent(suite, isDirectory: true)
            defer {
                defaults.removePersistentDomain(forName: suite)
                try? FileManager.default.removeItem(at: folder)
            }
            let settings = HubSettings(defaults: defaults)
            settings.enabledFeatures = Set(HubFeature.allCases)
            let display = DisplaySettings(defaults: defaults)
            let store = HubStore(metricsStore: MetricsStore(), displaySettings: display,
                                 settings: settings, defaults: defaults, storageDirectory: folder)
            for language in AppLanguage.allCases {
                display.language = language
                for dark in [false, true] {
                    for feature in HubFeature.allCases {
                        store.select(feature: feature)
                        let view = HubCardView(store: store, displaySettings: display, requestKeyboard: {},
                                               holdInteraction: { _ in }, openDetails: {}, openSettings: {})
                            .preferredColorScheme(dark ? .dark : .light)
                        try Self.render(view, width: 360, height: feature.cardHeight,
                                   name: "\(language.rawValue)-\(dark ? "dark" : "light")-\(feature.rawValue)")
                        if feature == .calendar {
                            store.calendar.mode = .month
                            store.calendar.selectedDate = Calendar.current.date(from: DateComponents(year: 2026, month: 8, day: 15))!
                            try Self.render(view, width: 360, height: feature.cardHeight,
                                            name: "\(language.rawValue)-\(dark ? "dark" : "light")-calendar-month")
                            store.calendar.mode = .week
                        }
                    }
                    let settingsView = HubSettingsView(store: store, displaySettings: display, requestKeyboard: {},
                                                       holdInteraction: { _ in }, openDetails: {}, openLegacySettings: {})
                        .preferredColorScheme(dark ? .dark : .light)
                    try Self.render(settingsView, width: 360, height: 520,
                               name: "\(language.rawValue)-\(dark ? "dark" : "light")-settings")
                }
            }
            store.stop()
        }
    }

    @MainActor private static func render<V: View>(_ view: V, width: CGFloat, height: CGFloat, name: String) throws {
        let renderer = ImageRenderer(content: view.frame(width: width, height: height))
        renderer.scale = 2
        let rendered = try XCTUnwrap(renderer.cgImage)
        XCTAssertEqual(rendered.width, Int(width * 2))
        XCTAssertEqual(rendered.height, Int(height * 2))
        if let path = ProcessInfo.processInfo.environment["NETSTATS_HUB_RENDER_OUTPUT"] {
            let folder = URL(fileURLWithPath: path, isDirectory: true)
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let bitmap = NSBitmapImageRep(cgImage: rendered)
            let png = try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
            try png.write(to: folder.appendingPathComponent(name + ".png"))
            // Native controls (ScrollView/segmented Picker) are omitted by
            // ImageRenderer. Also capture our own AppKit view for layout QA.
            _ = NSApplication.shared
            let hosting = NSHostingView(rootView: view)
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: width, height: height),
                                  styleMask: .borderless, backing: .buffered, defer: false)
            window.contentView = hosting
            hosting.frame = NSRect(x: 0, y: 0, width: width, height: height)
            hosting.layoutSubtreeIfNeeded()
            if let representation = hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds) {
                hosting.cacheDisplay(in: hosting.bounds, to: representation)
                if let data = representation.representation(using: .png, properties: [:]) {
                    try data.write(to: folder.appendingPathComponent("native-" + name + ".png"))
                }
            }
            window.contentView = nil
        }
    }
}

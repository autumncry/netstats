import AppKit
import SwiftUI
import XCTest
@testable import NetStatsCore

final class HubRenderingTests: XCTestCase {
    @MainActor
    func testDeviceMetricsFitAboveNavigationWithBottomBreathingRoom() {
        // Measure the actual text layout, not just the output image dimensions.
        // Header is 25 + 12 + 7 pt; navigation is 40 + 6 + 6 pt.
        let viewportHeight = HubFeature.device.cardHeight - 44 - 52
        for language in AppLanguage.allCases {
            for load: Double? in [nil, 0.3] {
                for name in ["MacBook Pro", String(repeating: "Long device name ", count: 8)] {
                    let content = HubDeviceContent(snapshot: .empty,
                                                   gpu: GPUReading(name: "Apple GPU", utilization: load),
                                                   deviceName: name, language: language)
                        .frame(width: 328).fixedSize(horizontal: false, vertical: true)
                    let hosting = NSHostingView(rootView: content)
                    let naturalHeight = hosting.fittingSize.height
                    XCTAssertGreaterThan(naturalHeight, 0)
                    XCTAssertLessThanOrEqual(naturalHeight + 8, viewportHeight + 0.01,
                                             "Device rows and I/O need room above the navigation: \(language), \(String(describing: load)), content=\(naturalHeight), available=\(viewportHeight)")
                }
            }
        }
    }

    @MainActor
    func testDeviceCardReflectsUnavailableZeroAndUsedSwapSamples() throws {
        let samples: [SwapUsage?] = [nil, SwapUsage(usedBytes: 0, totalBytes: 0),
                                     SwapUsage(usedBytes: 2 << 30, totalBytes: 4 << 30)]
        for language in AppLanguage.allCases {
            var inkCounts: [Int] = []
            for (index, swap) in samples.enumerated() {
                let memory = MemorySnapshot(usedBytes: 17 << 30, totalBytes: 24 << 30, availableBytes: 7 << 30,
                                            cachedBytes: 0, wiredBytes: 0, compressedBytes: 0, pressure: 0.5, swap: swap)
                let disk = DiskSnapshot(usedBytes: 300 << 30, totalBytes: 500 << 30, freeBytes: 200 << 30,
                                        readBytesPerSecond: 1_048_576, writeBytesPerSecond: 2_097_152)
                let snapshot = SystemSnapshot(timestamp: .distantPast, cpuUsage: 0.22, memory: memory, disk: disk,
                                              network: SystemSnapshot.empty.network, power: .noBattery)
                let content = HubDeviceContent(snapshot: snapshot, gpu: GPUReading(name: "Apple GPU", utilization: 0.3),
                                               deviceName: "MacBook Pro", language: language)
                    .frame(width: 328, height: HubFeature.device.cardHeight - 96, alignment: .top)
                    .background(.white).environment(\.colorScheme, .light)
                let rendered = try Self.render(content, width: 328, height: HubFeature.device.cardHeight - 96,
                                               name: "device-swap-\(language.rawValue)-\(index)")
                // Only the right side of the memory row should change. Count
                // visible ink instead of comparing PNG metadata or exact glyphs.
                let region = CGRect(x: rendered.width / 2, y: rendered.height / 3,
                                    width: rendered.width / 2, height: rendered.height / 3)
                let bitmap = NSBitmapImageRep(cgImage: try XCTUnwrap(rendered.cropping(to: region)))
                var ink = 0
                for y in 0..<bitmap.pixelsHigh {
                    for x in 0..<bitmap.pixelsWide {
                        if let color = bitmap.colorAt(x: x, y: y), color.redComponent < 0.5 { ink += 1 }
                    }
                }
                inkCounts.append(ink)
            }
            XCTAssertLessThan(inkCounts[0], inkCounts[1], "An allocated-size pair should replace the dash")
            XCTAssertLessThan(inkCounts[1], inkCounts[2], "The nonzero GB pair should be visible in full")
        }
    }

    func testNetworkHandlesUploadDominantAndUnavailableSamples() async throws {
        try await MainActor.run {
            for language in AppLanguage.allCases {
                for (index, rates) in [(474.0 * 1024, 13.0 * 1024 * 1024), (Double.nan, Double.infinity)].enumerated() {
                    let network = NetworkSnapshot(downloadBytesPerSecond: rates.0, uploadBytesPerSecond: rates.1,
                                                  sessionDownloadedBytes: 607 * 1024 * 1024 * 1024,
                                                  sessionUploadedBytes: 113 * 1024 * 1024 * 1024,
                                                  activeInterfaces: ["anpi0", "awdl0"], ipv4Addresses: [])
                    let view = HubNetworkContent(network: network, history: MetricHistory(), language: language)
                        .padding(16).frame(width: 360, height: 120)
                        .background(Color(nsColor: .windowBackgroundColor))
                    try Self.render(view, width: 360, height: 120, name: "network-sample-\(language.rawValue)-\(index)")
                }
            }
        }
    }

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
            let base = SystemSnapshot.empty
            let example = SystemSnapshot(timestamp: base.timestamp, cpuUsage: 0.18, memory: base.memory,
                                         disk: base.disk,
                                         network: NetworkSnapshot(downloadBytesPerSecond: 474 * 1024, uploadBytesPerSecond: 13 * 1024 * 1024,
                                                                  sessionDownloadedBytes: 607 * 1024 * 1024 * 1024,
                                                                  sessionUploadedBytes: 113 * 1024 * 1024 * 1024,
                                                                  activeInterfaces: ["anpi0", "awdl0"], ipv4Addresses: []), power: base.power)
            var history = MetricHistory()
            for _ in 0..<8 { history.append(example) }
            let store = HubStore(metricsStore: MetricsStore(snapshot: example, history: history), displaySettings: display,
                                 settings: settings, defaults: defaults, storageDirectory: folder)
            for language in AppLanguage.allCases {
                display.language = language
                for dark in [false, true] {
                    for feature in HubFeature.allCases {
                        store.select(feature: feature)
                        let view = HubCardView(store: store, displaySettings: display, requestKeyboard: {},
                                               holdInteraction: { _ in }, openDetails: {}, openSettings: {})
                            .preferredColorScheme(dark ? .dark : .light)
                            .environment(\.colorScheme, dark ? .dark : .light)
                        try Self.render(view, width: 360, height: feature.cardHeight,
                                   name: "\(language.rawValue)-\(dark ? "dark" : "light")-\(feature.rawValue)")
                        if feature == .network {
                            let pinned = HubCardView(store: store, displaySettings: display, requestKeyboard: {},
                                                     holdInteraction: { _ in }, openDetails: {}, openSettings: {},
                                                     pin: TopEdgeCardPin(isPinned: true, toggle: {}))
                                .environment(\.colorScheme, dark ? .dark : .light)
                            try Self.render(pinned, width: 360, height: feature.cardHeight,
                                            name: "\(language.rawValue)-\(dark ? "dark" : "light")-pinned-network")
                        }
                        if feature == .calendar {
                            store.calendar.mode = .month
                            store.calendar.selectedDate = Calendar.current.date(from: DateComponents(year: 2026, month: 8, day: 15))!
                            try Self.render(view, width: 360, height: feature.cardHeight,
                                            name: "\(language.rawValue)-\(dark ? "dark" : "light")-calendar-month")
                            store.calendar.mode = .week
                        }
                    }
                    let settingsView = HubSettingsView(store: store, displaySettings: display, metricsStore: store.metricsStore)
                        .preferredColorScheme(dark ? .dark : .light)
                    try Self.render(settingsView, width: 780, height: 620,
                               name: "\(language.rawValue)-\(dark ? "dark" : "light")-settings")
                }
            }
            store.stop()
        }
    }

    @discardableResult
    @MainActor private static func render<V: View>(_ view: V, width: CGFloat, height: CGFloat, name: String) throws -> CGImage {
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
        return rendered
    }
}

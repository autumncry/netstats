import AppKit
import SwiftUI
import Vision
import XCTest
@testable import NetStatsCore

final class TerminalMonitorRenderingTests: XCTestCase {
    @MainActor
    func testTerminalTextAndStatusColorsRemainReadableOnItsDarkSurface() throws {
        func luminance(_ color: Color) throws -> Double {
            let rgb = try XCTUnwrap(NSColor(color).usingColorSpace(.sRGB))
            func linear(_ component: CGFloat) -> Double {
                let value = Double(component)
                return value <= 0.04045 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
            }
            return 0.2126 * linear(rgb.redComponent) + 0.7152 * linear(rgb.greenComponent) + 0.0722 * linear(rgb.blueComponent)
        }
        let background = try luminance(TerminalTheme.background)
        for color in [TerminalTheme.foreground, TerminalTheme.secondary, TerminalTheme.accent, TerminalTheme.positive, TerminalTheme.warning, TerminalTheme.error] {
            let foreground = try luminance(color)
            XCTAssertGreaterThanOrEqual((max(foreground, background) + 0.05) / (min(foreground, background) + 0.05), 4.5)
        }
    }

    @MainActor
    func testTerminalDetailsRenderAtShippedSizeInBothLanguagesAndAppearances() throws {
        let suite = "netstats-terminal-render-\(UUID())"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let display = DisplaySettings(defaults: defaults)
        display.panelStyle = .terminal
        display.publicIPLookupEnabled = false
        let metrics = MetricsStore(snapshot: Self.snapshot(), history: Self.history())
        for language in AppLanguage.allCases {
            display.language = language
            for dark in [false, true] {
                let view = MonitorPopoverView(metricsStore: metrics, displaySettings: display,
                                              ipGeolocationStore: IPGeolocationStore(), clashStatusStore: ClashStatusStore(),
                                              openSettings: {})
                    .environment(\.colorScheme, dark ? .dark : .light)
                    .frame(width: 760, height: 700)
                try Self.render(view, name: "\(language.rawValue)-\(dark ? "dark" : "light")")
            }
        }
    }

    @MainActor
    func testModuleAndProcessSwitchesControlVisibleContent() throws {
        for (modules, ranks, cpuVisible, processVisible) in [
            (Set([MonitorModule.hardware]), true, true, true),
            (Set([MonitorModule.hardware]), false, true, false),
            (Set<MonitorModule>(), true, false, false)
        ] {
            let bitmap = try Self.render(Self.demo(modules: modules, ranks: ranks), name: "switches-\(modules.count)-\(ranks)")
            let text = try Self.recognizedText(bitmap)
            XCTAssertEqual(text.contains("cpu"), cpuVisible)
            XCTAssertEqual(text.contains("compileworker"), processVisible)
            if processVisible { XCTAssertTrue(text.contains("124.6%"), "Per-process CPU may exceed 100%") }
        }
    }

    @MainActor
    func testDisabledIPLookupNeverRendersCachedPublicAddressOrLocation() throws {
        for lookup in [true, false] {
            let bitmap = try Self.render(Self.demo(modules: [.network], lookup: lookup), name: "network-lookup-\(lookup)")
            let text = try Self.recognizedText(bitmap)
            XCTAssertEqual(text.contains("203.0.113.42"), lookup)
            XCTAssertEqual(text.contains("examplecity"), lookup)
        }
    }

    @MainActor
    func testSyntheticPopulatedAndErrorStatesRenderInBothLanguages() throws {
        for language in AppLanguage.allCases {
            try Self.render(Self.demo(language: language), name: "demo-\(language.rawValue)")
            try Self.render(Self.demo(language: language, loading: true, hasLocation: false), name: "loading-\(language.rawValue)")
            try Self.render(Self.demo(language: language, hasLocation: false, error: "Connection unavailable · retry at next refresh"),
                            name: "error-\(language.rawValue)")
        }
        XCTAssertEqual(TerminalFormatting.percent(.nan), "—")
        XCTAssertEqual(TerminalFormatting.speed(.infinity), "—")
        XCTAssertEqual(TerminalFormatting.speed(-1), "—")
    }

    @MainActor private static func demo(language: AppLanguage = .english,
                                        modules: Set<MonitorModule> = Set(MonitorModule.allCases),
                                        ranks: Bool = true, lookup: Bool = true,
                                        loading: Bool = false, hasLocation: Bool = true, error: String? = nil) -> some View {
        let gb: UInt64 = 1_073_741_824
        let processes = ProcessSnapshot(
            cpu: ProcessCategorySnapshot(items: [ProcessMetricSample(pid: 101, name: "CompileWorker", value: 124.6, auxiliaryBytes: nil),
                                                ProcessMetricSample(pid: 102, name: "WindowServer", value: 12.8, auxiliaryBytes: nil),
                                                ProcessMetricSample(pid: 103, name: "Terminal", value: 2.4, auxiliaryBytes: nil)], note: nil),
            gpu: .empty,
            memory: ProcessCategorySnapshot(items: [ProcessMetricSample(pid: 104, name: "Editor", value: 8.3, auxiliaryBytes: 2 * gb),
                                                   ProcessMetricSample(pid: 105, name: "Browser", value: 12.5, auxiliaryBytes: 3 * gb),
                                                   ProcessMetricSample(pid: 106, name: "Preview", value: 4.2, auxiliaryBytes: gb)], note: nil),
            disk: .empty, network: .empty, updatedAt: snapshot().timestamp)
        var clash = ClashStatus.empty
        clash.isRunning = true
        clash.controllerAvailable = true
        clash.systemProxyEnabled = true
        clash.mode = "rule"
        clash.selectedNode = "Example Node"
        return TerminalMonitorView(snapshot: snapshot(), history: history(), processes: processes,
                                   gpuName: "Apple M5", hostName: "macbook-pro.local", language: language,
                                   modules: modules, showHistory: true, showProcessRanks: ranks,
                                   publicLocation: hasLocation ? PublicIPLocation(ipAddress: "203.0.113.42", city: "ExampleCity", region: nil, country: nil, coordinates: nil) : nil,
                                   isLoadingLocation: loading, locationError: error, clashStatus: clash,
                                   lookupEnabled: lookup, copiedIPAddress: false, settingsAction: {}, copyIPAddressAction: {})
            .padding(18).frame(width: 760, height: 700).background(TerminalTheme.background)
    }

    private static func recognizedText(_ bitmap: NSBitmapImageRep) throws -> String {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .fast
        request.recognitionLanguages = ["en-US"]
        request.usesLanguageCorrection = false
        // Read rendered ASCII values without depending on a GPU/ANE OCR model.
        for (stage, devices) in try request.supportedComputeStageDevices {
            if let cpu = devices.first(where: { if case .cpu = $0 { return true }; return false }) {
                request.setComputeDevice(cpu, for: stage)
            }
        }
        try VNImageRequestHandler(cgImage: XCTUnwrap(bitmap.cgImage), options: [:]).perform([request])
        return (request.results ?? []).compactMap { $0.topCandidates(1).first?.string }.joined(separator: "\n")
            .lowercased().replacingOccurrences(of: " ", with: "")
    }

    @discardableResult
    @MainActor static func render<V: View>(_ view: V, name: String) throws -> NSBitmapImageRep {
        _ = NSApplication.shared
        let hosting = NSHostingView(rootView: view)
        let window = NSWindow(contentRect: CGRect(x: -10000, y: -10000, width: 760, height: 700),
                              styleMask: .borderless, backing: .buffered, defer: false)
        window.contentView = hosting
        defer { window.contentView = nil }
        hosting.frame = CGRect(x: 0, y: 0, width: 760, height: 700)
        hosting.layoutSubtreeIfNeeded()
        let bitmap = try XCTUnwrap(hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds))
        hosting.cacheDisplay(in: hosting.bounds, to: bitmap)
        XCTAssertGreaterThanOrEqual(bitmap.pixelsWide, 760)
        XCTAssertGreaterThanOrEqual(bitmap.pixelsHigh, 700)
        XCTAssertEqual(Double(bitmap.pixelsHigh) / Double(bitmap.pixelsWide), 700.0 / 760.0, accuracy: 0.001)
        if let path = ProcessInfo.processInfo.environment["NETSTATS_TERMINAL_RENDER_OUTPUT"] {
            let folder = URL(fileURLWithPath: path, isDirectory: true)
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
                .write(to: folder.appendingPathComponent(name + ".png"))
        }
        return bitmap
    }

    static func snapshot(cpu: Double = 0.32, download: Double = 12_400_000) -> SystemSnapshot {
        let gb: UInt64 = 1_073_741_824
        return SystemSnapshot(timestamp: Date(timeIntervalSince1970: 1_794_304_800), cpuUsage: cpu,
                              memory: MemorySnapshot(usedBytes: 17 * gb, totalBytes: 24 * gb, availableBytes: 7 * gb,
                                                     cachedBytes: 3 * gb, wiredBytes: 4 * gb, compressedBytes: gb, pressure: 0.43),
                              disk: DiskSnapshot(usedBytes: 347 * gb, totalBytes: 512 * gb, freeBytes: 165 * gb,
                                                 readBytesPerSecond: 2_100_000, writeBytesPerSecond: 614_000),
                              network: NetworkSnapshot(downloadBytesPerSecond: download, uploadBytesPerSecond: 819_000,
                                                       sessionDownloadedBytes: 24 * gb, sessionUploadedBytes: 3 * gb,
                                                       activeInterfaces: ["en0", "utun4"], ipv4Addresses: []),
                              power: PowerSnapshot(source: .acPower, batteryPercent: 0.86, isCharging: false))
    }

    static func history() -> MetricHistory {
        var history = MetricHistory()
        for value in [0.1, 0.14, 0.12, 0.24, 0.2, 0.26, 0.38, 0.22, 0.2, 0.3, 0.28, 0.32] {
            history.append(snapshot(cpu: value, download: value * 40_000_000))
        }
        return history
    }
}

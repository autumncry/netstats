import Foundation
import Darwin
import XCTest
@testable import NetStatsCore

final class HubWeatherTests: XCTestCase {
    func testParsesBeginnerTextWithExplicitUnitsAndReceiptTime() throws {
        let receivedAt = Date(timeIntervalSince1970: 1_800_000_000)
        for value in ["16°C", "16 ° C", "16℃"] {
            let weather = try WeatherSnapshot.parse(Data("NETSTATS_WEATHER_V1\n北京市\n\(value)\n晴".utf8), receivedAt: receivedAt)
            XCTAssertEqual(weather.location, "北京市")
            XCTAssertEqual(weather.temperatureC, 16)
            XCTAssertEqual(weather.condition, "晴")
            XCTAssertEqual(weather.updatedAt, receivedAt)
        }
        let fahrenheit = try WeatherSnapshot.parse(Data("\u{feff}NETSTATS_WEATHER_V1\r\n北京市\r\n61 °F\r\nMostly sunny\r\n".utf8), receivedAt: receivedAt)
        XCTAssertEqual(fahrenheit.temperatureC, 16.111111, accuracy: 0.00001)
        let negative = try WeatherSnapshot.parse(Data("NETSTATS_WEATHER_V1\n北京市\n−4℉\nSnow".utf8))
        XCTAssertEqual(negative.temperatureC, -20, accuracy: 0.00001)
    }

    func testBeginnerTextRejectsAmbiguousUnitsAndIncompleteOutput() {
        let invalid = ["NETSTATS_WEATHER_V1\n北京市\n16\n晴",
                       "NETSTATS_WEATHER_V1\n北京市\n290 K\n晴",
                       "NETSTATS_WEATHER_V1\n北京市\nNaN°C\n晴",
                       "NETSTATS_WEATHER_V1\n北京市\n81°C\n晴",
                       "NETSTATS_WEATHER_V1\n北京市\n177°F\n晴",
                       "NETSTATS_WEATHER_V1\n\n16°C\n晴",
                       "NETSTATS_WEATHER_V1\n北京市\n16°C\n",
                       "NETSTATS_WEATHER_V1\n北京市\n16°C\n晴\nExtra",
                       "天气\n北京市\n16°C\n晴"]
        for text in invalid { XCTAssertThrowsError(try WeatherSnapshot.parse(Data(text.utf8)), text) }
    }

    func testBeginnerTextRejectsUnreplacedSetupPlaceholders() throws {
        for city in ["【城市】", "【城市变量】", "[City]", "[City variable]"] {
            XCTAssertThrowsError(try WeatherSnapshot.parse(Data("NETSTATS_WEATHER_V1\n\(city)\n9°C\n晴".utf8)), city)
        }
        for condition in ["【天气状况变量】", "【天气状况】", "[Conditions variable]", "[Conditions]"] {
            XCTAssertThrowsError(try WeatherSnapshot.parse(Data("NETSTATS_WEATHER_V1\n北京市\n9°C\n\(condition)".utf8)), condition)
        }
        let valid = try WeatherSnapshot.parse(Data("NETSTATS_WEATHER_V1\n北京市\n9°C\n晴".utf8))
        XCTAssertEqual(valid.condition, "晴")
        XCTAssertEqual(valid.location, "北京市")
    }

    func testShortcutCatalogRequiresTheExactName() throws {
        let output = Data("Weather\nNetStats Weather copy\nNetStats Weather\n".utf8)
        XCTAssertTrue(try WeatherShortcutCatalog.contains("NetStats Weather", in: output))
        XCTAssertFalse(try WeatherShortcutCatalog.contains("NetStats", in: output))
        XCTAssertFalse(try WeatherShortcutCatalog.contains("netstats weather", in: output))
        XCTAssertThrowsError(try WeatherShortcutCatalog.contains("NetStats Weather", in: Data(repeating: 97, count: 65_537)))
    }

    @MainActor
    func testPreflightOutputCaptureIsCompleteAndBounded() async throws {
        let runner = WeatherCommandRunner()
        let names = "Weather\nNetStats Weather\n"
        _ = try await runner.run(executableURL: URL(fileURLWithPath: "/usr/bin/printf"),
                                 arguments: ["%s", names], captureOutput: true)
        XCTAssertEqual(runner.capturedOutput, Data(names.utf8))
        do {
            _ = try await runner.run(executableURL: URL(fileURLWithPath: "/usr/bin/printf"),
                                     arguments: ["%s", String(repeating: "a", count: 80_000)], captureOutput: true)
            XCTFail("Oversized catalogs must not silently produce a false missing-shortcut result")
        } catch {
            XCTAssertEqual(error as? WeatherBridgeError, .shortcutLookupFailed)
        }
        XCTAssertEqual(runner.capturedOutput.count, 64 * 1024)
    }

    @MainActor
    func testExplicitTestReportsMissingShortcutBeforeRunningBridge() async throws {
        let suite = "NetStatsWeatherTest-\(UUID())"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        var checks = 0
        let store = WeatherStore(defaults: defaults,
                                 cacheURL: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString),
                                 bridgeExecutableURL: URL(fileURLWithPath: "/usr/bin/true"),
                                 bridgeArguments: { _, _ in [] },
                                 shortcutPreflight: { name in checks += 1; XCTAssertEqual(name, "NetStats Weather"); return false })
        store.setEnabled(true)
        await store.refresh(force: true)
        XCTAssertEqual(checks, 0)
        await store.testConnection()
        XCTAssertEqual(checks, 1)
        XCTAssertEqual(store.error, .missingShortcut)
        XCTAssertFalse(store.isConfigured)
        XCTAssertNil(store.snapshot)
    }

    @MainActor
    func testSuccessfulProcessWithoutOutputHasSpecificError() async throws {
        let suite = "NetStatsWeatherTest-\(UUID())"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        for executable in ["/usr/bin/true", "/usr/bin/touch"] {
            let store = WeatherStore(defaults: defaults,
                                     cacheURL: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString),
                                     bridgeExecutableURL: URL(fileURLWithPath: executable),
                                     bridgeArguments: { _, output in executable.hasSuffix("touch") ? [output.path] : [] })
            await store.testConnection()
            XCTAssertEqual(store.error, .noOutput)
            XCTAssertFalse(store.isConfigured)
        }
    }

    func testParsesExplicitCelsiusAndISODate() throws {
        let weather = try WeatherSnapshot.parse(Data(#"{"location":"北京","temperatureC":23.5,"condition":"晴","updatedAt":"2026-10-22T08:30:00Z"}"#.utf8))
        XCTAssertEqual(weather.location, "北京")
        XCTAssertEqual(weather.temperatureC, 23.5)
        XCTAssertEqual(weather.condition, "晴")
        XCTAssertEqual(weather.updatedAt.timeIntervalSince1970, 1_792_657_800)
    }

    func testRejectsIncompleteOrAmbiguousWeather() {
        for text in [#"{"temperature":23,"condition":"晴"}"#,
                     #"{"location":"北京","temperatureC":230,"condition":"晴","updatedAt":"2026-10-22T08:30:00Z"}"#,
                     #"{"location":"","temperatureC":23,"condition":"晴","updatedAt":"yesterday"}"#] {
            XCTAssertThrowsError(try WeatherSnapshot.parse(Data(text.utf8)))
        }
    }

    func testCacheExpiresAtFifteenMinutesAndFutureDatesAreStale() {
        let cachedAt = Date(timeIntervalSince1970: 1000)
        XCTAssertTrue(WeatherCachePolicy.isFresh(cachedAt: cachedAt, now: cachedAt.addingTimeInterval(899.999)))
        XCTAssertFalse(WeatherCachePolicy.isFresh(cachedAt: cachedAt, now: cachedAt.addingTimeInterval(900)))
        XCTAssertFalse(WeatherCachePolicy.isFresh(cachedAt: cachedAt, now: cachedAt.addingTimeInterval(-1)))
    }

    @MainActor
    func testTimeoutTerminatesActualChild() async throws {
        let runner = WeatherCommandRunner()
        let operation = Task { try await runner.run(executableURL: URL(fileURLWithPath: "/bin/sleep"), arguments: ["10"], timeout: 0.15) }
        for _ in 0..<10 where runner.runningProcessIdentifier == nil { try await Task.sleep(for: .milliseconds(10)) }
        let pid = try XCTUnwrap(runner.runningProcessIdentifier)
        do {
            _ = try await operation.value
            XCTFail("A sleeping process must time out")
        } catch {
            XCTAssertEqual(error as? WeatherBridgeError, .timedOut)
        }
        XCTAssertNil(runner.runningProcessIdentifier)
        XCTAssertEqual(Darwin.kill(pid, 0), -1)
        XCTAssertEqual(errno, ESRCH)
    }

    @MainActor
    func testCancellationTerminatesActualChild() async throws {
        let runner = WeatherCommandRunner()
        let operation = Task { try await runner.run(executableURL: URL(fileURLWithPath: "/bin/sleep"), arguments: ["10"]) }
        for _ in 0..<10 where runner.runningProcessIdentifier == nil { try await Task.sleep(for: .milliseconds(10)) }
        let pid = try XCTUnwrap(runner.runningProcessIdentifier)
        operation.cancel()
        do {
            _ = try await operation.value
            XCTFail("Cancelled process must not succeed")
        } catch {
            XCTAssertEqual(error as? WeatherBridgeError, .cancelled)
        }
        XCTAssertEqual(Darwin.kill(pid, 0), -1)
        XCTAssertEqual(errno, ESRCH)
    }

    @MainActor
    func testSuccessfulSetupPersistsCacheAndFailureRetainsLastGoodData() async throws {
        let suite = "NetStatsWeatherTest-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let fixture = directory.appendingPathComponent("fixture.json")
        let timestamp = ISO8601DateFormatter().string(from: Date().addingTimeInterval(-60))
        try JSONSerialization.data(withJSONObject: ["location": "北京", "temperatureC": 23.5,
                                                     "condition": "晴", "updatedAt": timestamp]).write(to: fixture)
        let store = WeatherStore(defaults: defaults, cacheURL: directory.appendingPathComponent("cache.json"),
                                 bridgeExecutableURL: URL(fileURLWithPath: "/bin/cp"),
                                 bridgeArguments: { _, output in [fixture.path, output.path] })
        await store.testConnection()
        XCTAssertTrue(store.isConfigured)
        XCTAssertEqual(store.snapshot?.location, "北京")
        let original = store.snapshot
        let cachedAt = store.cachedAt
        try FileManager.default.removeItem(at: fixture)
        await store.testConnection()
        XCTAssertNotNil(store.error)
        XCTAssertEqual(store.snapshot, original)
        XCTAssertEqual(store.cachedAt, cachedAt)
        let reloaded = WeatherStore(defaults: defaults, cacheURL: directory.appendingPathComponent("cache.json"))
        XCTAssertTrue(reloaded.isConfigured)
        XCTAssertEqual(reloaded.snapshot, original)
        reloaded.shortcutName = "Another Weather"
        XCTAssertFalse(reloaded.isConfigured)
    }

    @MainActor
    func testDisabledOrUnverifiedStoreNeverRunsShortcut() async throws {
        let suite = "NetStatsWeatherTest-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let cacheURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let store = WeatherStore(defaults: defaults, cacheURL: cacheURL)
        store.setEnabled(true)
        store.start()
        await store.refresh()
        XCTAssertFalse(store.isConfigured)
        XCTAssertFalse(store.isRefreshing)
        XCTAssertNil(store.snapshot)
        store.stop()
    }

    @MainActor
    func testManualRefreshBypassesCacheOnlyForEnabledVerifiedConnection() async throws {
        let suite = "NetStatsWeatherTest-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let fixture = directory.appendingPathComponent("fixture.json")
        let timestamp = ISO8601DateFormatter().string(from: Date().addingTimeInterval(-30))
        func write(_ temperature: Double) throws {
            try JSONSerialization.data(withJSONObject: ["location": "Test City", "temperatureC": temperature,
                                                         "condition": "Clear", "updatedAt": timestamp]).write(to: fixture)
        }
        try write(10)
        let store = WeatherStore(defaults: defaults, cacheURL: directory.appendingPathComponent("cache.json"),
                                 bridgeExecutableURL: URL(fileURLWithPath: "/bin/cp"),
                                 bridgeArguments: { _, output in [fixture.path, output.path] })
        store.setEnabled(true)
        await store.refresh(force: true)
        XCTAssertNil(store.snapshot, "Force cannot bypass connection verification")
        await store.testConnection()
        XCTAssertEqual(store.snapshot?.temperatureC, 10)
        try write(20)
        await store.refresh()
        XCTAssertEqual(store.snapshot?.temperatureC, 10, "Background refresh respects the 15-minute cache")
        await store.refresh(force: true)
        XCTAssertEqual(store.snapshot?.temperatureC, 20, "Explicit refresh should bypass a fresh cache")
        store.setEnabled(false)
        try write(30)
        await store.refresh(force: true)
        XCTAssertEqual(store.snapshot?.temperatureC, 20, "Force cannot bypass the feature toggle")
        store.setEnabled(true)
        try FileManager.default.removeItem(at: fixture)
        await store.refresh(force: true)
        XCTAssertEqual(store.snapshot?.temperatureC, 20)
        XCTAssertNotNil(store.error)
        store.stop()
    }
}

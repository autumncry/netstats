import AppKit
import Combine
import Darwin
import Foundation

struct WeatherSnapshot: Codable, Equatable, Sendable {
    let location: String
    let temperatureC: Double
    let condition: String
    let updatedAt: Date

    static func parse(_ data: Data) throws -> WeatherSnapshot {
        guard data.count <= 64 * 1024,
              let object = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let rawLocation = object["location"] as? String,
              let rawCondition = object["condition"] as? String,
              let temperature = object["temperatureC"] as? NSNumber,
              CFGetTypeID(temperature) != CFBooleanGetTypeID(),
              let rawDate = object["updatedAt"] as? String else {
            throw WeatherBridgeError.invalidOutput
        }
        let location = rawLocation.trimmingCharacters(in: .whitespacesAndNewlines)
        let condition = rawCondition.trimmingCharacters(in: .whitespacesAndNewlines)
        let formatter = ISO8601DateFormatter()
        var date = formatter.date(from: rawDate)
        if date == nil {
            formatter.formatOptions.insert(.withFractionalSeconds)
            date = formatter.date(from: rawDate)
        }
        guard !location.isEmpty, location.count <= 120,
              !condition.isEmpty, condition.count <= 120,
              temperature.doubleValue.isFinite,
              (-100...80).contains(temperature.doubleValue), let date else {
            throw WeatherBridgeError.invalidOutput
        }
        return WeatherSnapshot(location: location, temperatureC: temperature.doubleValue, condition: condition, updatedAt: date)
    }

    var systemImage: String {
        let text = condition.lowercased()
        if ["雷", "thunder", "storm"].contains(where: text.contains) { return "cloud.bolt.rain.fill" }
        if ["雪", "snow", "sleet"].contains(where: text.contains) { return "cloud.snow.fill" }
        if ["雨", "rain", "drizzle"].contains(where: text.contains) { return "cloud.rain.fill" }
        if ["雾", "fog", "haze", "霾"].contains(where: text.contains) { return "cloud.fog.fill" }
        if ["云", "cloud", "overcast", "阴"].contains(where: text.contains) { return "cloud.fill" }
        if ["晴", "clear", "sun"].contains(where: text.contains) { return "sun.max.fill" }
        return "cloud.sun.fill"
    }
}

enum WeatherCachePolicy {
    static let interval: TimeInterval = 15 * 60

    static func isFresh(cachedAt: Date?, now: Date = Date()) -> Bool {
        guard let cachedAt else { return false }
        let age = now.timeIntervalSince(cachedAt)
        return age >= 0 && age < interval
    }
}

enum WeatherBridgeError: Error, Equatable {
    case launchFailed
    case failed(Int32)
    case timedOut
    case cancelled
    case invalidOutput
    case busy
}

/// Owns the actual CLI process until it has exited, including timeout escalation.
@MainActor
final class WeatherCommandRunner {
    private var process: Process?
    private var continuation: CheckedContinuation<Int32, Error>?
    private var timeoutTask: Task<Void, Never>?
    private var killTask: Task<Void, Never>?
    private var failure: WeatherBridgeError?
    private var runID: UUID?

    var runningProcessIdentifier: Int32? { process?.processIdentifier }

    func run(executableURL: URL, arguments: [String], timeout: TimeInterval = 20) async throws -> Int32 {
        guard process == nil else { throw WeatherBridgeError.busy }
        let identifier = UUID()
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { result in
                guard !Task.isCancelled else {
                    result.resume(throwing: WeatherBridgeError.cancelled)
                    return
                }
                let child = Process()
                child.executableURL = executableURL
                child.arguments = arguments
                child.standardOutput = FileHandle.nullDevice
                child.standardError = FileHandle.nullDevice
                child.standardInput = FileHandle.nullDevice
                child.terminationHandler = { [weak self] child in
                    let status = child.terminationStatus
                    Task { @MainActor in self?.finished(identifier: identifier, status: status) }
                }
                process = child
                continuation = result
                runID = identifier
                failure = nil
                do {
                    try child.run()
                    timeoutTask = Task { [weak self] in
                        do { try await Task.sleep(for: .seconds(max(0.01, timeout))) }
                        catch { return }
                        self?.cancel(identifier: identifier, reason: .timedOut)
                    }
                } catch {
                    finished(identifier: identifier, status: -1, launchFailure: true)
                }
            }
        } onCancel: {
            Task { @MainActor [weak self] in self?.cancel(identifier: identifier, reason: .cancelled) }
        }
    }

    func cancel() {
        if let runID { cancel(identifier: runID, reason: .cancelled) }
    }

    private func cancel(identifier: UUID, reason: WeatherBridgeError) {
        guard identifier == runID, let process else { return }
        if failure == nil { failure = reason }
        timeoutTask?.cancel()
        guard process.isRunning else { return }
        process.terminate()
        let pid = process.processIdentifier
        killTask?.cancel()
        killTask = Task { [weak self] in
            do { try await Task.sleep(for: .milliseconds(250)) }
            catch { return }
            guard self?.runID == identifier, self?.process?.isRunning == true else { return }
            Darwin.kill(pid, SIGKILL)
        }
    }

    private func finished(identifier: UUID, status: Int32, launchFailure: Bool = false) {
        guard runID == identifier else { return }
        let result = continuation
        let error = failure ?? (launchFailure ? .launchFailed : nil)
        timeoutTask?.cancel()
        killTask?.cancel()
        timeoutTask = nil
        killTask = nil
        process = nil
        continuation = nil
        failure = nil
        runID = nil
        if let error { result?.resume(throwing: error) }
        else if status != 0 { result?.resume(throwing: WeatherBridgeError.failed(status)) }
        else { result?.resume(returning: status) }
    }
}

@MainActor
final class WeatherStore: ObservableObject {
    @Published var shortcutName: String {
        didSet {
            guard oldValue != shortcutName else { return }
            defaults.set(shortcutName, forKey: Self.nameKey)
            isConfigured = false
            defaults.removeObject(forKey: Self.verifiedKey)
            cancelRefresh()
            error = nil
        }
    }
    @Published private(set) var snapshot: WeatherSnapshot?
    @Published private(set) var cachedAt: Date?
    @Published private(set) var isRefreshing = false
    @Published private(set) var isConfigured = false
    @Published private(set) var error: WeatherBridgeError?

    var canRefresh: Bool { enabled && isConfigured && !isRefreshing }

    private static let nameKey = "hub.weather.shortcutName"
    private static let verifiedKey = "hub.weather.verifiedShortcut"
    private let defaults: UserDefaults
    private let cacheURL: URL
    private let bridgeExecutableURL: URL
    private let bridgeArguments: (String, URL) -> [String]
    private let runner = WeatherCommandRunner()
    private var enabled = false
    private var started = false
    private var timer: Timer?
    private var task: Task<Void, Never>?
    private var generation = UUID()

    init(defaults: UserDefaults = .standard, cacheURL: URL? = nil,
         bridgeExecutableURL: URL = URL(fileURLWithPath: "/usr/bin/shortcuts"),
         bridgeArguments: ((String, URL) -> [String])? = nil) {
        self.defaults = defaults
        self.bridgeExecutableURL = bridgeExecutableURL
        self.bridgeArguments = bridgeArguments ?? { name, output in
            ["run", name, "--output-path", output.path, "--output-type", "public.utf8-plain-text"]
        }
        self.cacheURL = cacheURL ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("NetStats", isDirectory: true).appendingPathComponent("weather-cache.json")
        shortcutName = defaults.string(forKey: Self.nameKey) ?? "NetStats Weather"
        isConfigured = defaults.string(forKey: Self.verifiedKey) == shortcutName && !shortcutName.isEmpty
        if let data = try? Data(contentsOf: self.cacheURL),
           let cache = try? JSONDecoder().decode(WeatherCache.self, from: data), cache.shortcutName == shortcutName {
            snapshot = cache.snapshot
            cachedAt = cache.cachedAt
        }
    }

    func start() {
        guard !started else { return }
        started = true
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in await self?.refresh() }
        }
        if let timer { RunLoop.main.add(timer, forMode: .common) }
        if enabled && isConfigured { task = Task { [weak self] in await self?.refresh() } }
    }

    func stop() {
        started = false
        timer?.invalidate()
        timer = nil
        cancelRefresh()
    }

    func setEnabled(_ value: Bool) {
        guard enabled != value else { return }
        enabled = value
        if !value { cancelRefresh() }
        else if started && isConfigured { task = Task { [weak self] in await self?.refresh() } }
    }

    func refresh(force: Bool = false) async {
        guard enabled, isConfigured, !isRefreshing,
              force || !WeatherCachePolicy.isFresh(cachedAt: cachedAt) else { return }
        await runBridge(explicitTest: false)
    }

    func testConnection() async {
        guard !isRefreshing else { return }
        await runBridge(explicitTest: true)
    }

    func clearConnection() {
        cancelRefresh()
        isConfigured = false
        snapshot = nil
        cachedAt = nil
        error = nil
        defaults.removeObject(forKey: Self.verifiedKey)
        try? FileManager.default.removeItem(at: cacheURL)
    }

    func openShortcuts() { NSWorkspace.shared.open(URL(string: "shortcuts://")!) }

    func openWeather() { NSWorkspace.shared.open(URL(string: "weather:")!) }

    private func runBridge(explicitTest: Bool) async {
        let name = shortcutName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, name.count <= 256 else {
            error = .invalidOutput
            return
        }
        let token = UUID()
        generation = token
        isRefreshing = true
        error = nil
        let temporary = FileManager.default.temporaryDirectory.appendingPathComponent("netstats-weather-\(UUID().uuidString).json")
        defer {
            try? FileManager.default.removeItem(at: temporary)
            if generation == token { isRefreshing = false }
        }
        do {
            _ = try await runner.run(executableURL: bridgeExecutableURL, arguments: bridgeArguments(name, temporary))
            guard generation == token else { return }
            let values = try temporary.resourceValues(forKeys: [.fileSizeKey])
            guard let size = values.fileSize, size <= 64 * 1024 else { throw WeatherBridgeError.invalidOutput }
            let weather = try WeatherSnapshot.parse(Data(contentsOf: temporary))
            guard weather.updatedAt <= Date().addingTimeInterval(10 * 60) else { throw WeatherBridgeError.invalidOutput }
            snapshot = weather
            cachedAt = Date()
            if explicitTest {
                isConfigured = true
                defaults.set(shortcutName, forKey: Self.verifiedKey)
            }
            let cache = WeatherCache(shortcutName: shortcutName, snapshot: weather, cachedAt: cachedAt!)
            do {
                try FileManager.default.createDirectory(at: cacheURL.deletingLastPathComponent(), withIntermediateDirectories: true)
                try JSONEncoder().encode(cache).write(to: cacheURL, options: .atomic)
            } catch {
                // Current data remains usable when the optional on-disk cache cannot be saved.
            }
        } catch {
            guard generation == token else { return }
            self.error = (error as? WeatherBridgeError) ?? .invalidOutput
        }
    }

    private func cancelRefresh() {
        generation = UUID()
        task?.cancel()
        task = nil
        runner.cancel()
        isRefreshing = false
    }
}

private struct WeatherCache: Codable {
    let shortcutName: String
    let snapshot: WeatherSnapshot
    let cachedAt: Date
}

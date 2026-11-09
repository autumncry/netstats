import AppKit
import Combine
import Darwin
import Foundation

struct WeatherSnapshot: Codable, Equatable, Sendable {
    let location: String
    let temperatureC: Double
    let condition: String
    let updatedAt: Date

    static func parse(_ data: Data, receivedAt: Date = Date()) throws -> WeatherSnapshot {
        guard data.count <= 64 * 1024 else { throw WeatherBridgeError.invalidOutput }
        if let raw = String(data: data, encoding: .utf8) {
            let text = raw.trimmingCharacters(in: .whitespacesAndNewlines.union(CharacterSet(charactersIn: "\u{feff}")))
            if text.hasPrefix("NETSTATS_WEATHER_V1") {
                return try parseBeginnerText(text, receivedAt: receivedAt)
            }
        }
        guard
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

    private static func parseBeginnerText(_ text: String, receivedAt: Date) throws -> WeatherSnapshot {
        let lines = text.replacingOccurrences(of: "\r\n", with: "\n")
            .components(separatedBy: "\n").map { $0.trimmingCharacters(in: .whitespaces) }
        let setupPlaceholders: Set<String> = [
            "【城市】", "【城市变量】", "[City]", "[City variable]",
            "【天气状况变量】", "【天气状况】", "[Conditions variable]", "[Conditions]"
        ]
        guard lines.count == 4, lines[0] == "NETSTATS_WEATHER_V1",
              !lines[1].isEmpty, lines[1].count <= 120,
              !lines[3].isEmpty, lines[3].count <= 120,
              !setupPlaceholders.contains(lines[1]), !setupPlaceholders.contains(lines[3]) else {
            throw WeatherBridgeError.invalidOutput
        }
        let temperature = lines[2].replacingOccurrences(of: "℃", with: "°C")
            .replacingOccurrences(of: "℉", with: "°F")
            .replacingOccurrences(of: "−", with: "-")
        let pattern = #"^([+-]?[0-9]+(?:\.[0-9]+)?)\s*°\s*([CF])$"#
        let expression = try NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
        guard let match = expression.firstMatch(in: temperature, range: NSRange(temperature.startIndex..., in: temperature)),
              let numberRange = Range(match.range(at: 1), in: temperature),
              let unitRange = Range(match.range(at: 2), in: temperature),
              let number = Double(temperature[numberRange]), number.isFinite else { throw WeatherBridgeError.invalidOutput }
        let celsius = temperature[unitRange].uppercased() == "F" ? (number - 32) * 5 / 9 : number
        guard (-100...80).contains(celsius), receivedAt.timeIntervalSince1970.isFinite else { throw WeatherBridgeError.invalidOutput }
        return WeatherSnapshot(location: lines[1], temperatureC: celsius, condition: lines[3], updatedAt: receivedAt)
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
    case missingShortcut
    case noOutput
    case shortcutLookupFailed
    case busy
}

enum WeatherShortcutCatalog {
    static func contains(_ name: String, in data: Data) throws -> Bool {
        guard data.count <= 64 * 1024, let text = String(data: data, encoding: .utf8) else {
            throw WeatherBridgeError.shortcutLookupFailed
        }
        return text.replacingOccurrences(of: "\r\n", with: "\n").components(separatedBy: "\n").contains(name)
    }
}

/// Drains a nonblocking pipe on one serial queue, keeping at most64KiB in memory.
/// Finish never waits for a descendant that might keep an inherited pipe open.
private final class WeatherOutputCapture: @unchecked Sendable {
    let pipe = Pipe()
    private let queue = DispatchQueue(label: "com.ronnycao.netstats.weather-output")
    private var source: DispatchSourceRead?
    private var data = Data()
    private var exceededLimit = false
    private var closed = false
    private let limit = 64 * 1024

    init() throws {
        let fd = pipe.fileHandleForReading.fileDescriptor
        let flags = fcntl(fd, F_GETFL)
        guard flags != -1, fcntl(fd, F_SETFL, flags | O_NONBLOCK) != -1 else {
            throw WeatherBridgeError.launchFailed
        }
        let source = DispatchSource.makeReadSource(fileDescriptor: fd, queue: queue)
        self.source = source
        source.setEventHandler { [weak self] in self?.drain() }
        source.resume()
    }

    func closeWriter() { try? pipe.fileHandleForWriting.close() }

    func finish(_ completion: @escaping @Sendable (Data, Bool) -> Void) {
        queue.async {
            if !self.closed {
                self.drain()
                self.source?.cancel()
                self.source = nil
                try? self.pipe.fileHandleForReading.close()
                self.closed = true
            }
            completion(self.data, self.exceededLimit)
        }
    }

    private func drain() {
        guard !closed else { return }
        var bytes = [UInt8](repeating: 0, count: 4096)
        for _ in 0..<32 {
            let count = Darwin.read(pipe.fileHandleForReading.fileDescriptor, &bytes, bytes.count)
            if count > 0 {
                let available = max(0, limit - data.count)
                data.append(contentsOf: bytes.prefix(min(count, available)))
                if count > available { exceededLimit = true }
            } else {
                if count == 0 { source?.cancel(); source = nil }
                return
            }
        }
    }
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

    private(set) var capturedOutput = Data()
    var runningProcessIdentifier: Int32? { process?.processIdentifier }

    func run(executableURL: URL, arguments: [String], timeout: TimeInterval = 20, captureOutput: Bool = false) async throws -> Int32 {
        guard process == nil else { throw WeatherBridgeError.busy }
        let identifier = UUID()
        let capture = captureOutput ? try WeatherOutputCapture() : nil
        capturedOutput = Data()
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { result in
                guard !Task.isCancelled else {
                    capture?.closeWriter()
                    capture?.finish { _, _ in }
                    result.resume(throwing: WeatherBridgeError.cancelled)
                    return
                }
                let child = Process()
                child.executableURL = executableURL
                child.arguments = arguments
                if let capture { child.standardOutput = capture.pipe }
                else { child.standardOutput = FileHandle.nullDevice }
                child.standardError = FileHandle.nullDevice
                child.standardInput = FileHandle.nullDevice
                child.terminationHandler = { [weak self] child in
                    let status = child.terminationStatus
                    if let capture {
                        capture.finish { [weak self] output, exceeded in
                            Task { @MainActor in self?.finished(identifier: identifier, status: status, output: output, outputExceededLimit: exceeded) }
                        }
                    } else {
                        Task { @MainActor in self?.finished(identifier: identifier, status: status) }
                    }
                }
                process = child
                continuation = result
                runID = identifier
                failure = nil
                do {
                    try child.run()
                    capture?.closeWriter()
                    timeoutTask = Task { [weak self] in
                        do { try await Task.sleep(for: .seconds(max(0.01, timeout))) }
                        catch { return }
                        self?.cancel(identifier: identifier, reason: .timedOut)
                    }
                } catch {
                    capture?.closeWriter()
                    capture?.finish { _, _ in }
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

    private func finished(identifier: UUID, status: Int32, launchFailure: Bool = false, output: Data = Data(), outputExceededLimit: Bool = false) {
        guard runID == identifier else { return }
        let result = continuation
        let error = failure ?? (launchFailure ? .launchFailed : outputExceededLimit ? .shortcutLookupFailed : nil)
        capturedOutput = output
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
    private let shortcutPreflight: ((String) async throws -> Bool)?
    private let runner = WeatherCommandRunner()
    private var enabled = false
    private var started = false
    private var timer: Timer?
    private var task: Task<Void, Never>?
    private var generation = UUID()

    init(defaults: UserDefaults = .standard, cacheURL: URL? = nil,
         bridgeExecutableURL: URL = URL(fileURLWithPath: "/usr/bin/shortcuts"),
         bridgeArguments: ((String, URL) -> [String])? = nil,
         shortcutPreflight: ((String) async throws -> Bool)? = nil) {
        self.defaults = defaults
        self.bridgeExecutableURL = bridgeExecutableURL
        self.shortcutPreflight = shortcutPreflight
        self.bridgeArguments = bridgeArguments ?? { name, output in
            // Let Shortcuts infer plain text from the .txt destination. On
            // macOS 27, forcing public.utf8-plain-text can exit 0 with no file.
            ["run", name, "--output-path", output.path]
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
        let deadline = ProcessInfo.processInfo.systemUptime + 20
        let temporary = FileManager.default.temporaryDirectory.appendingPathComponent("netstats-weather-\(UUID().uuidString).txt")
        defer {
            try? FileManager.default.removeItem(at: temporary)
            if generation == token { isRefreshing = false }
        }
        do {
            if explicitTest {
                if let shortcutPreflight {
                    guard try await shortcutPreflight(name) else { throw WeatherBridgeError.missingShortcut }
                } else if bridgeExecutableURL.standardizedFileURL.path == "/usr/bin/shortcuts" {
                    _ = try await runner.run(executableURL: bridgeExecutableURL, arguments: ["list"],
                                             timeout: max(0.01, deadline - ProcessInfo.processInfo.systemUptime), captureOutput: true)
                    guard try WeatherShortcutCatalog.contains(name, in: runner.capturedOutput) else {
                        throw WeatherBridgeError.missingShortcut
                    }
                }
                guard generation == token, !Task.isCancelled else { return }
            }
            let remaining = deadline - ProcessInfo.processInfo.systemUptime
            guard remaining > 0 else { throw WeatherBridgeError.timedOut }
            _ = try await runner.run(executableURL: bridgeExecutableURL, arguments: bridgeArguments(name, temporary), timeout: remaining)
            guard generation == token else { return }
            guard FileManager.default.fileExists(atPath: temporary.path) else { throw WeatherBridgeError.noOutput }
            let values = try temporary.resourceValues(forKeys: [.fileSizeKey])
            guard let size = values.fileSize, size <= 64 * 1024 else { throw WeatherBridgeError.invalidOutput }
            guard size > 0 else { throw WeatherBridgeError.noOutput }
            let output = try Data(contentsOf: temporary)
            if let text = String(data: output, encoding: .utf8), text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                throw WeatherBridgeError.noOutput
            }
            let weather = try WeatherSnapshot.parse(output)
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

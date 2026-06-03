import Combine
import Foundation

struct ClashStatus: Equatable, Sendable {
    var isRunning: Bool
    var controllerAvailable: Bool
    var systemProxyEnabled: Bool
    var proxyAutoConfigEnabled: Bool
    var tunEnabled: Bool
    var tunDevice: String?
    var mode: String?
    var selectedGroup: String?
    var selectedNode: String?
    var subscriptionName: String?
    var subscriptionTraffic: ClashSubscriptionTraffic?
    var mixedPort: Int?
    var errorMessage: String?
    var updatedAt: Date

    static let empty = ClashStatus(
        isRunning: false,
        controllerAvailable: false,
        systemProxyEnabled: false,
        proxyAutoConfigEnabled: false,
        tunEnabled: false,
        tunDevice: nil,
        mode: nil,
        selectedGroup: nil,
        selectedNode: nil,
        subscriptionName: nil,
        subscriptionTraffic: nil,
        mixedPort: nil,
        errorMessage: nil,
        updatedAt: Date()
    )
}

@MainActor
final class ClashStatusStore: ObservableObject {
    @Published private(set) var status = ClashStatus.empty

    private var timer: Timer?
    private var isRefreshing = false

    func start() {
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refresh()
            }
        }

        if let timer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func refresh() {
        guard !isRefreshing else {
            return
        }

        isRefreshing = true
        DispatchQueue.global(qos: .utility).async {
            let status = Self.fetchStatus()
            DispatchQueue.main.async {
                self.status = status
                self.isRefreshing = false
            }
        }
    }

    nonisolated private static func fetchStatus() -> ClashStatus {
        let files = clashConfigFiles()
        let vergeConfig = readText(files.verge)
        let generatedConfig = readText(files.generated)
        let profilesConfig = readText(files.profiles)
        let selectedProfile = ClashProfileParser.selectedProfile(from: profilesConfig)

        let isRunning = processExists(pattern: "clash-verge|Clash Verge|verge-mihomo|mihomo")
        let unixSocket = parseStringValue("external-controller-unix", from: generatedConfig)
            ?? "/tmp/verge/verge-mihomo.sock"
        let secret = parseStringValue("secret", from: generatedConfig) ?? "set-your-secret"

        var apiConfig: ClashAPIConfig?
        if FileManager.default.fileExists(atPath: unixSocket) {
            apiConfig = fetchClashAPIConfig(unixSocket: unixSocket, secret: secret)
        }

        let mixedPort = apiConfig?.mixedPort
            ?? parseIntValue("mixed-port", from: generatedConfig)
            ?? parseIntValue("verge_mixed_port", from: vergeConfig)
        let proxyAutoConfigEnabled = parseBoolValue("proxy_auto_config", from: vergeConfig) ?? false
        let systemProxyEnabled = readSystemProxyEnabled(expectedPort: mixedPort)
            ?? parseBoolValue("enable_system_proxy", from: vergeConfig)
            ?? false
        let tunEnabled = apiConfig?.tunEnabled
            ?? parseBoolValue("enable", from: block(named: "tun", in: generatedConfig))
            ?? parseBoolValue("enable_tun_mode", from: vergeConfig)
            ?? false

        let errorMessage: String? = isRunning
            ? (apiConfig == nil ? "Controller unavailable" : nil)
            : "Not running"

        return ClashStatus(
            isRunning: isRunning,
            controllerAvailable: apiConfig != nil,
            systemProxyEnabled: systemProxyEnabled,
            proxyAutoConfigEnabled: proxyAutoConfigEnabled,
            tunEnabled: tunEnabled,
            tunDevice: apiConfig?.tunDevice,
            mode: apiConfig?.mode ?? parseStringValue("mode", from: generatedConfig),
            selectedGroup: selectedProfile.selectedGroup,
            selectedNode: selectedProfile.selectedNode,
            subscriptionName: selectedProfile.subscriptionName,
            subscriptionTraffic: selectedProfile.traffic,
            mixedPort: mixedPort,
            errorMessage: errorMessage,
            updatedAt: Date()
        )
    }

    nonisolated private static func fetchClashAPIConfig(unixSocket: String, secret: String) -> ClashAPIConfig? {
        let output = run(
            "/usr/bin/curl",
            arguments: [
                "--unix-socket", unixSocket,
                "-sS",
                "--max-time", "2",
                "-H", "Authorization: Bearer \(secret)",
                "http://localhost/configs"
            ]
        )

        guard let data = output?.data(using: .utf8),
              let payload = try? JSONDecoder().decode(ClashAPIConfigResponse.self, from: data) else {
            return nil
        }

        return ClashAPIConfig(
            mode: payload.mode,
            tunEnabled: payload.tun?.enable,
            tunDevice: payload.tun?.device,
            mixedPort: payload.mixedPort
        )
    }

    nonisolated private static func readSystemProxyEnabled(expectedPort: Int?) -> Bool? {
        guard let output = run("/usr/sbin/scutil", arguments: ["--proxy"]) else {
            return nil
        }

        return ClashSystemProxyParser.isEnabled(scutilOutput: output, expectedPort: expectedPort)
    }

    nonisolated private static func block(named name: String, in text: String?) -> String? {
        guard let text else { return nil }
        let lines = text.components(separatedBy: .newlines)
        var collecting = false
        var collected: [String] = []

        for line in lines {
            if line == "\(name):" {
                collecting = true
                continue
            }

            if collecting {
                if !line.hasPrefix(" "), !line.isEmpty {
                    break
                }
                collected.append(line)
            }
        }

        return collected.isEmpty ? nil : collected.joined(separator: "\n")
    }

    nonisolated private static func parseStringValue(_ key: String, from text: String?) -> String? {
        guard let text else { return nil }
        for line in text.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            let plainPrefix = "\(key):"
            let listPrefix = "- \(key):"
            guard trimmed.hasPrefix(plainPrefix) || trimmed.hasPrefix(listPrefix) else {
                continue
            }

            let prefixLength = trimmed.hasPrefix(listPrefix) ? listPrefix.count : plainPrefix.count
            let value = cleanYAMLValue(String(trimmed.dropFirst(prefixLength)))
            return value.isEmpty ? nil : value
        }

        return nil
    }

    nonisolated private static func parseIntValue(_ key: String, from text: String?) -> Int? {
        parseStringValue(key, from: text).flatMap(Int.init)
    }

    nonisolated private static func parseBoolValue(_ key: String, from text: String?) -> Bool? {
        guard let value = parseStringValue(key, from: text)?.lowercased() else {
            return nil
        }

        if ["true", "yes", "1"].contains(value) {
            return true
        }
        if ["false", "no", "0"].contains(value) {
            return false
        }
        return nil
    }

    nonisolated private static func cleanYAMLValue(_ rawValue: String) -> String {
        var value = rawValue.trimmingCharacters(in: .whitespaces)
        if value == "null" {
            return ""
        }
        if (value.hasPrefix("\"") && value.hasSuffix("\""))
            || (value.hasPrefix("'") && value.hasSuffix("'")) {
            value.removeFirst()
            value.removeLast()
        }
        return value
    }

    nonisolated private static func readText(_ url: URL) -> String? {
        try? String(contentsOf: url, encoding: .utf8)
    }

    nonisolated private static func processExists(pattern: String) -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/pgrep")
        process.arguments = ["-f", pattern]
        process.standardOutput = Pipe()
        process.standardError = Pipe()

        do {
            try process.run()
        } catch {
            return false
        }

        process.waitUntilExit()
        return process.terminationStatus == 0
    }

    nonisolated private static func run(_ executable: String, arguments: [String]) -> String? {
        let process = Process()
        let output = Pipe()
        let error = Pipe()

        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.standardOutput = output
        process.standardError = error

        do {
            try process.run()
        } catch {
            return nil
        }

        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            return nil
        }

        let data = output.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8)
    }

    nonisolated private static func clashConfigFiles() -> ClashConfigFiles {
        let appSupport = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/io.github.clash-verge-rev.clash-verge-rev")
        return ClashConfigFiles(
            appSupport: appSupport,
            verge: appSupport.appendingPathComponent("verge.yaml"),
            base: appSupport.appendingPathComponent("config.yaml"),
            generated: appSupport.appendingPathComponent("clash-verge.yaml"),
            profiles: appSupport.appendingPathComponent("profiles.yaml")
        )
    }
}

private struct ClashConfigFiles: Sendable {
    let appSupport: URL
    let verge: URL
    let base: URL
    let generated: URL
    let profiles: URL
}

private struct ClashAPIConfig: Sendable {
    let mode: String?
    let tunEnabled: Bool?
    let tunDevice: String?
    let mixedPort: Int?
}

private struct ClashAPIConfigResponse: Decodable, Sendable {
    let mode: String?
    let tun: ClashAPITun?

    private let mixedPortValue: Int?

    var mixedPort: Int? { mixedPortValue }

    enum CodingKeys: String, CodingKey {
        case mode
        case tun
        case mixedPortValue = "mixed-port"
    }
}

private struct ClashAPITun: Decodable, Sendable {
    let enable: Bool?
    let device: String?
}

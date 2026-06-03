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
        mixedPort: nil,
        errorMessage: nil,
        updatedAt: Date()
    )
}

@MainActor
final class ClashStatusStore: ObservableObject {
    @Published private(set) var status = ClashStatus.empty
    @Published private(set) var pendingAction: ClashControlAction?
    @Published private(set) var controlErrorMessage: String?

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

    func setSystemProxyEnabled(_ enabled: Bool) {
        performControl(.systemProxy) {
            try Self.applySystemProxy(enabled)
        }
    }

    func setTunEnabled(_ enabled: Bool) {
        performControl(.tun) {
            try Self.applyTun(enabled)
        }
    }

    func setMode(_ mode: ClashMode) {
        performControl(.mode) {
            try Self.applyMode(mode)
        }
    }

    private func performControl(_ action: ClashControlAction, operation: @escaping @Sendable () throws -> Void) {
        guard pendingAction == nil else {
            return
        }

        pendingAction = action
        controlErrorMessage = nil

        DispatchQueue.global(qos: .utility).async {
            let errorMessage: String?
            do {
                try operation()
                errorMessage = nil
            } catch {
                errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            }

            let status = Self.fetchStatus()
            DispatchQueue.main.async {
                self.status = status
                self.controlErrorMessage = errorMessage
                self.pendingAction = nil
            }
        }
    }

    nonisolated private static func fetchStatus() -> ClashStatus {
        let files = clashConfigFiles()
        let vergeConfig = readText(files.verge)
        let generatedConfig = readText(files.generated)
        let profilesConfig = readText(files.profiles)
        let selectedProfile = parseSelectedProfile(from: profilesConfig)

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
            mixedPort: mixedPort,
            errorMessage: errorMessage,
            updatedAt: Date()
        )
    }

    nonisolated private static func applySystemProxy(_ enabled: Bool) throws {
        let files = clashConfigFiles()
        guard processExists(pattern: "clash-verge|Clash Verge|verge-mihomo|mihomo") else {
            throw ClashControlError.notRunning
        }

        let vergeConfig = readText(files.verge)
        let generatedConfig = readText(files.generated)
        let host = parseStringValue("proxy_host", from: vergeConfig) ?? "127.0.0.1"
        let mixedPort = parseIntValue("mixed-port", from: generatedConfig)
            ?? parseIntValue("verge_mixed_port", from: vergeConfig)
        let usePAC = parseBoolValue("proxy_auto_config", from: vergeConfig) ?? false

        if enabled && !usePAC && mixedPort == nil {
            throw ClashControlError.missingMixedPort
        }

        let services = try activeNetworkServices()
        guard !services.isEmpty else {
            throw ClashControlError.noNetworkServices
        }

        for service in services {
            if enabled {
                if usePAC {
                    let pacURL = "http://\(host):33331/commands/pac"
                    try runRequired("/usr/sbin/networksetup", arguments: ["-setautoproxyurl", service, pacURL])
                    try runRequired("/usr/sbin/networksetup", arguments: ["-setautoproxystate", service, "on"])
                } else {
                    guard let mixedPort else {
                        throw ClashControlError.missingMixedPort
                    }
                    let port = String(mixedPort)
                    try runRequired("/usr/sbin/networksetup", arguments: ["-setwebproxy", service, host, port])
                    try runRequired("/usr/sbin/networksetup", arguments: ["-setsecurewebproxy", service, host, port])
                    try runRequired("/usr/sbin/networksetup", arguments: ["-setsocksfirewallproxy", service, host, port])
                    try runRequired("/usr/sbin/networksetup", arguments: ["-setwebproxystate", service, "on"])
                    try runRequired("/usr/sbin/networksetup", arguments: ["-setsecurewebproxystate", service, "on"])
                    try runRequired("/usr/sbin/networksetup", arguments: ["-setsocksfirewallproxystate", service, "on"])
                }
            } else {
                try runRequired("/usr/sbin/networksetup", arguments: ["-setwebproxystate", service, "off"])
                try runRequired("/usr/sbin/networksetup", arguments: ["-setsecurewebproxystate", service, "off"])
                try runRequired("/usr/sbin/networksetup", arguments: ["-setsocksfirewallproxystate", service, "off"])
                try runRequired("/usr/sbin/networksetup", arguments: ["-setautoproxystate", service, "off"])
            }
        }

        try updateConfigFile(files.verge) {
            ClashConfigTextEditor.setTopLevelScalar("enable_system_proxy", to: enabled ? "true" : "false", in: $0)
        }
    }

    nonisolated private static func applyTun(_ enabled: Bool) throws {
        let files = clashConfigFiles()
        let context = try controllerContext(files: files)
        try patchClashAPIConfig(
            unixSocket: context.unixSocket,
            secret: context.secret,
            payload: #"{"tun":{"enable":\#(enabled ? "true" : "false")}}"#
        )

        try updateConfigFile(files.verge) {
            ClashConfigTextEditor.setTopLevelScalar("enable_tun_mode", to: enabled ? "true" : "false", in: $0)
        }
        try updateConfigFile(files.base) {
            ClashConfigTextEditor.setNestedBool("enable", to: enabled, inBlock: "tun", text: $0)
        }
        try updateConfigFile(files.generated) {
            ClashConfigTextEditor.setNestedBool("enable", to: enabled, inBlock: "tun", text: $0)
        }
    }

    nonisolated private static func applyMode(_ mode: ClashMode) throws {
        let files = clashConfigFiles()
        let context = try controllerContext(files: files)
        try patchClashAPIConfig(
            unixSocket: context.unixSocket,
            secret: context.secret,
            payload: #"{"mode":"\#(mode.rawValue)"}"#
        )

        try updateConfigFile(files.base) {
            ClashConfigTextEditor.setTopLevelScalar("mode", to: mode.rawValue, in: $0)
        }
        try updateConfigFile(files.generated) {
            ClashConfigTextEditor.setTopLevelScalar("mode", to: mode.rawValue, in: $0)
        }
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

    nonisolated private static func patchClashAPIConfig(unixSocket: String, secret: String, payload: String) throws {
        try runRequired(
            "/usr/bin/curl",
            arguments: [
                "--unix-socket", unixSocket,
                "-sS",
                "--max-time", "2",
                "-X", "PATCH",
                "-H", "Authorization: Bearer \(secret)",
                "-H", "Content-Type: application/json",
                "-d", payload,
                "http://localhost/configs"
            ]
        )
    }

    nonisolated private static func readSystemProxyEnabled(expectedPort: Int?) -> Bool? {
        guard let output = run("/usr/sbin/scutil", arguments: ["--proxy"]) else {
            return nil
        }

        return ClashSystemProxyParser.isEnabled(scutilOutput: output, expectedPort: expectedPort)
    }

    nonisolated private static func parseSelectedProfile(from text: String?) -> SelectedProfile {
        guard let text else {
            return SelectedProfile(subscriptionName: nil, selectedGroup: nil, selectedNode: nil)
        }

        let current = parseStringValue("current", from: text)
        let blocks = splitYAMLItems(text)
        let block = blocks.first { parseStringValue("uid", from: $0) == current }
        let subscriptionName = block.flatMap { parseStringValue("name", from: $0) }
        let selections = block.map(parseSelections) ?? []
        let preferredSelection = selections.first { $0.group.uppercased() != "GLOBAL" } ?? selections.first

        return SelectedProfile(
            subscriptionName: subscriptionName,
            selectedGroup: preferredSelection?.group,
            selectedNode: preferredSelection?.node
        )
    }

    nonisolated private static func parseSelections(from block: String) -> [(group: String, node: String)] {
        let lines = block.components(separatedBy: .newlines)
        var selections: [(group: String, node: String)] = []
        var currentName: String?

        for rawLine in lines {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.hasPrefix("- name:") {
                currentName = cleanYAMLValue(String(line.dropFirst("- name:".count)))
            } else if line.hasPrefix("now:"), let name = currentName {
                let node = cleanYAMLValue(String(line.dropFirst("now:".count)))
                selections.append((group: name, node: node))
                currentName = nil
            }
        }

        return selections
    }

    nonisolated private static func splitYAMLItems(_ text: String) -> [String] {
        var blocks: [String] = []
        var current: [String] = []

        for line in text.components(separatedBy: .newlines) {
            if line.hasPrefix("- uid:"), !current.isEmpty {
                blocks.append(current.joined(separator: "\n"))
                current = [line]
            } else if line.hasPrefix("- uid:") || !current.isEmpty {
                current.append(line)
            }
        }

        if !current.isEmpty {
            blocks.append(current.joined(separator: "\n"))
        }

        return blocks
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

    nonisolated private static func updateConfigFile(_ url: URL, transform: (String) -> String) throws {
        guard let text = readText(url) else {
            throw ClashControlError.configReadFailed(url.lastPathComponent)
        }

        do {
            try transform(text).write(to: url, atomically: true, encoding: .utf8)
        } catch {
            throw ClashControlError.configWriteFailed(url.lastPathComponent)
        }
    }

    nonisolated private static func activeNetworkServices() throws -> [String] {
        guard let output = run("/usr/sbin/networksetup", arguments: ["-listallnetworkservices"]) else {
            throw ClashControlError.commandFailed("networksetup -listallnetworkservices")
        }

        return output
            .components(separatedBy: .newlines)
            .dropFirst()
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && !$0.hasPrefix("*") }
    }

    nonisolated private static func controllerContext(files: ClashConfigFiles) throws -> ClashControllerContext {
        guard processExists(pattern: "clash-verge|Clash Verge|verge-mihomo|mihomo") else {
            throw ClashControlError.notRunning
        }

        let generatedConfig = readText(files.generated)
        let unixSocket = parseStringValue("external-controller-unix", from: generatedConfig)
            ?? "/tmp/verge/verge-mihomo.sock"
        guard FileManager.default.fileExists(atPath: unixSocket) else {
            throw ClashControlError.controllerUnavailable
        }

        let secret = parseStringValue("secret", from: generatedConfig) ?? "set-your-secret"
        return ClashControllerContext(unixSocket: unixSocket, secret: secret)
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

    nonisolated private static func runRequired(_ executable: String, arguments: [String]) throws {
        guard run(executable, arguments: arguments) != nil else {
            throw ClashControlError.commandFailed(([executable] + arguments).joined(separator: " "))
        }
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

private enum ClashControlError: LocalizedError {
    case notRunning
    case controllerUnavailable
    case missingMixedPort
    case noNetworkServices
    case configReadFailed(String)
    case configWriteFailed(String)
    case commandFailed(String)

    var errorDescription: String? {
        switch self {
        case .notRunning:
            return "Clash Verge Dev is not running."
        case .controllerUnavailable:
            return "Mihomo controller is unavailable."
        case .missingMixedPort:
            return "Mixed proxy port is unavailable."
        case .noNetworkServices:
            return "No active network services found."
        case .configReadFailed(let file):
            return "Could not read \(file)."
        case .configWriteFailed(let file):
            return "Could not write \(file)."
        case .commandFailed(let command):
            return "Command failed: \(command)"
        }
    }
}

private struct ClashConfigFiles: Sendable {
    let appSupport: URL
    let verge: URL
    let base: URL
    let generated: URL
    let profiles: URL
}

private struct ClashControllerContext: Sendable {
    let unixSocket: String
    let secret: String
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

private struct SelectedProfile: Sendable {
    let subscriptionName: String?
    let selectedGroup: String?
    let selectedNode: String?
}

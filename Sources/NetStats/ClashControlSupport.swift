import Foundation

public enum ClashMode: String, CaseIterable, Identifiable, Sendable {
    case rule
    case global
    case direct

    public var id: String { rawValue }

    public init?(apiValue: String?) {
        guard let apiValue else {
            return nil
        }
        self.init(rawValue: apiValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())
    }

    func title(language: AppLanguage) -> String {
        switch self {
        case .rule:
            return LocalizedCopy.text(.rule, language: language)
        case .global:
            return LocalizedCopy.text(.global, language: language)
        case .direct:
            return LocalizedCopy.text(.direct, language: language)
        }
    }
}

public struct ClashSubscriptionTraffic: Equatable, Sendable {
    public let uploadBytes: UInt64
    public let downloadBytes: UInt64
    public let totalBytes: UInt64?
    public let expireTimestamp: UInt64?

    public var usedBytes: UInt64 {
        uploadBytes + downloadBytes
    }
}

public struct ClashProfileSelection: Equatable, Sendable {
    public let subscriptionName: String?
    public let selectedGroup: String?
    public let selectedNode: String?
    public let traffic: ClashSubscriptionTraffic?
}

public enum ClashProfileParser {
    public static func selectedProfile(from text: String?) -> ClashProfileSelection {
        guard let text else {
            return ClashProfileSelection(subscriptionName: nil, selectedGroup: nil, selectedNode: nil, traffic: nil)
        }

        let current = parseStringValue("current", from: text)
        let blocks = splitYAMLItems(text)
        let block = blocks.first { parseStringValue("uid", from: $0) == current }
        let subscriptionName = block.flatMap { parseStringValue("name", from: $0) }
        let selections = block.map(parseSelections) ?? []
        let preferredSelection = selections.first { $0.group.uppercased() != "GLOBAL" } ?? selections.first

        return ClashProfileSelection(
            subscriptionName: subscriptionName,
            selectedGroup: preferredSelection?.group,
            selectedNode: preferredSelection?.node,
            traffic: block.flatMap(parseTraffic)
        )
    }

    private static func parseSelections(from block: String) -> [(group: String, node: String)] {
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

    private static func parseTraffic(from block: String) -> ClashSubscriptionTraffic? {
        let extra = yamlBlock(named: "extra", in: block)
        let upload = parseUInt64Value("upload", from: extra)
        let download = parseUInt64Value("download", from: extra)

        guard upload != nil || download != nil else {
            return nil
        }

        return ClashSubscriptionTraffic(
            uploadBytes: upload ?? 0,
            downloadBytes: download ?? 0,
            totalBytes: parseUInt64Value("total", from: extra),
            expireTimestamp: parseUInt64Value("expire", from: extra)
        )
    }

    private static func splitYAMLItems(_ text: String) -> [String] {
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

    private static func yamlBlock(named name: String, in text: String?) -> String? {
        guard let text else { return nil }
        let lines = text.components(separatedBy: .newlines)
        var collecting = false
        var collected: [String] = []

        for line in lines {
            if line.trimmingCharacters(in: .whitespaces) == "\(name):" {
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

    private static func parseStringValue(_ key: String, from text: String?) -> String? {
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

    private static func parseUInt64Value(_ key: String, from text: String?) -> UInt64? {
        parseStringValue(key, from: text).flatMap(UInt64.init)
    }

    private static func cleanYAMLValue(_ rawValue: String) -> String {
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
}

public enum ClashConfigTextEditor {
    public static func setTopLevelScalar(_ key: String, to value: String, in text: String) -> String {
        var lines = text.components(separatedBy: "\n")
        let prefix = "\(key):"

        for index in lines.indices {
            let line = lines[index]
            if line.hasPrefix(prefix) {
                lines[index] = "\(key): \(value)"
                return lines.joined(separator: "\n")
            }
        }

        lines.insert("\(key): \(value)", at: insertionIndexBeforeTrailingEmptyLines(in: lines))
        return lines.joined(separator: "\n")
    }

    public static func setNestedBool(_ key: String, to value: Bool, inBlock blockName: String, text: String) -> String {
        var lines = text.components(separatedBy: "\n")
        let blockPrefix = "\(blockName):"
        let keyPrefix = "\(key):"
        let renderedValue = value ? "true" : "false"

        guard let blockIndex = lines.firstIndex(where: { $0 == blockPrefix }) else {
            lines.insert(blockPrefix, at: insertionIndexBeforeTrailingEmptyLines(in: lines))
            lines.insert("  \(key): \(renderedValue)", at: insertionIndexBeforeTrailingEmptyLines(in: lines))
            return lines.joined(separator: "\n")
        }

        var scanIndex = lines.index(after: blockIndex)
        while scanIndex < lines.endIndex {
            let line = lines[scanIndex]
            if isTopLevelLine(line) {
                break
            }

            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix(keyPrefix) {
                let indent = String(line.prefix { $0 == " " || $0 == "\t" })
                lines[scanIndex] = "\(indent)\(key): \(renderedValue)"
                return lines.joined(separator: "\n")
            }

            scanIndex = lines.index(after: scanIndex)
        }

        lines.insert("  \(key): \(renderedValue)", at: scanIndex)
        return lines.joined(separator: "\n")
    }

    private static func insertionIndexBeforeTrailingEmptyLines(in lines: [String]) -> Int {
        var index = lines.endIndex
        while index > lines.startIndex {
            let previous = lines.index(before: index)
            if !lines[previous].isEmpty {
                break
            }
            index = previous
        }
        return index
    }

    private static func isTopLevelLine(_ line: String) -> Bool {
        !line.isEmpty && !line.hasPrefix(" ") && !line.hasPrefix("\t")
    }
}

public enum ClashSystemProxyParser {
    public static func isEnabled(scutilOutput: String, expectedPort: Int?) -> Bool {
        if parseScutilInt("ProxyAutoConfigEnable", from: scutilOutput) == 1 {
            return true
        }

        let enabledKeysAndPorts = [
            ("HTTPEnable", "HTTPPort"),
            ("HTTPSEnable", "HTTPSPort"),
            ("SOCKSEnable", "SOCKSPort")
        ]

        let enabledPorts = enabledKeysAndPorts.compactMap { enabledKey, portKey -> Int? in
            guard parseScutilInt(enabledKey, from: scutilOutput) == 1 else {
                return nil
            }
            return parseScutilInt(portKey, from: scutilOutput)
        }

        guard !enabledPorts.isEmpty else {
            return false
        }

        guard let expectedPort else {
            return true
        }

        return enabledPorts.contains(expectedPort)
    }

    public static func parseScutilInt(_ key: String, from text: String) -> Int? {
        let pattern = "\(key) : "
        for line in text.components(separatedBy: .newlines) {
            guard let range = line.range(of: pattern) else {
                continue
            }
            return Int(line[range.upperBound...].trimmingCharacters(in: .whitespaces))
        }
        return nil
    }
}

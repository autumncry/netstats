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

enum ClashControlAction: Equatable, Sendable {
    case systemProxy
    case tun
    case mode
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

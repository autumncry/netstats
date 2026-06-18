import Foundation

public struct ProcessMetricSample: Equatable, Identifiable, Sendable {
    public let pid: Int32
    public let name: String
    public let value: Double
    public let auxiliaryBytes: UInt64?

    public var id: String {
        "\(pid)-\(name)"
    }
}

public struct ProcessRow: Equatable, Sendable {
    public let pid: Int32
    public let name: String
    public let cpuPercent: Double
    public let memoryPercent: Double
    public let residentBytes: UInt64
}

public struct ProcessCategorySnapshot: Equatable, Sendable {
    public let items: [ProcessMetricSample]
    public let note: String?

    static let empty = ProcessCategorySnapshot(items: [], note: nil)
}

public struct ProcessSnapshot: Equatable, Sendable {
    public let cpu: ProcessCategorySnapshot
    public let gpu: ProcessCategorySnapshot
    public let memory: ProcessCategorySnapshot
    public let disk: ProcessCategorySnapshot
    public let network: ProcessCategorySnapshot
    public let updatedAt: Date

    static let empty = ProcessSnapshot(
        cpu: .empty,
        gpu: ProcessCategorySnapshot(items: [], note: "GPU process metrics require privileged sampling."),
        memory: .empty,
        disk: ProcessCategorySnapshot(items: [], note: "Per-process disk usage requires privileged tracing."),
        network: ProcessCategorySnapshot(items: [], note: "Per-process network usage requires additional local network sampling permission."),
        updatedAt: Date()
    )
}

public enum ProcessMetricParser {
    public static func processes(fromPSOutput output: String) -> [ProcessRow] {
        output
            .components(separatedBy: .newlines)
            .compactMap(parsePSLine)
    }

    public static func topCPUProcesses(from processes: [ProcessRow], limit: Int) -> [ProcessMetricSample] {
        processes
            .filter { $0.cpuPercent > 0 }
            .sorted {
                if $0.cpuPercent != $1.cpuPercent {
                    return $0.cpuPercent > $1.cpuPercent
                }
                return $0.name.localizedStandardCompare($1.name) == .orderedAscending
            }
            .prefix(limit)
            .map {
                ProcessMetricSample(
                    pid: $0.pid,
                    name: $0.name,
                    value: $0.cpuPercent,
                    auxiliaryBytes: nil
                )
            }
    }

    public static func topMemoryProcesses(from processes: [ProcessRow], limit: Int) -> [ProcessMetricSample] {
        processes
            .filter { $0.residentBytes > 0 }
            .sorted {
                if $0.residentBytes != $1.residentBytes {
                    return $0.residentBytes > $1.residentBytes
                }
                return $0.name.localizedStandardCompare($1.name) == .orderedAscending
            }
            .prefix(limit)
            .map {
                ProcessMetricSample(
                    pid: $0.pid,
                    name: $0.name,
                    value: $0.memoryPercent,
                    auxiliaryBytes: $0.residentBytes
                )
            }
    }

    private static func parsePSLine(_ line: String) -> ProcessRow? {
        let parts = line.split(maxSplits: 4, whereSeparator: { $0 == " " || $0 == "\t" })
        guard parts.count == 5,
              let pid = Int32(parts[0]),
              let cpuPercent = Double(parts[1]),
              let memoryPercent = Double(parts[2]),
              let residentKilobytes = UInt64(parts[3]) else {
            return nil
        }

        return ProcessRow(
            pid: pid,
            name: displayName(for: String(parts[4])),
            cpuPercent: cpuPercent,
            memoryPercent: memoryPercent,
            residentBytes: residentKilobytes * 1024
        )
    }

    private static func displayName(for command: String) -> String {
        let trimmed = command.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return "Unknown"
        }

        let name: String
        if trimmed.hasPrefix("/") {
            name = URL(fileURLWithPath: trimmed).lastPathComponent
        } else {
            name = trimmed
        }

        if name.count > 22 {
            return String(name.prefix(21)) + "…"
        }
        return name
    }
}

public final class ProcessMetricSampler: @unchecked Sendable {
    public init() {}

    public func sample() -> ProcessSnapshot {
        let now = Date()
        let processRows = ProcessMetricParser.processes(fromPSOutput: runPS())

        let snapshot = ProcessSnapshot(
            cpu: ProcessCategorySnapshot(
                items: ProcessMetricParser.topCPUProcesses(from: processRows, limit: 3),
                note: nil
            ),
            gpu: ProcessCategorySnapshot(
                items: [],
                note: "Per-process GPU usage is not exposed by public macOS APIs."
            ),
            memory: ProcessCategorySnapshot(
                items: ProcessMetricParser.topMemoryProcesses(from: processRows, limit: 3),
                note: nil
            ),
            disk: ProcessCategorySnapshot(
                items: [],
                note: "Per-process disk usage requires privileged tracing."
            ),
            network: ProcessCategorySnapshot(
                items: [],
                note: "Per-process network usage requires additional local network sampling permission."
            ),
            updatedAt: now
        )

        return snapshot
    }

    private func runPS() -> String {
        run("/bin/ps", arguments: ["-axo", "pid=,pcpu=,pmem=,rss=,comm="]) ?? ""
    }

    private func run(_ executable: String, arguments: [String]) -> String? {
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

        let data = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            return nil
        }

        return String(data: data, encoding: .utf8)
    }
}

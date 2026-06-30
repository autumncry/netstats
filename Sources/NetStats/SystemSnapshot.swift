import Foundation

public struct MemorySnapshot: Equatable, Sendable {
    public let usedBytes: UInt64
    public let totalBytes: UInt64
    public let availableBytes: UInt64
    public let cachedBytes: UInt64
    public let wiredBytes: UInt64
    public let compressedBytes: UInt64
    public let pressure: Double

    public init(
        usedBytes: UInt64,
        totalBytes: UInt64,
        availableBytes: UInt64,
        cachedBytes: UInt64,
        wiredBytes: UInt64,
        compressedBytes: UInt64,
        pressure: Double
    ) {
        self.usedBytes = usedBytes
        self.totalBytes = totalBytes
        self.availableBytes = availableBytes
        self.cachedBytes = cachedBytes
        self.wiredBytes = wiredBytes
        self.compressedBytes = compressedBytes
        self.pressure = pressure
    }

    var usage: Double {
        guard totalBytes > 0 else { return 0 }
        return min(max(Double(usedBytes) / Double(totalBytes), 0), 1)
    }
}

public struct IPv4AddressSnapshot: Equatable, Sendable {
    public let interfaceName: String
    public let address: String

    public init(interfaceName: String, address: String) {
        self.interfaceName = interfaceName
        self.address = address
    }

    var isPrivateAddress: Bool {
        let parts = address.split(separator: ".").compactMap { Int($0) }
        guard parts.count == 4 else {
            return false
        }

        if parts[0] == 10 {
            return true
        }
        if parts[0] == 172, (16...31).contains(parts[1]) {
            return true
        }
        if parts[0] == 192, parts[1] == 168 {
            return true
        }

        return false
    }
}

public struct NetworkSnapshot: Equatable, Sendable {
    public let downloadBytesPerSecond: Double
    public let uploadBytesPerSecond: Double
    public let sessionDownloadedBytes: UInt64
    public let sessionUploadedBytes: UInt64
    public let activeInterfaces: [String]
    public let ipv4Addresses: [IPv4AddressSnapshot]

    public init(
        downloadBytesPerSecond: Double,
        uploadBytesPerSecond: Double,
        sessionDownloadedBytes: UInt64,
        sessionUploadedBytes: UInt64,
        activeInterfaces: [String],
        ipv4Addresses: [IPv4AddressSnapshot]
    ) {
        self.downloadBytesPerSecond = downloadBytesPerSecond
        self.uploadBytesPerSecond = uploadBytesPerSecond
        self.sessionDownloadedBytes = sessionDownloadedBytes
        self.sessionUploadedBytes = sessionUploadedBytes
        self.activeInterfaces = activeInterfaces
        self.ipv4Addresses = ipv4Addresses
    }

    var primaryIPv4Address: IPv4AddressSnapshot? {
        ipv4Addresses.first
    }
}

public struct DiskSnapshot: Equatable, Sendable {
    public let usedBytes: UInt64
    public let totalBytes: UInt64
    public let freeBytes: UInt64
    public let readBytesPerSecond: Double
    public let writeBytesPerSecond: Double

    public init(
        usedBytes: UInt64,
        totalBytes: UInt64,
        freeBytes: UInt64,
        readBytesPerSecond: Double,
        writeBytesPerSecond: Double
    ) {
        self.usedBytes = usedBytes
        self.totalBytes = totalBytes
        self.freeBytes = freeBytes
        self.readBytesPerSecond = readBytesPerSecond
        self.writeBytesPerSecond = writeBytesPerSecond
    }

    var usage: Double {
        guard totalBytes > 0 else { return 0 }
        return min(max(Double(usedBytes) / Double(totalBytes), 0), 1)
    }
}

public enum PowerSourceKind: Equatable, Sendable {
    case acPower
    case battery
    case noBattery
    case unknown
}

public struct PowerSnapshot: Equatable, Sendable {
    public let source: PowerSourceKind
    public let batteryPercent: Double?
    public let isCharging: Bool

    public init(source: PowerSourceKind, batteryPercent: Double?, isCharging: Bool) {
        self.source = source
        self.batteryPercent = batteryPercent
        self.isCharging = isCharging
    }

    public static let noBattery = PowerSnapshot(source: .noBattery, batteryPercent: nil, isCharging: false)
}

public struct SystemSnapshot: Equatable, Sendable {
    public let timestamp: Date
    public let cpuUsage: Double
    public let memory: MemorySnapshot
    public let disk: DiskSnapshot
    public let network: NetworkSnapshot
    public let power: PowerSnapshot

    public init(
        timestamp: Date,
        cpuUsage: Double,
        memory: MemorySnapshot,
        disk: DiskSnapshot,
        network: NetworkSnapshot,
        power: PowerSnapshot
    ) {
        self.timestamp = timestamp
        self.cpuUsage = cpuUsage
        self.memory = memory
        self.disk = disk
        self.network = network
        self.power = power
    }

    static let empty = SystemSnapshot(
        timestamp: Date(),
        cpuUsage: 0,
        memory: MemorySnapshot(
            usedBytes: 0,
            totalBytes: ProcessInfo.processInfo.physicalMemory,
            availableBytes: ProcessInfo.processInfo.physicalMemory,
            cachedBytes: 0,
            wiredBytes: 0,
            compressedBytes: 0,
            pressure: 0
        ),
        disk: DiskSnapshot(
            usedBytes: 0,
            totalBytes: 0,
            freeBytes: 0,
            readBytesPerSecond: 0,
            writeBytesPerSecond: 0
        ),
        network: NetworkSnapshot(
            downloadBytesPerSecond: 0,
            uploadBytesPerSecond: 0,
            sessionDownloadedBytes: 0,
            sessionUploadedBytes: 0,
            activeInterfaces: [],
            ipv4Addresses: []
        ),
        power: .noBattery
    )
}

public struct MetricHistorySample: Equatable, Sendable {
    public let timestamp: Date
    public let cpuUsage: Double
    public let memoryPressure: Double
    public let diskUsage: Double
    public let networkDownloadBytesPerSecond: Double
    public let networkUploadBytesPerSecond: Double
    public let diskReadBytesPerSecond: Double
    public let diskWriteBytesPerSecond: Double
}

public struct MetricHistory: Equatable, Sendable {
    public private(set) var samples: [MetricHistorySample]
    private let maxSamples: Int

    public init(maxSamples: Int = 90) {
        self.maxSamples = max(1, maxSamples)
        samples = []
    }

    public mutating func append(_ snapshot: SystemSnapshot) {
        samples.append(MetricHistorySample(
            timestamp: snapshot.timestamp,
            cpuUsage: snapshot.cpuUsage,
            memoryPressure: snapshot.memory.pressure,
            diskUsage: snapshot.disk.usage,
            networkDownloadBytesPerSecond: snapshot.network.downloadBytesPerSecond,
            networkUploadBytesPerSecond: snapshot.network.uploadBytesPerSecond,
            diskReadBytesPerSecond: snapshot.disk.readBytesPerSecond,
            diskWriteBytesPerSecond: snapshot.disk.writeBytesPerSecond
        ))

        if samples.count > maxSamples {
            samples.removeFirst(samples.count - maxSamples)
        }
    }
}

import Foundation

struct MemorySnapshot: Equatable {
    let usedBytes: UInt64
    let totalBytes: UInt64
    let availableBytes: UInt64
    let cachedBytes: UInt64
    let wiredBytes: UInt64
    let compressedBytes: UInt64
    let pressure: Double

    var usage: Double {
        guard totalBytes > 0 else { return 0 }
        return min(max(Double(usedBytes) / Double(totalBytes), 0), 1)
    }
}

struct IPv4AddressSnapshot: Equatable {
    let interfaceName: String
    let address: String

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

struct NetworkSnapshot: Equatable {
    let downloadBytesPerSecond: Double
    let uploadBytesPerSecond: Double
    let activeInterfaces: [String]
    let ipv4Addresses: [IPv4AddressSnapshot]

    var primaryIPv4Address: IPv4AddressSnapshot? {
        ipv4Addresses.first
    }
}

struct SystemSnapshot: Equatable {
    let timestamp: Date
    let cpuUsage: Double
    let memory: MemorySnapshot
    let network: NetworkSnapshot

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
        network: NetworkSnapshot(
            downloadBytesPerSecond: 0,
            uploadBytesPerSecond: 0,
            activeInterfaces: [],
            ipv4Addresses: []
        )
    )
}

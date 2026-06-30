import Darwin
import Foundation
import IOKit
import IOKit.ps

final class SystemSampler {
    private var previousCPUInfo: [integer_t]?
    private var previousNetworkCounters: NetworkCounters?
    private var previousNetworkUptime: TimeInterval?
    private var previousDiskCounters: DiskCounters?
    private var previousDiskUptime: TimeInterval?
    private var sessionDownloadedBytes: UInt64 = 0
    private var sessionUploadedBytes: UInt64 = 0

    func sample() -> SystemSnapshot {
        SystemSnapshot(
            timestamp: Date(),
            cpuUsage: readCPUUsage(),
            memory: readMemory(),
            disk: readDisk(),
            network: readNetwork(),
            power: readPower()
        )
    }

    private func readCPUUsage() -> Double {
        var cpuInfo: processor_info_array_t?
        var cpuInfoCount = mach_msg_type_number_t(0)
        var cpuCount = natural_t(0)

        let result = host_processor_info(
            mach_host_self(),
            PROCESSOR_CPU_LOAD_INFO,
            &cpuCount,
            &cpuInfo,
            &cpuInfoCount
        )

        guard result == KERN_SUCCESS, let cpuInfo else {
            return 0
        }

        defer {
            let byteCount = vm_size_t(Int(cpuInfoCount) * MemoryLayout<integer_t>.stride)
            vm_deallocate(mach_task_self_, vm_address_t(UInt(bitPattern: cpuInfo)), byteCount)
        }

        let current = Array(UnsafeBufferPointer(start: cpuInfo, count: Int(cpuInfoCount)))
        defer {
            previousCPUInfo = current
        }

        guard let previousCPUInfo, previousCPUInfo.count == current.count else {
            return 0
        }

        let stateCount = Int(CPU_STATE_MAX)
        var totalTicks: UInt64 = 0
        var idleTicks: UInt64 = 0

        for index in stride(from: 0, to: current.count, by: stateCount) {
            let user = tickDelta(current, previousCPUInfo, index + Int(CPU_STATE_USER))
            let system = tickDelta(current, previousCPUInfo, index + Int(CPU_STATE_SYSTEM))
            let idle = tickDelta(current, previousCPUInfo, index + Int(CPU_STATE_IDLE))
            let nice = tickDelta(current, previousCPUInfo, index + Int(CPU_STATE_NICE))

            totalTicks += user + system + idle + nice
            idleTicks += idle
        }

        guard totalTicks > 0 else { return 0 }
        return min(max(1 - (Double(idleTicks) / Double(totalTicks)), 0), 1)
    }

    private func tickDelta(_ current: [integer_t], _ previous: [integer_t], _ index: Int) -> UInt64 {
        guard current.indices.contains(index), previous.indices.contains(index) else {
            return 0
        }

        let currentValue = UInt64(UInt32(bitPattern: current[index]))
        let previousValue = UInt64(UInt32(bitPattern: previous[index]))
        if currentValue >= previousValue {
            return currentValue - previousValue
        }

        return (UInt64(UInt32.max) - previousValue) + currentValue + 1
    }

    private func readMemory() -> MemorySnapshot {
        var pageSize = vm_size_t(0)
        host_page_size(mach_host_self(), &pageSize)

        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(
            MemoryLayout<vm_statistics64_data_t>.stride / MemoryLayout<integer_t>.stride
        )

        let result = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }

        let total = ProcessInfo.processInfo.physicalMemory
        guard result == KERN_SUCCESS, pageSize > 0 else {
            return MemorySnapshot(
                usedBytes: 0,
                totalBytes: total,
                availableBytes: total,
                cachedBytes: 0,
                wiredBytes: 0,
                compressedBytes: 0,
                pressure: 0
            )
        }

        let pageBytes = UInt64(pageSize)
        let wiredPages = UInt64(stats.wire_count)
        let compressedPages = UInt64(stats.compressor_page_count)
        let freePages = UInt64(stats.free_count + stats.speculative_count)
        let reclaimablePages = UInt64(stats.inactive_count + stats.purgeable_count + stats.external_page_count)
        let cachedPages = UInt64(stats.inactive_count + stats.speculative_count + stats.purgeable_count + stats.external_page_count)
        let wiredBytes = wiredPages * pageBytes
        let compressedBytes = compressedPages * pageBytes
        let cachedBytes = cachedPages * pageBytes
        let availableBytes = min(total, (freePages + reclaimablePages) * pageBytes)
        let usedBytes = total > availableBytes ? total - availableBytes : 0
        let pressure = total > 0 ? Double(usedBytes) / Double(total) : 0

        return MemorySnapshot(
            usedBytes: usedBytes,
            totalBytes: total,
            availableBytes: availableBytes,
            cachedBytes: min(cachedBytes, total),
            wiredBytes: wiredBytes,
            compressedBytes: compressedBytes,
            pressure: min(max(pressure, 0), 1)
        )
    }

    private func readNetwork() -> NetworkSnapshot {
        let current = NetworkCounters.read()
        let uptime = ProcessInfo.processInfo.systemUptime
        defer {
            previousNetworkCounters = current
            previousNetworkUptime = uptime
        }

        guard let previousNetworkCounters, let previousNetworkUptime else {
            return NetworkSnapshot(
                downloadBytesPerSecond: 0,
                uploadBytesPerSecond: 0,
                sessionDownloadedBytes: sessionDownloadedBytes,
                sessionUploadedBytes: sessionUploadedBytes,
                activeInterfaces: current.activeInterfaces,
                ipv4Addresses: current.ipv4Addresses
            )
        }

        let elapsed = max(uptime - previousNetworkUptime, 0.1)
        let receivedDelta = current.receivedBytes >= previousNetworkCounters.receivedBytes
            ? current.receivedBytes - previousNetworkCounters.receivedBytes
            : 0
        let sentDelta = current.sentBytes >= previousNetworkCounters.sentBytes
            ? current.sentBytes - previousNetworkCounters.sentBytes
            : 0

        sessionDownloadedBytes += receivedDelta
        sessionUploadedBytes += sentDelta

        return NetworkSnapshot(
            downloadBytesPerSecond: Double(receivedDelta) / elapsed,
            uploadBytesPerSecond: Double(sentDelta) / elapsed,
            sessionDownloadedBytes: sessionDownloadedBytes,
            sessionUploadedBytes: sessionUploadedBytes,
            activeInterfaces: current.activeInterfaces,
            ipv4Addresses: current.ipv4Addresses
        )
    }

    private func readDisk() -> DiskSnapshot {
        let activity = readDiskActivity()

        do {
            let values = try URL(fileURLWithPath: "/").resourceValues(forKeys: [
                .volumeTotalCapacityKey,
                .volumeAvailableCapacityForImportantUsageKey,
                .volumeAvailableCapacityKey
            ])
            let total = UInt64(max(values.volumeTotalCapacity ?? 0, 0))
            let available = UInt64(max(Int(values.volumeAvailableCapacityForImportantUsage ?? Int64(values.volumeAvailableCapacity ?? 0)), 0))
            let free = min(total, available)
            let used = total > free ? total - free : 0
            return DiskSnapshot(
                usedBytes: used,
                totalBytes: total,
                freeBytes: free,
                readBytesPerSecond: activity.readBytesPerSecond,
                writeBytesPerSecond: activity.writeBytesPerSecond
            )
        } catch {
            return DiskSnapshot(
                usedBytes: 0,
                totalBytes: 0,
                freeBytes: 0,
                readBytesPerSecond: activity.readBytesPerSecond,
                writeBytesPerSecond: activity.writeBytesPerSecond
            )
        }
    }

    private func readDiskActivity() -> (readBytesPerSecond: Double, writeBytesPerSecond: Double) {
        let current = DiskCounters.read()
        let uptime = ProcessInfo.processInfo.systemUptime
        defer {
            previousDiskCounters = current
            previousDiskUptime = uptime
        }

        guard let current, let previousDiskCounters, let previousDiskUptime else {
            return (0, 0)
        }

        let elapsed = max(uptime - previousDiskUptime, 0.1)
        let readDelta = current.readBytes >= previousDiskCounters.readBytes
            ? current.readBytes - previousDiskCounters.readBytes
            : 0
        let writeDelta = current.writeBytes >= previousDiskCounters.writeBytes
            ? current.writeBytes - previousDiskCounters.writeBytes
            : 0

        return (
            Double(readDelta) / elapsed,
            Double(writeDelta) / elapsed
        )
    }

    private func readPower() -> PowerSnapshot {
        guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue() else {
            return PowerSnapshot(source: .unknown, batteryPercent: nil, isCharging: false)
        }

        let sourceType = IOPSGetProvidingPowerSourceType(info)?.takeUnretainedValue() as String?
        let source: PowerSourceKind
        switch sourceType {
        case kIOPSACPowerValue:
            source = .acPower
        case kIOPSBatteryPowerValue:
            source = .battery
        default:
            source = .unknown
        }

        guard let list = IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [CFTypeRef], !list.isEmpty else {
            return source == .unknown ? .noBattery : PowerSnapshot(source: source, batteryPercent: nil, isCharging: false)
        }

        for item in list {
            guard let description = IOPSGetPowerSourceDescription(info, item)?
                .takeUnretainedValue() as? [String: Any] else {
                continue
            }

            let current = numberValue(description[kIOPSCurrentCapacityKey])
            let maximum = numberValue(description[kIOPSMaxCapacityKey])
            let percent: Double?
            if let current, let maximum, maximum > 0 {
                percent = min(max(current / maximum, 0), 1)
            } else {
                percent = nil
            }
            let isCharging = description[kIOPSIsChargingKey] as? Bool ?? false
            return PowerSnapshot(source: source, batteryPercent: percent, isCharging: isCharging)
        }

        return PowerSnapshot(source: source, batteryPercent: nil, isCharging: false)
    }

    private func numberValue(_ value: Any?) -> Double? {
        if let value = value as? Double {
            return value
        }
        if let value = value as? Int {
            return Double(value)
        }
        if let value = value as? NSNumber {
            return value.doubleValue
        }
        return nil
    }
}

private struct NetworkCounters {
    let receivedBytes: UInt64
    let sentBytes: UInt64
    let activeInterfaces: [String]
    let ipv4Addresses: [IPv4AddressSnapshot]

    static func read() -> NetworkCounters {
        var addressList: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&addressList) == 0, let firstAddress = addressList else {
            return NetworkCounters(
                receivedBytes: 0,
                sentBytes: 0,
                activeInterfaces: [],
                ipv4Addresses: []
            )
        }

        defer {
            freeifaddrs(addressList)
        }

        var receivedBytes: UInt64 = 0
        var sentBytes: UInt64 = 0
        var interfaces = Set<String>()
        var ipv4Addresses: [IPv4AddressSnapshot] = []
        var cursor: UnsafeMutablePointer<ifaddrs>? = firstAddress

        while let current = cursor {
            defer {
                cursor = current.pointee.ifa_next
            }

            let interface = current.pointee
            guard
                let address = interface.ifa_addr
            else {
                continue
            }

            let flags = Int32(interface.ifa_flags)
            let isUsable = (flags & IFF_UP) != 0
                && (flags & IFF_RUNNING) != 0
                && (flags & IFF_LOOPBACK) == 0

            guard isUsable else {
                continue
            }

            let name = String(cString: interface.ifa_name)

            if address.pointee.sa_family == UInt8(AF_INET),
               let ipv4Address = readIPv4Address(from: address, interfaceName: name) {
                ipv4Addresses.append(ipv4Address)
                continue
            }

            guard address.pointee.sa_family == UInt8(AF_LINK) else {
                continue
            }

            guard let data = interface.ifa_data else {
                continue
            }

            let linkData = data.assumingMemoryBound(to: if_data.self).pointee
            receivedBytes += UInt64(linkData.ifi_ibytes)
            sentBytes += UInt64(linkData.ifi_obytes)
            interfaces.insert(name)
        }

        return NetworkCounters(
            receivedBytes: receivedBytes,
            sentBytes: sentBytes,
            activeInterfaces: interfaces.sorted(),
            ipv4Addresses: sortIPv4Addresses(ipv4Addresses)
        )
    }

    private static func readIPv4Address(
        from address: UnsafeMutablePointer<sockaddr>,
        interfaceName: String
    ) -> IPv4AddressSnapshot? {
        var socketAddress = address.withMemoryRebound(to: sockaddr_in.self, capacity: 1) {
            $0.pointee
        }
        var buffer = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))

        guard inet_ntop(
            AF_INET,
            &socketAddress.sin_addr,
            &buffer,
            socklen_t(INET_ADDRSTRLEN)
        ) != nil else {
            return nil
        }

        let ipAddressBytes = buffer.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }
        let ipAddress = String(decoding: ipAddressBytes, as: UTF8.self)
        guard !ipAddress.hasPrefix("127."), !ipAddress.hasPrefix("169.254.") else {
            return nil
        }

        return IPv4AddressSnapshot(
            interfaceName: interfaceName,
            address: ipAddress
        )
    }

    private static func sortIPv4Addresses(_ addresses: [IPv4AddressSnapshot]) -> [IPv4AddressSnapshot] {
        addresses.sorted {
            let leftRank = interfaceRank($0.interfaceName)
            let rightRank = interfaceRank($1.interfaceName)
            if leftRank != rightRank {
                return leftRank < rightRank
            }

            return $0.interfaceName.localizedStandardCompare($1.interfaceName) == .orderedAscending
        }
    }

    private static func interfaceRank(_ interfaceName: String) -> Int {
        if interfaceName.hasPrefix("en") {
            return 0
        }
        if interfaceName.hasPrefix("bridge") || interfaceName.hasPrefix("awdl") || interfaceName.hasPrefix("llw") {
            return 2
        }
        if interfaceName.hasPrefix("utun") {
            return 3
        }
        return 1
    }
}

private struct DiskCounters {
    let readBytes: UInt64
    let writeBytes: UInt64

    static func read() -> DiskCounters? {
        guard let matching = IOServiceMatching("IOBlockStorageDriver") else {
            return nil
        }

        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator) == KERN_SUCCESS else {
            return nil
        }
        defer {
            IOObjectRelease(iterator)
        }

        var readBytes: UInt64 = 0
        var writeBytes: UInt64 = 0

        while true {
            let service = IOIteratorNext(iterator)
            if service == 0 {
                break
            }
            defer {
                IOObjectRelease(service)
            }

            guard let property = IORegistryEntryCreateCFProperty(
                service,
                "Statistics" as CFString,
                kCFAllocatorDefault,
                0
            )?.takeRetainedValue() as? [String: Any] else {
                continue
            }

            readBytes += uint64Value(property["Bytes (Read)"])
            writeBytes += uint64Value(property["Bytes (Write)"])
        }

        return DiskCounters(readBytes: readBytes, writeBytes: writeBytes)
    }

    private static func uint64Value(_ value: Any?) -> UInt64 {
        if let value = value as? UInt64 {
            return value
        }
        if let value = value as? Int {
            return UInt64(max(value, 0))
        }
        if let value = value as? NSNumber {
            return value.uint64Value
        }
        return 0
    }
}

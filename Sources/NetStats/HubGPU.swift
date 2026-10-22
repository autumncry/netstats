import Combine
import Foundation
import IOKit
import Metal

struct GPUReading: Equatable, Sendable {
    var name: String
    var utilization: Double?

    static func normalizedUtilization(_ percent: Double?) -> Double? {
        guard let percent, percent.isFinite, (0...100).contains(percent) else { return nil }
        return percent / 100
    }

    static func sample() -> GPUReading {
        let name = MTLCreateSystemDefaultDevice()?.name ?? "GPU"
        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching("IOAccelerator"), &iterator) == KERN_SUCCESS else {
            return GPUReading(name: name, utilization: nil)
        }
        defer { IOObjectRelease(iterator) }
        var values: [Double] = []
        while case let service = IOIteratorNext(iterator), service != 0 {
            defer { IOObjectRelease(service) }
            // Optional driver telemetry. Unsupported hardware explicitly stays unavailable.
            if let stats = IORegistryEntryCreateCFProperty(service, "PerformanceStatistics" as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() as? [String: Any],
               let number = stats["Device Utilization %"] as? NSNumber,
               let value = normalizedUtilization(number.doubleValue) {
                values.append(value)
            }
        }
        return GPUReading(name: name, utilization: values.max())
    }
}

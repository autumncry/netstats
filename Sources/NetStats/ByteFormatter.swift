import Foundation

enum ByteFormatter {
    static func memory(_ bytes: UInt64) -> String {
        formatted(bytes, suffix: "B")
    }

    static func speed(_ bytesPerSecond: Double) -> String {
        formatted(UInt64(max(0, bytesPerSecond)), suffix: "B/s")
    }

    private static func formatted(_ bytes: UInt64, suffix: String) -> String {
        let units = ["", "K", "M", "G", "T"]
        var value = Double(bytes)
        var unitIndex = 0

        while value >= 1024, unitIndex < units.count - 1 {
            value /= 1024
            unitIndex += 1
        }

        if value >= 10 || unitIndex == 0 {
            return String(format: "%.0f %@%@", value, units[unitIndex], suffix)
        }

        return String(format: "%.1f %@%@", value, units[unitIndex], suffix)
    }
}

import AppKit

enum StatusItemTooltipPolicy {
    static var usesNativeTooltips: Bool { ProcessInfo.processInfo.operatingSystemVersion.majorVersion < 27 }

    static func text(lines: [String], macOSMajorVersion: Int) -> String? {
        guard macOSMajorVersion < 27, !lines.isEmpty else { return nil }
        return lines.joined(separator: "\n")
    }

    @MainActor static func update(_ view: NSView, lines: [String], macOSMajorVersion: Int = ProcessInfo.processInfo.operatingSystemVersion.majorVersion) {
        let next = text(lines: lines, macOSMajorVersion: macOSMajorVersion)
        guard view.toolTip != next else { return }
        view.toolTip = next
    }
}

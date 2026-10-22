import CoreGraphics

package struct NotchSummaryLayout: Equatable {
    package let hardwareEnabled: Bool
    package let networkEnabled: Bool

    package var contentHeight: CGFloat {
        switch (hardwareEnabled, networkEnabled) {
        case (true, true): 220
        case (true, false), (false, true): 144
        case (false, false): 112
        }
    }

    package init(modules: Set<MonitorModule>) {
        hardwareEnabled = modules.contains(.hardware)
        networkEnabled = modules.contains(.network)
    }
}

import Foundation

enum TerminalProcessKind: CaseIterable {
    case cpu, gpu, memory, disk, network

    fileprivate var module: MonitorModule {
        switch self {
        case .cpu, .gpu, .memory: .hardware
        case .disk: .disk
        case .network: .network
        }
    }
}

enum TerminalProcessValueStyle {
    case percent, memory, speed
}

struct TerminalNetworkPresentation: Equatable {
    let ipText: String
    let locationText: String
    let canCopy: Bool
}

/// The presentation decisions used by the actual Terminal view. Keeping these
/// independent of rasterization makes visibility and privacy deterministic on
/// both local displays and headless build machines.
struct TerminalPresentation {
    private let modules: Set<MonitorModule>
    private let showProcessRanks: Bool
    private let processes: ProcessSnapshot
    let network: TerminalNetworkPresentation

    init(modules: Set<MonitorModule>, showProcessRanks: Bool, processes: ProcessSnapshot,
         publicLocation: PublicIPLocation?, lookupEnabled: Bool, isLoadingLocation: Bool,
         locationError: String?, language: AppLanguage) {
        self.modules = modules
        self.showProcessRanks = showProcessRanks
        self.processes = processes

        func tr(_ chinese: String, _ english: String) -> String {
            language == .simplifiedChinese ? chinese : english
        }
        let ipText: String
        let locationText: String
        if !lookupEnabled {
            ipText = tr("查询已关闭", "Lookup disabled")
            locationText = tr("本地模式 · 不发起公网查询", "Local mode · no public-IP request")
        } else {
            if let publicLocation {
                ipText = publicLocation.ipAddress
            } else {
                ipText = isLoadingLocation ? tr("查询中…", "Looking up…") : tr("不可用", "Unavailable")
            }
            if let publicLocation, !publicLocation.displayLocation.isEmpty {
                locationText = publicLocation.displayLocation
            } else if isLoadingLocation {
                locationText = tr("查询中…", "Looking up…")
            } else {
                locationText = locationError ?? tr("暂无位置信息", "Location unavailable")
            }
        }
        network = TerminalNetworkPresentation(ipText: ipText, locationText: locationText,
                                              canCopy: publicLocation != nil && lookupEnabled)
    }

    var visibleModules: [MonitorModule] {
        [.hardware, .disk, .network, .clash].filter { modules.contains($0) }
    }

    func processCategory(_ kind: TerminalProcessKind) -> ProcessCategorySnapshot? {
        guard showProcessRanks, modules.contains(kind.module) else { return nil }
        switch kind {
        case .cpu: return processes.cpu
        case .gpu: return processes.gpu
        case .memory: return processes.memory
        case .disk: return processes.disk
        case .network: return processes.network
        }
    }
}

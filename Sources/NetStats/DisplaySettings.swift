import Combine
import Foundation

enum AppLanguage: String, CaseIterable, Identifiable {
    case english
    case simplifiedChinese

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .english:
            return "English"
        case .simplifiedChinese:
            return "中文"
        }
    }
}

enum MonitorMetric: String, CaseIterable, Identifiable {
    case cpu
    case memory
    case download
    case upload
    case interfaces
    case wiredMemory
    case compressedMemory
    case cachedMemory

    var id: String { rawValue }

    static var configurableCases: [MonitorMetric] {
        allCases.filter { $0 != .interfaces }
    }

    func title(language: AppLanguage) -> String {
        if language == .simplifiedChinese {
            switch self {
            case .cpu:
                return "CPU"
            case .memory:
                return "内存"
            case .download:
                return "下载"
            case .upload:
                return "上传"
            case .interfaces:
                return "网络接口"
            case .wiredMemory:
                return "固定内存"
            case .compressedMemory:
                return "压缩内存"
            case .cachedMemory:
                return "缓存内存"
            }
        }

        switch self {
        case .cpu:
            return "CPU"
        case .memory:
            return "Memory"
        case .download:
            return "Download"
        case .upload:
            return "Upload"
        case .interfaces:
            return "Interfaces"
        case .wiredMemory:
            return "Wired Memory"
        case .compressedMemory:
            return "Compressed Memory"
        case .cachedMemory:
            return "Cached Memory"
        }
    }

    var systemImage: String {
        switch self {
        case .cpu:
            return "cpu"
        case .memory:
            return "memorychip"
        case .download:
            return "arrow.down.circle"
        case .upload:
            return "arrow.up.circle"
        case .interfaces:
            return "network"
        case .wiredMemory:
            return "bolt.horizontal"
        case .compressedMemory:
            return "archivebox"
        case .cachedMemory:
            return "externaldrive"
        }
    }
}

@MainActor
final class DisplaySettings: ObservableObject {
    @Published var statusBarMetrics: Set<MonitorMetric> {
        didSet {
            save(statusBarMetrics, forKey: Self.statusBarKey)
        }
    }

    @Published var hoverMetrics: Set<MonitorMetric> {
        didSet {
            save(hoverMetrics, forKey: Self.hoverKey)
        }
    }

    @Published var language: AppLanguage {
        didSet {
            defaults.set(language.rawValue, forKey: Self.languageKey)
        }
    }

    private static let statusBarKey = "display.statusBarMetrics"
    private static let hoverKey = "display.hoverMetrics"
    private static let languageKey = "display.language"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        statusBarMetrics = Self.readMetrics(
            from: defaults,
            key: Self.statusBarKey,
            fallback: [.cpu, .memory]
        )
        hoverMetrics = Self.readMetrics(
            from: defaults,
            key: Self.hoverKey,
            fallback: Set(MonitorMetric.configurableCases)
        )
        language = Self.readLanguage(from: defaults)
    }

    func binding(for metric: MonitorMetric, inStatusBar: Bool) -> Bool {
        inStatusBar ? statusBarMetrics.contains(metric) : hoverMetrics.contains(metric)
    }

    func set(_ isVisible: Bool, metric: MonitorMetric, inStatusBar: Bool) {
        if inStatusBar {
            update(&statusBarMetrics, metric: metric, isVisible: isVisible)
        } else {
            update(&hoverMetrics, metric: metric, isVisible: isVisible)
        }
    }

    private func update(_ metrics: inout Set<MonitorMetric>, metric: MonitorMetric, isVisible: Bool) {
        if isVisible {
            metrics.insert(metric)
        } else {
            metrics.remove(metric)
        }
    }

    private func save(_ metrics: Set<MonitorMetric>, forKey key: String) {
        defaults.set(metrics.map(\.rawValue).sorted(), forKey: key)
    }

    private static func readMetrics(
        from defaults: UserDefaults,
        key: String,
        fallback: Set<MonitorMetric>
    ) -> Set<MonitorMetric> {
        guard let rawValues = defaults.array(forKey: key) as? [String] else {
            return fallback
        }

        let metrics = Set(rawValues.compactMap(MonitorMetric.init(rawValue:)))
        return metrics
    }

    private static func readLanguage(from defaults: UserDefaults) -> AppLanguage {
        guard let rawValue = defaults.string(forKey: languageKey),
              let language = AppLanguage(rawValue: rawValue) else {
            return .english
        }

        return language
    }
}

enum LocalizedCopy {
    static func text(_ key: Key, language: AppLanguage) -> String {
        switch language {
        case .english:
            return english[key] ?? key.rawValue
        case .simplifiedChinese:
            return simplifiedChinese[key] ?? english[key] ?? key.rawValue
        }
    }

    enum Key: String {
        case activityMonitor
        case bar
        case cached
        case compressed
        case copied
        case copyPublicIP
        case display
        case done
        case down
        case gpu
        case hardware
        case hover
        case idle
        case interfaces
        case ipGeolocation
        case language
        case loading
        case location
        case memoryLoad
        case metric
        case mixedPortUnavailable
        case network
        case publicIP
        case publicIPLocation
        case settings
        case statusBarAndHover
        case systemMonitor
        case advanced
        case clashVerge
        case controller
        case direct
        case global
        case mode
        case node
        case off
        case on
        case proxyGroup
        case rule
        case running
        case subscription
        case systemProxy
        case tun
        case stopped
        case unavailable
        case up
        case used
    }

    private static let english: [Key: String] = [
        .activityMonitor: "Activity Monitor",
        .bar: "Bar",
        .cached: "Cached",
        .compressed: "Compressed",
        .copied: "Copied",
        .copyPublicIP: "Copy public IP",
        .display: "Display",
        .done: "Done",
        .down: "Down",
        .gpu: "GPU",
        .hardware: "Hardware",
        .hover: "Hover",
        .idle: "Idle",
        .interfaces: "Interfaces",
        .ipGeolocation: "IP geolocation",
        .language: "Language",
        .loading: "Loading...",
        .location: "Location",
        .memoryLoad: "Memory Load",
        .metric: "Metric",
        .mixedPortUnavailable: "Mixed port unavailable",
        .network: "Network",
        .publicIP: "Public IP",
        .publicIPLocation: "Public IP location",
        .settings: "Settings",
        .statusBarAndHover: "Status bar and hover",
        .systemMonitor: "NetStats",
        .advanced: "Advanced",
        .clashVerge: "Clash Verge Dev",
        .controller: "Controller",
        .direct: "Direct",
        .global: "Global",
        .mode: "Mode",
        .node: "Node",
        .off: "Off",
        .on: "On",
        .proxyGroup: "Proxy Group",
        .rule: "Rule",
        .running: "Running",
        .subscription: "Subscription",
        .systemProxy: "System Proxy",
        .tun: "TUN",
        .stopped: "Stopped",
        .unavailable: "Unavailable",
        .up: "Up",
        .used: "Used"
    ]

    private static let simplifiedChinese: [Key: String] = [
        .activityMonitor: "活动监视器",
        .bar: "状态栏",
        .cached: "缓存",
        .compressed: "压缩",
        .copied: "已复制",
        .copyPublicIP: "复制公网 IP",
        .display: "显示设置",
        .done: "完成",
        .down: "下载",
        .gpu: "GPU",
        .hardware: "硬件信息",
        .hover: "悬停",
        .idle: "空闲",
        .interfaces: "网络接口",
        .ipGeolocation: "IP 地理位置",
        .language: "语言",
        .loading: "加载中...",
        .location: "地理位置",
        .memoryLoad: "内存负载",
        .metric: "指标",
        .mixedPortUnavailable: "混合端口不可用",
        .network: "网络信息",
        .publicIP: "公网 IP",
        .publicIPLocation: "公网 IP 地理位置",
        .settings: "设置",
        .statusBarAndHover: "状态栏和悬停显示",
        .systemMonitor: "NetStats",
        .advanced: "高级信息",
        .clashVerge: "Clash Verge Dev",
        .controller: "控制接口",
        .direct: "直连",
        .global: "全局",
        .mode: "模式",
        .node: "节点",
        .off: "关闭",
        .on: "开启",
        .proxyGroup: "代理组",
        .rule: "规则",
        .running: "运行中",
        .subscription: "订阅",
        .systemProxy: "系统代理",
        .tun: "TUN",
        .stopped: "未运行",
        .unavailable: "不可用",
        .up: "上传",
        .used: "已用"
    ]
}

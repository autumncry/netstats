import Combine
import Foundation

enum HubFeature: String, CaseIterable, Identifiable, Codable, Sendable {
    case network, device, calendar, weather, clipboard, shelf
    var id: String { rawValue }
    var cardHeight: CGFloat {
        switch self {
        case .network, .weather: 208
        case .device, .shelf: 232
        case .calendar, .clipboard: 248
        }
    }
    var symbol: String {
        switch self {
        case .network: "network"
        case .device: "desktopcomputer"
        case .calendar: "calendar"
        case .weather: "cloud.sun"
        case .clipboard: "doc.on.clipboard"
        case .shelf: "tray"
        }
    }
    func title(_ language: AppLanguage) -> String {
        if language == .simplifiedChinese {
            switch self {
            case .network: return "网络"
            case .device: return "设备"
            case .calendar: return "日历"
            case .weather: return "天气"
            case .clipboard: return "剪切板"
            case .shelf: return "暂存架"
            }
        }
        switch self {
        case .network: return "Network"
        case .device: return "Device"
        case .calendar: return "Calendar"
        case .weather: return "Weather"
        case .clipboard: return "Clipboard"
        case .shelf: return "Shelf"
        }
    }
    static func defaultSelection(in enabled: Set<HubFeature>) -> HubFeature? {
        allCases.first { enabled.contains($0) }
    }
}

@MainActor
final class HubSettings: ObservableObject {
    @Published var enabledFeatures: Set<HubFeature> {
        didSet { defaults.set(enabledFeatures.map(\.rawValue).sorted(), forKey: Self.key) }
    }
    private let defaults: UserDefaults
    private static let key = "hub.enabledFeatures"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let stored = defaults.stringArray(forKey: Self.key) {
            enabledFeatures = Set(stored.compactMap(HubFeature.init(rawValue:)))
        } else {
            enabledFeatures = [.network, .device, .shelf]
        }
    }
    func set(_ enabled: Bool, feature: HubFeature) {
        if enabled { enabledFeatures.insert(feature) }
        else { enabledFeatures.remove(feature) }
    }
}

import Combine
import Foundation

@MainActor
final class HubStore: ObservableObject {
    let metricsStore: MetricsStore
    let settings: HubSettings
    let clipboard: ClipboardStore
    let shelf: ShelfStore
    let calendar: CalendarStore
    let weather: WeatherStore
    @Published private(set) var selected: HubFeature?
    private(set) var pageTransitionDirection: HubPageDirection?
    private(set) var selectionRevision: UInt64 = 0
    @Published private(set) var gpu = GPUReading(name: "GPU", utilization: nil)
    private var subscriptions = Set<AnyCancellable>()
    private var started = false
    private var gpuSampling = false
    var currentHeight: CGFloat { selected?.cardHeight ?? 208 }

    init(metricsStore: MetricsStore, displaySettings: DisplaySettings,
         settings: HubSettings = HubSettings(), defaults: UserDefaults = .standard,
         storageDirectory: URL? = nil) {
        self.metricsStore = metricsStore
        self.settings = settings
        clipboard = ClipboardStore(defaults: defaults, directory: storageDirectory)
        shelf = ShelfStore(defaults: defaults)
        calendar = CalendarStore(defaults: defaults)
        weather = WeatherStore(defaults: defaults, cacheURL: storageDirectory?.appendingPathComponent("weather-cache.json"))
        selected = HubFeature.defaultSelection(in: settings.enabledFeatures)
        settings.$enabledFeatures
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.featuresChanged() }
            .store(in: &subscriptions)
        metricsStore.$snapshot.dropFirst().receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.sampleGPU() }
            .store(in: &subscriptions)
    }
    func start() {
        guard !started else { return }
        started = true
        featuresChanged()
        clipboard.start()
        calendar.start()
        weather.start()
        sampleGPU()
    }
    func stop() {
        started = false
        clipboard.stop()
        calendar.stop()
        weather.stop()
    }
    func selectDefault() {
        pageTransitionDirection = nil
        updateSelection(HubFeature.defaultSelection(in: settings.enabledFeatures), animated: false)
    }
    func select(feature: HubFeature, animated: Bool = false) {
        guard settings.enabledFeatures.contains(feature) else { return }
        updateSelection(feature, animated: animated)
    }
    @discardableResult
    func selectAdjacent(_ direction: HubPageDirection) -> Bool {
        let enabled = HubFeature.allCases.filter { settings.enabledFeatures.contains($0) }
        guard let selected, let index = enabled.firstIndex(of: selected) else { return false }
        let next = index + (direction == .next ? 1 : -1)
        guard enabled.indices.contains(next) else { return false }
        updateSelection(enabled[next], animated: true)
        return true
    }

    private func updateSelection(_ feature: HubFeature?, animated: Bool) {
        guard feature != selected else { return }
        if animated, let old = selected, let feature,
           let oldIndex = HubFeature.allCases.firstIndex(of: old),
           let newIndex = HubFeature.allCases.firstIndex(of: feature) {
            pageTransitionDirection = newIndex > oldIndex ? .next : .previous
        } else {
            pageTransitionDirection = nil
        }
        // Set transition metadata before selected publishes its change. Old
        // pages retain this revision, so their delayed cleanup cannot affect
        // a newly selected page, including a quick A -> B -> A reversal.
        selectionRevision &+= 1
        selected = feature
    }
    private func featuresChanged() {
        if let selected, !settings.enabledFeatures.contains(selected) { selectDefault() }
        else if selected == nil { selectDefault() }
        guard started else { return }
        clipboard.setEnabled(settings.enabledFeatures.contains(.clipboard))
        calendar.setEnabled(settings.enabledFeatures.contains(.calendar))
        weather.setEnabled(settings.enabledFeatures.contains(.weather))
    }
    private func sampleGPU() {
        guard started, settings.enabledFeatures.contains(.device), !gpuSampling else { return }
        gpuSampling = true
        DispatchQueue.global(qos: .utility).async { [weak self] in
            let reading = GPUReading.sample()
            Task { @MainActor in
                self?.gpu = reading
                self?.gpuSampling = false
            }
        }
    }
}

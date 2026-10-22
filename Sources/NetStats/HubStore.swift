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
    func selectDefault() { selected = HubFeature.defaultSelection(in: settings.enabledFeatures) }
    func select(feature: HubFeature) {
        guard settings.enabledFeatures.contains(feature) else { return }
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

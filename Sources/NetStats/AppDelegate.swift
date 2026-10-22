import AppKit

@MainActor
public final class AppDelegate: NSObject, NSApplicationDelegate {
    private var metricsStore: MetricsStore?
    private var displaySettings: DisplaySettings?
    private var ipGeolocationStore: IPGeolocationStore?
    private var clashStatusStore: ClashStatusStore?
    private var hubStore: HubStore?
    private var presentationCoordinator: MonitorPresentationCoordinator?

    public override init() {
        super.init()
    }

    public func applicationDidFinishLaunching(_ notification: Notification) {
        let metricsStore = MetricsStore()
        let displaySettings = DisplaySettings()
        let ipGeolocationStore = IPGeolocationStore()
        let clashStatusStore = ClashStatusStore()
        self.metricsStore = metricsStore
        self.displaySettings = displaySettings
        self.ipGeolocationStore = ipGeolocationStore
        self.clashStatusStore = clashStatusStore
        let hubStore = HubStore(metricsStore: metricsStore, displaySettings: displaySettings)
        self.hubStore = hubStore
        presentationCoordinator = MonitorPresentationCoordinator(
            metricsStore: metricsStore,
            hubStore: hubStore,
            displaySettings: displaySettings,
            ipGeolocationStore: ipGeolocationStore,
            clashStatusStore: clashStatusStore
        )
        metricsStore.start()
        hubStore.start()
        ipGeolocationStore.start(lookupEnabled: displaySettings.publicIPLookupEnabled)
        clashStatusStore.start()
    }

    public func applicationWillTerminate(_ notification: Notification) {
        metricsStore?.stop()
        ipGeolocationStore?.stop()
        clashStatusStore?.stop()
        hubStore?.stop()
        presentationCoordinator?.stop()
    }
}

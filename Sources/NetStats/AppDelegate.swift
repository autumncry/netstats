import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var metricsStore: MetricsStore?
    private var displaySettings: DisplaySettings?
    private var ipGeolocationStore: IPGeolocationStore?
    private var clashStatusStore: ClashStatusStore?
    private var statusController: StatusBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let metricsStore = MetricsStore()
        let displaySettings = DisplaySettings()
        let ipGeolocationStore = IPGeolocationStore()
        let clashStatusStore = ClashStatusStore()
        self.metricsStore = metricsStore
        self.displaySettings = displaySettings
        self.ipGeolocationStore = ipGeolocationStore
        self.clashStatusStore = clashStatusStore
        statusController = StatusBarController(
            metricsStore: metricsStore,
            displaySettings: displaySettings,
            ipGeolocationStore: ipGeolocationStore,
            clashStatusStore: clashStatusStore
        )
        metricsStore.start()
        ipGeolocationStore.start()
        clashStatusStore.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        metricsStore?.stop()
        ipGeolocationStore?.stop()
        clashStatusStore?.stop()
        statusController?.stop()
    }
}

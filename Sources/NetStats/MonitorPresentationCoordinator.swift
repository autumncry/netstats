import AppKit

/// Routes both entrances through one owner so a detail panel and a notch card
/// cannot compete for the pointer or remain visible together.
@MainActor
final class MonitorPresentationCoordinator {
    private let statusBar: StatusBarController
    private let notch: NotchPanelController

    init(
        metricsStore: MetricsStore,
        hubStore: HubStore,
        displaySettings: DisplaySettings,
        ipGeolocationStore: IPGeolocationStore,
        clashStatusStore: ClashStatusStore
    ) {
        statusBar = StatusBarController(
            metricsStore: metricsStore,
            hubStore: hubStore,
            displaySettings: displaySettings,
            ipGeolocationStore: ipGeolocationStore,
            clashStatusStore: clashStatusStore
        )
        notch = NotchPanelController(hubStore: hubStore, displaySettings: displaySettings)
        statusBar.onVisibilityChange = { [weak self] visible in
            self?.notch.setDetailsVisible(visible)
        }
        notch.openDetails = { [weak self] in self?.statusBar.show(page: .monitor) }
        notch.openLegacySettings = { [weak self] in self?.statusBar.show(page: .settings) }
        notch.start()
    }

    func stop() {
        notch.stop()
        statusBar.stop()
    }
}

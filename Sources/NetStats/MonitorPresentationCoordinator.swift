import AppKit

/// Coordinates the monitoring entrances and the independent Settings window.
@MainActor
final class MonitorPresentationCoordinator {
    private let statusBar: StatusBarController
    private let notch: NotchPanelController
    private let settingsWindow: SettingsWindowController

    var isHoverSuppressed: Bool { notch.isHoverSuppressed }
    var isSettingsPresented: Bool { settingsWindow.isPresented }

    init(
        metricsStore: MetricsStore,
        hubStore: HubStore,
        displaySettings: DisplaySettings,
        ipGeolocationStore: IPGeolocationStore,
        clashStatusStore: ClashStatusStore
    ) {
        statusBar = StatusBarController(metricsStore: metricsStore, hubStore: hubStore,
                                        displaySettings: displaySettings,
                                        ipGeolocationStore: ipGeolocationStore, clashStatusStore: clashStatusStore)
        notch = NotchPanelController(hubStore: hubStore, displaySettings: displaySettings)
        settingsWindow = SettingsWindowController(hubStore: hubStore, displaySettings: displaySettings, metricsStore: metricsStore)
        statusBar.onVisibilityChange = { [weak self] visible in
            self?.notch.setDetailsVisible(visible)
        }
        statusBar.openSettings = { [weak self] in self?.showSettings() }
        settingsWindow.onRequestShowSettings = { [weak self] in self?.showSettings() }
        notch.openDetails = { [weak self] in self?.showDetails() }
        notch.openSettings = { [weak self] in self?.showSettings() }
        notch.start()
    }

    func showDetails() { statusBar.showDetails() }

    func showSettings(activate: Bool = true) {
        // Settings is an independent window, not a competing monitoring panel.
        // Dismiss once and require a fresh pointer entry, without disabling
        // hover for the entire lifetime of that window.
        notch.dismiss()
        statusBar.dismiss()
        settingsWindow.showSettings(activate: activate)
    }
    func stop() {
        notch.stop()
        statusBar.stop()
        settingsWindow.stop()
    }
}

import AppKit
import Combine
import SwiftUI

@MainActor
final class StatusBarController: NSObject {
    private let metricsStore: MetricsStore
    private let hubStore: HubStore
    private let displaySettings: DisplaySettings
    private let ipGeolocationStore: IPGeolocationStore
    private let clashStatusStore: ClashStatusStore
    private let statusItem: NSStatusItem
    private lazy var panel = makePanel()
    private var hubPanel: HubPanel?
    private let hubNavigation = HubPanelNavigation()
    private var environmentObservers: [(NotificationCenter, NSObjectProtocol)] = []
    private var trackingMenus = Set<ObjectIdentifier>()
    private var cancellables = Set<AnyCancellable>()
    private var eventMonitors: [Any] = []
    private let navigation = MonitorPanelNavigation()
    var onVisibilityChange: ((Bool) -> Void)?

    private var currentPanelSize: NSSize {
        displaySettings.panelStyle.panelSize
    }

    init(
        metricsStore: MetricsStore,
        hubStore: HubStore,
        displaySettings: DisplaySettings,
        ipGeolocationStore: IPGeolocationStore,
        clashStatusStore: ClashStatusStore
    ) {
        self.metricsStore = metricsStore
        self.hubStore = hubStore
        self.displaySettings = displaySettings
        self.ipGeolocationStore = ipGeolocationStore
        self.clashStatusStore = clashStatusStore
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()
        configureStatusItem()
        configurePanel()
        bindMetrics()
        observeEnvironment()
    }

    func stop() {
        for eventMonitor in eventMonitors {
            NSEvent.removeMonitor(eventMonitor)
        }
        eventMonitors.removeAll()
        cancellables.removeAll()
        for (center, token) in environmentObservers { center.removeObserver(token) }
        environmentObservers.removeAll()
        closeHubPanel()
        hubPanel?.stopPopoverTracking()
        closePanel()
    }

    func show(page: MonitorPanelPage) {
        guard let button = statusItem.button else { return }
        closeHubPanel()
        navigation.page = page
        showPanel(relativeTo: button)
    }

    private func configureStatusItem() {
        guard let button = statusItem.button else {
            return
        }

        button.image = NSImage(systemSymbolName: "cpu", accessibilityDescription: "NetStats")
        button.image?.isTemplate = true
        button.imagePosition = .imageLeading
        button.font = NSFont.monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        button.target = self
        button.action = #selector(togglePanel(_:))
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }

    private func makePanel() -> NSPanel {
        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: currentPanelSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        panel.backgroundColor = .clear
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        panel.contentViewController = NSHostingController(
            rootView: MonitorPanelRootView(
                metricsStore: metricsStore,
                displaySettings: displaySettings,
                ipGeolocationStore: ipGeolocationStore,
                clashStatusStore: clashStatusStore,
                navigation: navigation
            )
        )
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.isMovable = false
        panel.isOpaque = false
        panel.isReleasedWhenClosed = false
        panel.level = .popUpMenu

        return panel
    }

    private func configurePanel() {
        if let globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown], handler: { [weak self] _ in
            MainActor.assumeIsolated {
                self?.closeVisiblePanelIfNeeded(forScreenPoint: NSEvent.mouseLocation)
            }
        }) { eventMonitors.append(globalMonitor) }

        if let localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .keyDown], handler: { [weak self] event in
            var consumed = false
            MainActor.assumeIsolated {
                guard let self else { return }
                if event.type == .keyDown, event.keyCode == 53 {
                    if let hubPanel = self.hubPanel, hubPanel.isVisible,
                       hubPanel.owns(event.window) || hubPanel.isKeyWindow {
                        if !hubPanel.dismissOwnedChild() { self.closeHubPanel() }
                        consumed = true
                        return
                    }
                    if self.panel.isVisible, event.window === self.panel {
                        self.closePanel()
                        consumed = true
                        return
                    }
                } else if event.type != .keyDown {
                    self.handleLocalMouseEvent(event)
                }
            }
            return consumed ? nil : event
        }) { eventMonitors.append(localMonitor) }
    }

    private func bindMetrics() {
        metricsStore.$snapshot
            .receive(on: RunLoop.main)
            .sink { [weak self] snapshot in
                self?.updateStatusItem(snapshot)
            }
            .store(in: &cancellables)

        displaySettings.$statusBarMetrics
            .combineLatest(displaySettings.$hoverMetrics)
            .combineLatest(displaySettings.$language)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard let self else { return }
                self.updateStatusItem(self.metricsStore.snapshot)
            }
            .store(in: &cancellables)

        displaySettings.$panelStyle
            .dropFirst()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.resizePanelForCurrentStyle()
            }
            .store(in: &cancellables)

        hubStore.$selected
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.resizeHubPanel() }
            .store(in: &cancellables)
        hubNavigation.$showingSettings
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.resizeHubPanel() }
            .store(in: &cancellables)
        hubStore.settings.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.resizeHubPanel() }
            .store(in: &cancellables)

        displaySettings.$publicIPLookupEnabled
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] isEnabled in
                self?.ipGeolocationStore.setLookupEnabled(isEnabled)
            }
            .store(in: &cancellables)
    }

    private func updateStatusItem(_ snapshot: SystemSnapshot) {
        guard let button = statusItem.button else {
            return
        }

        let title = displaySettings.statusBarMetrics
            .sortedForDisplay()
            .compactMap { statusBarText(for: $0, snapshot: snapshot) }
            .joined(separator: "  ")
        button.title = title.isEmpty ? "" : " \(title)"
        button.toolTip = tooltipText(for: snapshot)
    }

    private func tooltipText(for snapshot: SystemSnapshot) -> String {
        let language = displaySettings.language
        let lines = displaySettings.hoverMetrics
            .sortedForDisplay()
            .flatMap { tooltipLines(for: $0, snapshot: snapshot, language: language) }

        return lines.isEmpty ? LocalizedCopy.text(.systemMonitor, language: language) : lines.joined(separator: "\n")
    }

    private func statusBarText(for metric: MonitorMetric, snapshot: SystemSnapshot) -> String? {
        let language = displaySettings.language
        switch metric {
        case .cpu:
            return "CPU \(percent(snapshot.cpuUsage))"
        case .memory:
            return language == .simplifiedChinese
                ? "内存 \(percent(snapshot.memory.pressure))"
                : "MEM \(percent(snapshot.memory.pressure))"
        case .download:
            return "↓ \(ByteFormatter.speed(snapshot.network.downloadBytesPerSecond))"
        case .upload:
            return "↑ \(ByteFormatter.speed(snapshot.network.uploadBytesPerSecond))"
        case .interfaces:
            return snapshot.network.activeInterfaces.isEmpty
                ? "NET idle"
                : "NET \(snapshot.network.activeInterfaces.count)"
        case .wiredMemory:
            return "WIRED \(ByteFormatter.memory(snapshot.memory.wiredBytes))"
        case .compressedMemory:
            return "COMP \(ByteFormatter.memory(snapshot.memory.compressedBytes))"
        case .cachedMemory:
            return "CACHE \(ByteFormatter.memory(snapshot.memory.cachedBytes))"
        }
    }

    private func tooltipLines(
        for metric: MonitorMetric,
        snapshot: SystemSnapshot,
        language: AppLanguage
    ) -> [String] {
        switch metric {
        case .cpu:
            return ["CPU: \(percent(snapshot.cpuUsage))"]
        case .memory:
            return [
                "\(LocalizedCopy.text(.memoryLoad, language: language)): \(percent(snapshot.memory.pressure))",
                "\(LocalizedCopy.text(.used, language: language)): \(ByteFormatter.memory(snapshot.memory.usedBytes)) / \(ByteFormatter.memory(snapshot.memory.totalBytes))"
            ]
        case .download:
            return ["\(LocalizedCopy.text(.down, language: language)): \(ByteFormatter.speed(snapshot.network.downloadBytesPerSecond))"]
        case .upload:
            return ["\(LocalizedCopy.text(.up, language: language)): \(ByteFormatter.speed(snapshot.network.uploadBytesPerSecond))"]
        case .interfaces:
            let interfaces = snapshot.network.activeInterfaces.isEmpty
                ? LocalizedCopy.text(.idle, language: language)
                : snapshot.network.activeInterfaces.joined(separator: ", ")
            return ["\(LocalizedCopy.text(.interfaces, language: language)): \(interfaces)"]
        case .wiredMemory:
            return ["Wired Memory: \(ByteFormatter.memory(snapshot.memory.wiredBytes))"]
        case .compressedMemory:
            return ["\(LocalizedCopy.text(.compressed, language: language)): \(ByteFormatter.memory(snapshot.memory.compressedBytes))"]
        case .cachedMemory:
            return ["\(LocalizedCopy.text(.cached, language: language)): \(ByteFormatter.memory(snapshot.memory.cachedBytes))"]
        }
    }

    private func percent(_ value: Double) -> String {
        "\(Int(round(value * 100)))%"
    }

    @objc private func togglePanel(_ sender: NSStatusBarButton) {
        if panel.isVisible || hubPanel?.isVisible == true {
            closeHubPanel()
            closePanel()
        } else {
            showHubPanel(relativeTo: sender)
        }
    }

    private func showHubPanel(relativeTo button: NSStatusBarButton) {
        closePanel()
        hubStore.selectDefault()
        hubNavigation.showingSettings = false
        if hubPanel == nil { hubPanel = makeHubPanel() }
        onVisibilityChange?(true)
        resizeHubPanel()
        hubPanel?.orderFrontRegardless()
    }

    private func makeHubPanel() -> HubPanel {
        let result = HubPanel()
        result.trackPopoverLifecycle()
        let root = HubPanelRootView(
            store: hubStore, displaySettings: displaySettings, navigation: hubNavigation,
            requestKeyboard: { [weak self] in self?.hubPanel?.requestKeyboard() },
            holdInteraction: { _ in },
            openDetails: { [weak self] in self?.show(page: .monitor) },
            openLegacySettings: { [weak self] in self?.show(page: .settings) }
        )
        let hosting = NSHostingView(rootView: root)
        let destination = NotchDropDestinationView(frame: .zero)
        destination.acceptsFiles = { [weak self] in self?.hubStore.settings.enabledFeatures.contains(.shelf) == true }
        destination.onEnter = { [weak self] in
            self?.hubStore.select(feature: .shelf)
            self?.hubNavigation.showingSettings = false
            self?.resizeHubPanel()
        }
        destination.onDrop = { [weak self] urls in
            self?.hubStore.shelf.add(urls: urls)
            self?.hubStore.select(feature: .shelf)
            self?.hubNavigation.showingSettings = false
            self?.resizeHubPanel()
        }
        destination.embed(hosting)
        result.contentView = destination
        return result
    }

    private func resizeHubPanel() {
        guard let hubPanel, let button = statusItem.button else { return }
        let height: CGFloat = hubNavigation.showingSettings ? 520 : hubStore.currentHeight
        let size = NSSize(width: 360, height: height)
        hubPanel.setFrame(NSRect(origin: panelOrigin(relativeTo: button, size: size), size: size), display: true)
    }

    private func closeHubPanel() {
        guard let hubPanel, hubPanel.isVisible else { return }
        hubPanel.dismissOwnedChildren()
        hubPanel.endInteraction()
        hubPanel.orderOut(nil)
        trackingMenus.removeAll()
        onVisibilityChange?(panel.isVisible)
    }

    private func showPanel(relativeTo button: NSStatusBarButton) {
        onVisibilityChange?(true)
        let size = currentPanelSize
        let frame = NSRect(origin: panelOrigin(relativeTo: button, size: size), size: size)
        panel.setFrame(frame, display: true)
        panel.orderFrontRegardless()
    }

    private func resizePanelForCurrentStyle() {
        guard panel.isVisible, let button = statusItem.button else {
            return
        }

        let size = currentPanelSize
        let frame = NSRect(origin: panelOrigin(relativeTo: button, size: size), size: size)
        panel.setFrame(frame, display: true)
    }

    private func closePanel() {
        guard panel.isVisible else {
            return
        }

        panel.orderOut(nil)
        onVisibilityChange?(hubPanel?.isVisible == true)
    }

    private func closeVisiblePanelIfNeeded(forScreenPoint point: NSPoint) {
        if let hubPanel, hubPanel.isVisible {
            if hubPanel.containsOwnedPoint(point) || !trackingMenus.isEmpty { return }
            if let button = statusItem.button, screenFrame(for: button).contains(point) { return }
            closeHubPanel()
        }
        guard panel.isVisible else { return }
        if panel.frame.contains(point) { return }
        if let button = statusItem.button, screenFrame(for: button).contains(point) { return }
        closePanel()
    }

    private func panelOrigin(relativeTo button: NSStatusBarButton, size: NSSize) -> NSPoint {
        let buttonFrame = screenFrame(for: button)
        let screen = button.window?.screen ?? NSScreen.main
        let visibleFrame = screen?.visibleFrame ?? buttonFrame
        let margin: CGFloat = 8

        var x = buttonFrame.midX - size.width / 2
        var y = buttonFrame.minY - size.height - margin

        x = min(max(x, visibleFrame.minX + margin), visibleFrame.maxX - size.width - margin)
        y = min(max(y, visibleFrame.minY + margin), visibleFrame.maxY - size.height - margin)

        return NSPoint(x: x, y: y)
    }

    private func screenFrame(for button: NSStatusBarButton) -> NSRect {
        guard let window = button.window else {
            return NSRect(origin: .zero, size: currentPanelSize)
        }

        let frameInWindow = button.convert(button.bounds, to: nil)
        return window.convertToScreen(frameInWindow)
    }

    private func handleLocalMouseEvent(_ event: NSEvent) {
        if event.window === statusItem.button?.window { return }
        if let hubPanel, hubPanel.isVisible {
            if hubPanel.owns(event.window) || hubPanel.containsOwnedPoint(NSEvent.mouseLocation) || !trackingMenus.isEmpty { return }
            closeHubPanel()
        }
        if panel.isVisible, event.window !== panel { closePanel() }
    }

    private func observeEnvironment() {
        let workspace = NSWorkspace.shared.notificationCenter
        let entries: [(NotificationCenter, Notification.Name)] = [
            (.default, NSApplication.didChangeScreenParametersNotification),
            (workspace, NSWorkspace.willSleepNotification),
            (workspace, NSWorkspace.screensDidSleepNotification),
            (workspace, NSWorkspace.sessionDidResignActiveNotification),
            (workspace, NSWorkspace.activeSpaceDidChangeNotification),
            (workspace, NSWorkspace.didActivateApplicationNotification)
        ]
        for (center, name) in entries {
            let token = center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.closeHubPanel()
                    self?.closePanel()
                }
            }
            environmentObservers.append((center, token))
        }
        let begin = NotificationCenter.default.addObserver(forName: NSMenu.didBeginTrackingNotification, object: nil, queue: .main) { [weak self] note in
            guard let menu = note.object as? NSMenu else { return }
            let menuID = ObjectIdentifier(menu)
            MainActor.assumeIsolated {
                guard let self,
                      self.hubPanel?.isVisible == true,
                      self.hubPanel?.containsOwnedPoint(NSEvent.mouseLocation) == true else { return }
                self.trackingMenus.insert(menuID)
            }
        }
        let end = NotificationCenter.default.addObserver(forName: NSMenu.didEndTrackingNotification, object: nil, queue: .main) { [weak self] note in
            guard let menu = note.object as? NSMenu else { return }
            let menuID = ObjectIdentifier(menu)
            MainActor.assumeIsolated {
                _ = self?.trackingMenus.remove(menuID)
            }
        }
        environmentObservers.append((.default, begin))
        environmentObservers.append((.default, end))
    }

}

private extension Set where Element == MonitorMetric {
    func sortedForDisplay() -> [MonitorMetric] {
        MonitorMetric.configurableCases.filter { contains($0) }
    }
}

private struct MonitorPanelRootView: View {
    @ObservedObject var metricsStore: MetricsStore
    @ObservedObject var displaySettings: DisplaySettings
    @ObservedObject var ipGeolocationStore: IPGeolocationStore
    @ObservedObject var clashStatusStore: ClashStatusStore
    @ObservedObject var navigation: MonitorPanelNavigation

    var body: some View {
        MonitorPopoverView(
            metricsStore: metricsStore,
            displaySettings: displaySettings,
            ipGeolocationStore: ipGeolocationStore,
            clashStatusStore: clashStatusStore,
            page: $navigation.page
        )
        .frame(
            width: displaySettings.panelStyle.panelSize.width,
            height: displaySettings.panelStyle.panelSize.height
        )
    }
}

@MainActor
private final class MonitorPanelNavigation: ObservableObject {
    @Published var page = MonitorPanelPage.monitor
}

private extension PanelStyle {
    var panelSize: NSSize {
        switch self {
        case .native:
            return NSSize(width: 440, height: 760)
        case .terminal:
            return NSSize(width: 760, height: 700)
        }
    }
}

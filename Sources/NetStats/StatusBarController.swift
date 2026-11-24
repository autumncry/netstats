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
    private var environmentObservers: [(NotificationCenter, NSObjectProtocol)] = []
    private var trackingMenus = Set<ObjectIdentifier>()
    private var hubInteractionHeld = false
    private var hubFileDragging = false
    private var contextMenu: StatusItemContextMenu?
    private var sessionBridge: StatusItemSessionBridge?
    private var panelBelongsToSession = false
    private var panelAnchor: CGRect?
    private var menuAnchor: CGRect?
    private var isPresentingContextMenu = false
    private var cancellables = Set<AnyCancellable>()
    private var eventMonitors: [Any] = []
    var onVisibilityChange: ((Bool) -> Void)?
    var openSettings: (() -> Void)?

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
        sessionBridge?.stop()
        sessionBridge = nil
        contextMenu?.menu.cancelTracking()
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
        statusItem.button?.target = nil
        NSStatusBar.system.removeStatusItem(statusItem)
    }

    func showDetails() {
        guard let button = statusItem.button else { return }
        if hubPanel?.isVisible != true { panelAnchor = menuAnchor ?? resolveAnchor(for: button) }
        guard let frame = panelFrame(size: currentPanelSize) else { dismiss(); return }
        closeHubPanel()
        showPanel(frame: frame)
    }

    func dismiss() {
        panelBelongsToSession = false
        sessionBridge?.cancel()
        closeHubPanel()
        closePanel()
    }

    private func configureStatusItem() {
        guard let button = statusItem.button else {
            return
        }

        button.image = NSImage(systemSymbolName: "cpu", accessibilityDescription: nil)
        button.image?.isTemplate = true
        button.imagePosition = .imageLeading
        button.font = NSFont.monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        button.setAccessibilityLabel("NetStats")
        contextMenu = StatusItemContextMenu(
            language: { [weak displaySettings] in displaySettings?.language ?? .english },
            overviewLines: { [weak self] in
                guard let self, !StatusItemTooltipPolicy.usesNativeTooltips else { return [] }
                return self.summaryLines(for: self.metricsStore.snapshot)
            },
            onTrackingChanged: { [weak self] tracking in
                guard let self else { return }
                self.isPresentingContextMenu = tracking
                self.onVisibilityChange?(tracking || self.panel.isVisible || self.hubPanel?.isVisible == true)
            },
            showCard: { [weak self, weak button] in
                guard let self, let button else { return }
                self.showHubPanel(relativeTo: button)
            },
            showDetails: { [weak self] in self?.showDetails() },
            settings: { [weak self] in self?.openSettings?() },
            quit: { NSApp.terminate(nil) }
        )

        sessionBridge = StatusItemSessionBridge(statusItem: statusItem, onBegin: { [weak self] in
            guard let self else { return }
            guard let button = self.statusItem.button, !self.isPresentingContextMenu else {
                self.sessionBridge?.cancel()
                return
            }
            self.panelBelongsToSession = true
            self.showHubPanel(relativeTo: button)
        }, onEnd: { [weak self] _ in
            guard let self, self.panelBelongsToSession else { return }
            self.panelBelongsToSession = false
            self.closeHubPanel()
            self.closePanel()
        })
        // A primary menu would take over the icon's normal left-click behavior.
        // New AppKit versions open the card through the expanded-interface delegate.
        guard sessionBridge == nil else { return }
        button.target = self
        button.action = #selector(handleStatusItemClick(_:))
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
                openSettings: { [weak self] in self?.openSettings?() }
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
                if self.handleSessionButtonEvent(event) {
                    consumed = true
                    return
                }
                if event.type == .keyDown, event.keyCode == 53 {
                    if let hubPanel = self.hubPanel, hubPanel.isVisible,
                       hubPanel.owns(event.window) || hubPanel.isKeyWindow {
                        if !hubPanel.dismissOwnedChild() { self.dismiss() }
                        consumed = true
                        return
                    }
                    if self.panel.isVisible, event.window === self.panel {
                        self.dismiss()
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
            .sink { [weak self] _ in
                guard let self else { return }
                self.resizeHubPanel(animated: self.hubStore.pageTransitionDirection != nil)
            }
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
        let nextTitle = title.isEmpty ? "" : " \(title)"
        if button.title != nextTitle { button.title = nextTitle }
        let lines = StatusItemTooltipPolicy.usesNativeTooltips ? summaryLines(for: snapshot) : []
        StatusItemTooltipPolicy.update(button, lines: lines)
    }

    private func summaryLines(for snapshot: SystemSnapshot) -> [String] {
        displaySettings.hoverMetrics.sortedForDisplay().flatMap {
            tooltipLines(for: $0, snapshot: snapshot, language: displaySettings.language)
        }
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

    @objc private func handleStatusItemClick(_ sender: NSStatusBarButton) {
        let event = NSApp.currentEvent
        if StatusItemClickAction.resolve(type: event?.type, modifiers: event?.modifierFlags ?? []) == .contextMenu {
            showContextMenu(relativeTo: sender)
            return
        }
        if panel.isVisible || hubPanel?.isVisible == true {
            closeHubPanel()
            closePanel()
        } else {
            showHubPanel(relativeTo: sender)
        }
    }

    // Only consume events actually delivered to this status button. The local
    // mouse-down carries the real button/modifiers even when a control action
    // on macOS 27 is subsequently delivered as a gesture or keyboard event.
    private func handleSessionButtonEvent(_ event: NSEvent) -> Bool {
        guard let sessionBridge, !isPresentingContextMenu, let button = statusItem.button,
              let action = StatusItemClickAction.sessionAction(for: event, button: button,
                  expanded: sessionBridge.isActive || panel.isVisible || hubPanel?.isVisible == true) else { return false }
        switch action {
        case .contextMenu: showContextMenu(relativeTo: button)
        case .toggleCard: dismiss()
        }
        return true
    }

    private func showContextMenu(relativeTo button: NSStatusBarButton) {
        guard !isPresentingContextMenu, let menu = contextMenu?.menu,
              let anchor = resolveAnchor(for: button) else { return }
        menuAnchor = anchor
        dismiss()
        defer { menuAnchor = nil }
        menu.popUp(positioning: nil, at: NSPoint(x: anchor.minX, y: anchor.minY), in: nil)
    }

    private func showHubPanel(relativeTo button: NSStatusBarButton) {
        panelAnchor = menuAnchor ?? resolveAnchor(for: button)
        guard panelAnchor != nil else { dismiss(); return }
        closePanel()
        hubStore.selectDefault()
        if hubPanel == nil { hubPanel = makeHubPanel() }
        onVisibilityChange?(true)
        resizeHubPanel()
        hubPanel?.orderFrontRegardless()
    }

    private func makeHubPanel() -> HubPanel {
        let result = HubPanel()
        result.trackPopoverLifecycle()
        result.onNavigatePage = { [weak hubStore] direction in hubStore?.selectAdjacent(direction) ?? false }
        let root = HubPanelRootView(
            store: hubStore, displaySettings: displaySettings,
            requestKeyboard: { [weak self] in self?.hubPanel?.requestKeyboard() },
            holdInteraction: { [weak self] held in
                self?.hubInteractionHeld = held
                self?.updateHubPageSuppression()
            },
            openDetails: { [weak self] in self?.showDetails() },
            openSettings: { [weak self] in self?.openSettings?() }
        )
        let hosting = NSHostingView(rootView: root)
        let destination = NotchDropDestinationView(frame: .zero)
        destination.acceptsFiles = { [weak self] in self?.hubStore.settings.enabledFeatures.contains(.shelf) == true }
        destination.onEnter = { [weak self] in
            self?.hubFileDragging = true
            self?.updateHubPageSuppression()
            self?.hubStore.select(feature: .shelf)
            self?.resizeHubPanel()
        }
        destination.onExit = { [weak self] in
            self?.hubFileDragging = false
            self?.updateHubPageSuppression()
        }
        destination.onDrop = { [weak self] urls in
            self?.hubStore.shelf.add(urls: urls)
            self?.hubStore.select(feature: .shelf)
            self?.resizeHubPanel()
        }
        destination.embed(hosting)
        result.contentView = destination
        return result
    }

    private func updateHubPageSuppression() {
        hubPanel?.suppressesPageNavigation = hubInteractionHeld || hubFileDragging || !trackingMenus.isEmpty
    }

    private func resizeHubPanel(animated: Bool = false) {
        guard let hubPanel, let frame = panelFrame(size: NSSize(width: 360, height: hubStore.currentHeight)) else { return }
        hubPanel.setCardFrame(frame, animated: animated)
    }

    private func closeHubPanel() {
        guard let hubPanel, hubPanel.isVisible else { return }
        hubPanel.dismissOwnedChildren()
        hubPanel.endInteraction()
        hubInteractionHeld = false
        hubFileDragging = false
        hubPanel.orderOut(nil)
        trackingMenus.removeAll()
        onVisibilityChange?(panel.isVisible)
    }

    private func showPanel(frame: NSRect) {
        onVisibilityChange?(true)
        panel.setFrame(frame, display: true)
        panel.orderFrontRegardless()
    }

    private func resizePanelForCurrentStyle() {
        guard panel.isVisible, let frame = panelFrame(size: currentPanelSize) else { return }
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
        guard !isPresentingContextMenu else { return }
        if let hubPanel, hubPanel.isVisible {
            if hubPanel.containsOwnedPoint(point) || !trackingMenus.isEmpty { return }
            if panelAnchor?.contains(point) == true { return }
            dismiss()
            return
        }
        guard panel.isVisible else { return }
        if panel.frame.contains(point) { return }
        if panelAnchor?.contains(point) == true { return }
        dismiss()
    }

    private func panelFrame(size: NSSize) -> NSRect? {
        guard let buttonFrame = panelAnchor,
              let screen = NSScreen.screens.first(where: { $0.frame.contains(NSPoint(x: buttonFrame.midX, y: buttonFrame.midY)) })
        else { return nil }
        let visibleFrame = screen.visibleFrame
        let margin: CGFloat = 8

        var x = buttonFrame.midX - size.width / 2
        var y = buttonFrame.minY - size.height - margin

        x = min(max(x, visibleFrame.minX + margin), visibleFrame.maxX - size.width - margin)
        y = min(max(y, visibleFrame.minY + margin), visibleFrame.maxY - size.height - margin)

        return NSRect(origin: NSPoint(x: x, y: y), size: size)
    }

    private func resolveAnchor(for button: NSStatusBarButton) -> NSRect? {
        let frame = button.window.map { $0.convertToScreen(button.convert(button.bounds, to: nil)) }
        return StatusItemAnchor.resolve(buttonFrame: frame, pointer: NSEvent.mouseLocation,
                                        screens: NSScreen.screens.map { .init(frame: $0.frame, visibleFrame: $0.visibleFrame) },
                                        menuBarHeight: NSStatusBar.system.thickness)
    }

    private func handleLocalMouseEvent(_ event: NSEvent) {
        guard !isPresentingContextMenu else { return }
        if let window = statusItem.button?.window, event.window === window { return }
        if let hubPanel, hubPanel.isVisible {
            if hubPanel.owns(event.window) || hubPanel.containsOwnedPoint(NSEvent.mouseLocation) || !trackingMenus.isEmpty { return }
            dismiss()
        } else if panel.isVisible, event.window !== panel {
            dismiss()
        }
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
                    if name == NSWorkspace.didActivateApplicationNotification, self?.sessionBridge?.isActive == true { return }
                    self?.dismiss()
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
                self.updateHubPageSuppression()
            }
        }
        let end = NotificationCenter.default.addObserver(forName: NSMenu.didEndTrackingNotification, object: nil, queue: .main) { [weak self] note in
            guard let menu = note.object as? NSMenu else { return }
            let menuID = ObjectIdentifier(menu)
            MainActor.assumeIsolated {
                _ = self?.trackingMenus.remove(menuID)
                self?.updateHubPageSuppression()
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
    var openSettings: () -> Void

    var body: some View {
        MonitorPopoverView(
            metricsStore: metricsStore,
            displaySettings: displaySettings,
            ipGeolocationStore: ipGeolocationStore,
            clashStatusStore: clashStatusStore,
            openSettings: openSettings
        )
        .frame(
            width: displaySettings.panelStyle.panelSize.width,
            height: displaySettings.panelStyle.panelSize.height
        )
    }
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

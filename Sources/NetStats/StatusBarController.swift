import AppKit
import Combine
import SwiftUI

@MainActor
final class StatusBarController: NSObject {
    private let metricsStore: MetricsStore
    private let displaySettings: DisplaySettings
    private let ipGeolocationStore: IPGeolocationStore
    private let clashStatusStore: ClashStatusStore
    private let statusItem: NSStatusItem
    private lazy var panel = makePanel()
    private var cancellables = Set<AnyCancellable>()
    private var eventMonitors: [Any] = []

    private var currentPanelSize: NSSize {
        displaySettings.panelStyle.panelSize
    }

    init(
        metricsStore: MetricsStore,
        displaySettings: DisplaySettings,
        ipGeolocationStore: IPGeolocationStore,
        clashStatusStore: ClashStatusStore
    ) {
        self.metricsStore = metricsStore
        self.displaySettings = displaySettings
        self.ipGeolocationStore = ipGeolocationStore
        self.clashStatusStore = clashStatusStore
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()
        configureStatusItem()
        configurePanel()
        bindMetrics()
    }

    func stop() {
        for eventMonitor in eventMonitors {
            NSEvent.removeMonitor(eventMonitor)
        }
        eventMonitors.removeAll()
        closePanel()
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
                clashStatusStore: clashStatusStore
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
        let globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            Task { @MainActor in
                self?.closePanelIfNeeded(forScreenPoint: NSEvent.mouseLocation)
            }
        }
        if let globalMonitor {
            eventMonitors.append(globalMonitor)
        }

        let localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            self?.handleLocalMouseEvent(event)
            return event
        }
        if let localMonitor {
            eventMonitors.append(localMonitor)
        }
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
        if panel.isVisible {
            closePanel()
        } else {
            showPanel(relativeTo: sender)
        }
    }

    private func showPanel(relativeTo button: NSStatusBarButton) {
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
    }

    private func closePanelIfNeeded(forScreenPoint point: NSPoint) {
        guard panel.isVisible else {
            return
        }

        if panel.frame.contains(point) {
            return
        }

        if let button = statusItem.button,
           screenFrame(for: button).contains(point) {
            return
        }

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
        guard panel.isVisible else {
            return
        }

        if event.window === panel || event.window === statusItem.button?.window {
            return
        }

        closePanel()
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

    var body: some View {
        MonitorPopoverView(
            metricsStore: metricsStore,
            displaySettings: displaySettings,
            ipGeolocationStore: ipGeolocationStore,
            clashStatusStore: clashStatusStore
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
            return NSSize(width: 420, height: 740)
        case .terminal:
            return NSSize(width: 760, height: 700)
        }
    }
}

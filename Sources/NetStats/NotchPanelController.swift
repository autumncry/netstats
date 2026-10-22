import AppKit
import Combine
import SwiftUI

@MainActor
final class NotchPanelController {
    var openDetails: (() -> Void)?
    var openLegacySettings: (() -> Void)?

    private let hubStore: HubStore
    private let displaySettings: DisplaySettings
    private var interaction = HubHoverLifecycle()
    private var geometry: NotchGeometry?
    private var detailsVisible = false
    private var suspended = false
    private var started = false
    private var cardPresented = false
    private var uiHeld = false
    private var dragDestinations = Set<ObjectIdentifier>()
    private var trackingMenus = Set<ObjectIdentifier>()
    private var eventMonitors: [Any] = []
    private var observers: [(NotificationCenter, NSObjectProtocol)] = []
    private var subscriptions = Set<AnyCancellable>()
    private var deadlineTask: Task<Void, Never>?
    private var hideTask: Task<Void, Never>?
    private var dragTask: Task<Void, Never>?
    private var scheduledDeadline: TimeInterval?
    private var timerGeneration = 0
    private var revealGeneration = 0
    private var dragGeneration = 0
    private var dragDwell = NotchFileDragDwell()
    private let reveal = NotchRevealState()
    private let navigation = HubPanelNavigation()
    private var panel: HubPanel?
    private var connector: HubPanel?
    private var dropAnchor: HubPanel?
    private var anchorDestination: NotchDropDestinationView?
    private var cardDestination: NotchDropDestinationView?

    init(hubStore: HubStore, displaySettings: DisplaySettings) {
        self.hubStore = hubStore
        self.displaySettings = displaySettings
    }

    func start() {
        guard !started else { return }
        started = true
        refreshGeometry()
        observeEnvironment()
        displaySettings.$notchEnabled
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.configurationChanged() }
            .store(in: &subscriptions)
        hubStore.$selected
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.resizeCard() }
            .store(in: &subscriptions)
        hubStore.settings.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.resizeCard()
                self?.refreshDropAnchor()
            }
            .store(in: &subscriptions)
        navigation.$showingSettings
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.resizeCard() }
            .store(in: &subscriptions)
        configurationChanged()
    }

    func stop() {
        guard started else { return }
        started = false
        reset(animated: false)
        removeMouseMonitors()
        subscriptions.removeAll()
        for (center, token) in observers { center.removeObserver(token) }
        observers.removeAll()
        dropAnchor?.orderOut(nil)
        dropAnchor?.contentView = nil
        dropAnchor = nil
        anchorDestination = nil
        panel?.contentView = nil
        panel?.stopPopoverTracking()
        panel = nil
        connector?.orderOut(nil)
        connector = nil
        cardDestination = nil
    }

    func setDetailsVisible(_ visible: Bool) {
        detailsVisible = visible
        reset(animated: false)
        refreshDropAnchor()
        if started { updatePointer() }
    }

    private var canMonitor: Bool {
        started && displaySettings.notchEnabled && geometry != nil && !suspended
    }

    private var acceptsShelfFiles: Bool {
        canMonitor && !detailsVisible && hubStore.settings.enabledFeatures.contains(.shelf)
    }

    private var held: Bool {
        uiHeld || !dragDestinations.isEmpty || !trackingMenus.isEmpty
            || (cardPresented && NSEvent.pressedMouseButtons != 0)
            || panel?.ownedChildren.isEmpty == false
    }

    private func refreshGeometry() {
        geometry = NSScreen.screens.compactMap { screen -> NotchGeometry? in
            guard let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber,
                  let left = screen.auxiliaryTopLeftArea,
                  let right = screen.auxiliaryTopRightArea
            else { return nil }
            return NotchGeometry.detect(
                screenFrame: screen.frame, visibleFrame: screen.visibleFrame,
                safeAreaTop: screen.safeAreaInsets.top,
                auxiliaryLeft: left, auxiliaryRight: right,
                isBuiltIn: CGDisplayIsBuiltin(CGDirectDisplayID(number.uint32Value)) != 0
            )
        }.first
        displaySettings.notchAvailable = geometry != nil
    }

    private func configurationChanged() {
        reset(animated: false)
        if canMonitor {
            installMouseMonitors()
            refreshDropAnchor()
            updatePointer()
        } else {
            removeMouseMonitors()
            dropAnchor?.orderOut(nil)
        }
    }

    private func installMouseMonitors() {
        guard eventMonitors.isEmpty else { return }
        let mask: NSEvent.EventTypeMask = [
            .mouseMoved, .leftMouseDragged, .rightMouseDragged, .otherMouseDragged,
            .leftMouseDown, .rightMouseDown, .otherMouseDown,
            .leftMouseUp, .rightMouseUp, .otherMouseUp
        ]
        if let token = NSEvent.addGlobalMonitorForEvents(matching: mask, handler: { [weak self] event in
            MainActor.assumeIsolated { self?.handleMouseEvent(event) }
        }) { eventMonitors.append(token) }
        if let token = NSEvent.addLocalMonitorForEvents(matching: mask.union(.keyDown), handler: { [weak self] event in
            var consumed = false
            MainActor.assumeIsolated {
                guard let self else { return }
                if event.type == .keyDown {
                    consumed = self.handleKeyEvent(event)
                    return
                }
                self.handleMouseEvent(event)
            }
            return consumed ? nil : event
        }) { eventMonitors.append(token) }
    }

    private func removeMouseMonitors() {
        for token in eventMonitors { NSEvent.removeMonitor(token) }
        eventMonitors.removeAll()
    }

    private func handleMouseEvent(_ event: NSEvent) {
        guard canMonitor else { return }
        let point = NSEvent.mouseLocation
        if [.leftMouseDown, .rightMouseDown, .otherMouseDown].contains(event.type),
           cardPresented,
           panel?.owns(event.window) != true,
           panel?.containsOwnedPoint(point) != true,
           geometry?.containsTrigger(point) != true,
           trackingMenus.isEmpty {
            reset(animated: true)
        }
        updatePointer()
    }

    private func handleKeyEvent(_ event: NSEvent) -> Bool {
        guard cardPresented, event.keyCode == 53, let panel,
              panel.owns(event.window) || panel.isKeyWindow else { return false }
        if panel.dismissOwnedChild() { return true }
        reset(animated: true)
        return true
    }

    private func updatePointer() {
        guard canMonitor, let geometry else { return }
        let point = NSEvent.mouseLocation
        interaction.update(
            now: ProcessInfo.processInfo.systemUptime,
            inTrigger: geometry.containsTrigger(point),
            inCard: cardPresented && panel?.containsOwnedPoint(point) == true,
            pointerDown: NSEvent.pressedMouseButtons != 0,
            held: held,
            suppressed: detailsVisible
        )
        if interaction.isVisible && !cardPresented { showCard() }
        if !interaction.isVisible && cardPresented { hideCard(animated: true) }
        scheduleDeadline()
    }

    private func scheduleDeadline() {
        let deadline = interaction.nextDeadline
        guard deadline != scheduledDeadline else { return }
        deadlineTask?.cancel()
        timerGeneration += 1
        scheduledDeadline = deadline
        guard let deadline else { deadlineTask = nil; return }
        let generation = timerGeneration
        let delay = max(0, deadline - ProcessInfo.processInfo.systemUptime)
        deadlineTask = Task { @MainActor [weak self] in
            do { try await Task.sleep(for: .seconds(delay)) } catch { return }
            guard let self, !Task.isCancelled, self.timerGeneration == generation else { return }
            self.scheduledDeadline = nil
            self.deadlineTask = nil
            self.updatePointer()
        }
    }

    private func reset(animated: Bool) {
        interaction.dismiss()
        deadlineTask?.cancel()
        deadlineTask = nil
        scheduledDeadline = nil
        timerGeneration += 1
        cancelDragDwell()
        anchorDestination?.cancel()
        cardDestination?.cancel()
        dragDestinations.removeAll()
        trackingMenus.removeAll()
        uiHeld = false
        hideCard(animated: animated)
    }

    private func makePanel() -> HubPanel {
        let result = HubPanel()
        result.trackPopoverLifecycle()
        result.onKeyboardInteraction = { [weak self] in self?.setUIHeld(true) }
        let root = HubPanelRootView(
            store: hubStore, displaySettings: displaySettings, navigation: navigation,
            requestKeyboard: { [weak self] in
                self?.panel?.requestKeyboard()
                self?.setUIHeld(true)
            },
            holdInteraction: { [weak self] in self?.setUIHeld($0) },
            openDetails: { [weak self] in self?.openDetails?() },
            openLegacySettings: { [weak self] in self?.openLegacySettings?() }
        )
        let hosting = NSHostingView(rootView: NotchPanelContent(content: root, reveal: reveal))
        let destination = makeDestination(isAnchor: false)
        destination.embed(hosting)
        result.contentView = destination
        cardDestination = destination
        return result
    }

    private func setUIHeld(_ value: Bool) {
        uiHeld = value
        updatePointer()
    }

    private func showCard(selectDefault: Bool = true) {
        guard canMonitor, !detailsVisible, geometry != nil else { return }
        hideTask?.cancel()
        hideTask = nil
        revealGeneration += 1
        if selectDefault {
            hubStore.selectDefault()
            navigation.showingSettings = false
        }
        if panel == nil { panel = makePanel() }
        cardPresented = true
        resizeCard()
        panel?.ignoresMouseEvents = false
        reveal.expanded = false
        panel?.orderFrontRegardless()
        connector?.orderFrontRegardless()
        // The real destination must survive ordering the expanded card in.
        dropAnchor?.orderFrontRegardless()
        withAnimation(.easeInOut(duration: 0.22)) { reveal.expanded = true }
    }

    private func hideCard(animated: Bool) {
        cardPresented = false
        hideTask?.cancel()
        hideTask = nil
        revealGeneration += 1
        panel?.dismissOwnedChildren()
        panel?.endInteraction()
        panel?.ignoresMouseEvents = true
        guard animated, panel?.isVisible == true else {
            reveal.expanded = false
            panel?.orderOut(nil)
            connector?.orderOut(nil)
            return
        }
        withAnimation(.easeInOut(duration: 0.22)) { reveal.expanded = false }
        let generation = revealGeneration
        hideTask = Task { @MainActor [weak self] in
            do { try await Task.sleep(for: .milliseconds(220)) } catch { return }
            guard let self, !Task.isCancelled, self.revealGeneration == generation else { return }
            self.panel?.orderOut(nil)
            self.connector?.orderOut(nil)
            self.hideTask = nil
        }
    }

    private func resizeCard() {
        guard cardPresented, let geometry, let panel else { return }
        let height: CGFloat = navigation.showingSettings ? 520 : hubStore.currentHeight
        let frame = geometry.cardFrame(height: height, width: 360)
        panel.setFrame(frame, display: true)
        let gap = geometry.notchFrame.minY - frame.maxY
        if gap > 0 {
            if connector == nil {
                let bridge = HubPanel()
                bridge.hasShadow = false
                bridge.ignoresMouseEvents = true
                let material = NSVisualEffectView()
                material.material = .menu
                material.blendingMode = .behindWindow
                material.state = .active
                bridge.contentView = material
                connector = bridge
            }
            connector?.setFrame(NSRect(x: geometry.notchFrame.minX, y: frame.maxY,
                                      width: geometry.notchFrame.width, height: gap), display: true)
            if panel.isVisible { connector?.orderFrontRegardless() }
        } else {
            connector?.orderOut(nil)
        }
    }

    private func refreshDropAnchor() {
        guard acceptsShelfFiles, let geometry else {
            anchorDestination?.cancel()
            dropAnchor?.orderOut(nil)
            return
        }
        if dropAnchor == nil {
            let anchor = HubPanel()
            anchor.hasShadow = false
            // This almost transparent paint remains inside the already black
            // camera housing; the actual window alpha stays 1 for drag delivery.
            anchor.backgroundColor = NSColor.black.withAlphaComponent(0.01)
            anchor.ignoresMouseEvents = false
            let destination = makeDestination(isAnchor: true)
            anchor.contentView = destination
            dropAnchor = anchor
            anchorDestination = destination
        }
        dropAnchor?.setFrame(geometry.notchFrame, display: true)
        dropAnchor?.orderFrontRegardless()
    }

    private func makeDestination(isAnchor: Bool) -> NotchDropDestinationView {
        let destination = NotchDropDestinationView(frame: .zero)
        destination.acceptsFiles = { [weak self] in self?.acceptsShelfFiles == true }
        destination.onEnter = { [weak self, weak destination] in
            guard let self, let destination else { return }
            self.dragDestinations.insert(ObjectIdentifier(destination))
            if isAnchor { self.beginDragDwell() }
            else {
                self.hubStore.select(feature: .shelf)
                self.navigation.showingSettings = false
                self.resizeCard()
            }
            self.updatePointer()
        }
        destination.onExit = { [weak self, weak destination] in
            guard let self, let destination else { return }
            self.dragDestinations.remove(ObjectIdentifier(destination))
            if isAnchor { self.cancelDragDwell() }
            self.updatePointer()
        }
        destination.onDrop = { [weak self] urls in
            guard let self, self.acceptsShelfFiles else { return }
            self.hubStore.shelf.add(urls: urls)
            self.hubStore.select(feature: .shelf)
            self.navigation.showingSettings = false
            self.interaction.expandForFileDrag()
            if !self.cardPresented { self.showCard(selectDefault: false) }
            self.resizeCard()
        }
        return destination
    }

    private func beginDragDwell() {
        guard dragTask == nil, acceptsShelfFiles else { return }
        dragDwell.enter(now: ProcessInfo.processInfo.systemUptime)
        guard let deadline = dragDwell.deadline else { return }
        dragGeneration += 1
        let generation = dragGeneration
        dragTask = Task { @MainActor [weak self] in
            do { try await Task.sleep(for: .seconds(max(0, deadline - ProcessInfo.processInfo.systemUptime))) }
            catch { return }
            guard let self, !Task.isCancelled, self.dragGeneration == generation,
                  self.acceptsShelfFiles, self.anchorDestination?.hasValidFiles == true,
                  self.dragDwell.isReady(now: ProcessInfo.processInfo.systemUptime)
            else { return }
            self.dragTask = nil
            self.hubStore.select(feature: .shelf)
            self.navigation.showingSettings = false
            self.interaction.expandForFileDrag()
            if !self.cardPresented { self.showCard(selectDefault: false) }
            self.resizeCard()
            self.scheduleDeadline()
        }
    }

    private func cancelDragDwell() {
        dragTask?.cancel()
        dragTask = nil
        dragGeneration += 1
        dragDwell.exit()
    }

    private func observeEnvironment() {
        observe(.default, NSApplication.didChangeScreenParametersNotification) { [weak self] _ in self?.environmentChanged() }
        let workspace = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.willSleepNotification, NSWorkspace.screensDidSleepNotification,
                     NSWorkspace.sessionDidResignActiveNotification] {
            observe(workspace, name) { [weak self] _ in self?.suspend() }
        }
        for name in [NSWorkspace.didWakeNotification, NSWorkspace.screensDidWakeNotification,
                     NSWorkspace.sessionDidBecomeActiveNotification] {
            observe(workspace, name) { [weak self] _ in
                self?.suspended = false
                self?.environmentChanged()
            }
        }
        observe(workspace, NSWorkspace.activeSpaceDidChangeNotification) { [weak self] _ in self?.environmentChanged() }
        observe(workspace, NSWorkspace.didActivateApplicationNotification) { [weak self] _ in self?.reset(animated: false) }
        observe(.default, NSMenu.didBeginTrackingNotification) { [weak self] menuID in
            guard let self, self.cardPresented, let menuID,
                  self.panel?.containsOwnedPoint(NSEvent.mouseLocation) == true else { return }
            self.trackingMenus.insert(menuID)
            self.updatePointer()
        }
        observe(.default, NSMenu.didEndTrackingNotification) { [weak self] menuID in
            guard let self, let menuID else { return }
            self.trackingMenus.remove(menuID)
            self.updatePointer()
        }
    }

    private func observe(_ center: NotificationCenter, _ name: Notification.Name, action: @escaping @MainActor (ObjectIdentifier?) -> Void) {
        let token = center.addObserver(forName: name, object: nil, queue: .main) { notification in
            let objectID = notification.object.map { ObjectIdentifier($0 as AnyObject) }
            MainActor.assumeIsolated { action(objectID) }
        }
        observers.append((center, token))
    }

    private func suspend() { suspended = true; configurationChanged() }
    private func environmentChanged() { reset(animated: false); refreshGeometry(); configurationChanged() }
}

@MainActor
private final class NotchRevealState: ObservableObject { @Published var expanded = false }

private struct NotchPanelContent: View {
    let content: HubPanelRootView
    @ObservedObject var reveal: NotchRevealState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        content
            .scaleEffect(
                x: reduceMotion || reveal.expanded ? 1 : 0.86,
                y: reduceMotion || reveal.expanded ? 1 : 0.01,
                anchor: .top
            )
            .opacity(reveal.expanded ? 1 : 0)
            .allowsHitTesting(reveal.expanded)
            .clipped()
    }
}

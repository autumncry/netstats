import AppKit
import Combine
import SwiftUI
import QuartzCore

/// Passive controls remain nonactivating. Only an explicit input interaction
/// grants key-window status, and the panel can never become the main window.
@MainActor
final class HubPanel: NSPanel {
    var allowsKeyboardFocus = false
    var onKeyboardInteraction: (() -> Void)?
    var onNavigatePage: ((HubPageDirection) -> Bool)?
    var suppressesPageNavigation = false {
        didSet { if suppressesPageNavigation { pageSwipe.reset() } }
    }
    private var pageSwipe = HubPageSwipe()
    private var popoverObserver: NSObjectProtocol?
    private let popovers = NSHashTable<NSPopover>.weakObjects()
    override var canBecomeKey: Bool { allowsKeyboardFocus }
    override var canBecomeMain: Bool { false }

    init() {
        super.init(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        backgroundColor = .clear
        isOpaque = false
        hasShadow = true
        hidesOnDeactivate = false
        isMovable = false
        isReleasedWhenClosed = false
        acceptsMouseMovedEvents = true
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        level = .popUpMenu
    }

    func requestKeyboard() {
        allowsKeyboardFocus = true
        makeKey()
    }

    /// Only user page changes animate. Opening, screen changes and layout
    /// refreshes use the immediate path, with no delayed resize tasks.
    func setCardFrame(_ frame: NSRect, animated: Bool) {
        let shouldAnimate = animated && isVisible && !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        // Retarget the same animatable property even for immediate updates.
        // Calling setFrame directly does not cancel an in-flight animator,
        // and a quick reversal may still equal the first animation's start.
        NSAnimationContext.runAnimationGroup { context in
            context.duration = shouldAnimate ? HubPageMotion.duration : 0
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            animator().setFrame(frame, display: true)
        }
    }

    func trackPopoverLifecycle() {
        guard popoverObserver == nil else { return }
        popoverObserver = NotificationCenter.default.addObserver(forName: NSPopover.didShowNotification, object: nil, queue: .main) { [weak self] note in
            guard let popover = note.object as? NSPopover else { return }
            MainActor.assumeIsolated {
                guard let self, self.isVisible,
                      self.isKeyWindow || self.containsOwnedPoint(NSEvent.mouseLocation) else { return }
                self.popovers.add(popover)
            }
        }
    }

    func stopPopoverTracking() {
        if let popoverObserver { NotificationCenter.default.removeObserver(popoverObserver) }
        popoverObserver = nil
        popovers.removeAllObjects()
    }

    override func sendEvent(_ event: NSEvent) {
        if event.type == .scrollWheel, let onNavigatePage {
            let decision = pageSwipe.update(
                x: event.scrollingDeltaX, y: event.scrollingDeltaY,
                phase: pagePhase(event.phase), precise: event.hasPreciseScrollingDeltas,
                momentum: !event.momentumPhase.isEmpty,
                suppressed: suppressesPageNavigation || NSEvent.pressedMouseButtons != 0
                    || firstResponder is NSTextView || !ownedChildren.isEmpty
            )
            if let direction = decision.direction { _ = onNavigatePage(direction) }
            if decision.consumed { return }
        }
        // Grant key status before AppKit dispatches the first field click.
        // A SwiftUI tap callback alone can arrive after the field has already
        // declined that initial focus attempt in a passive panel.
        if event.type == .leftMouseDown, let contentView {
            let location = contentView.convert(event.locationInWindow, from: nil)
            var candidate = contentView.hitTest(location)
            while let view = candidate {
                if view is NSTextView || (view as? NSTextField).map({ $0.isEditable || $0.isSelectable }) == true {
                    requestKeyboard()
                    onKeyboardInteraction?()
                    break
                }
                candidate = view.superview
            }
        }
        super.sendEvent(event)
    }

    private func pagePhase(_ phase: NSEvent.Phase) -> HubPageSwipe.Phase {
        if phase.contains(.cancelled) { return .cancelled }
        if phase.contains(.ended) { return .ended }
        if phase.contains(.began) { return .began }
        if phase.contains(.changed) || phase.contains(.stationary) { return .changed }
        return .none
    }

    func endInteraction() {
        pageSwipe.reset()
        suppressesPageNavigation = false
        makeFirstResponder(nil)
        allowsKeyboardFocus = false
        if isKeyWindow { resignKey() }
    }

    func owns(_ window: NSWindow?) -> Bool {
        guard let window else { return false }
        if window === self { return true }
        var ancestor = window.parent
        while let current = ancestor {
            if current === self { return true }
            ancestor = current.parent
        }
        return ownedChildren.contains { $0 === window }
    }

    var ownedChildren: [NSWindow] {
        func descendants(of window: NSWindow) -> [NSWindow] {
            let children = (window.childWindows ?? []) + (window.attachedSheet.map { [$0] } ?? [])
            return children + children.flatMap { descendants(of: $0) }
        }
        let popoverWindows = popovers.allObjects.filter(\.isShown).compactMap { $0.contentViewController?.view.window }
        return (descendants(of: self) + popoverWindows).filter(\.isVisible)
    }

    func containsOwnedPoint(_ point: NSPoint) -> Bool {
        frame.contains(point) || ownedChildren.contains { $0.frame.contains(point) }
    }

    /// Escape dismisses the frontmost owned sheet/popover before its parent.
    func dismissOwnedChild() -> Bool {
        if let popover = popovers.allObjects.last(where: \.isShown) {
            popover.performClose(nil)
            return true
        }
        guard let child = ownedChildren.last else { return false }
        if child.isSheet { endSheet(child) }
        else { child.close() }
        return true
    }

    func dismissOwnedChildren() {
        for popover in popovers.allObjects where popover.isShown { popover.performClose(nil) }
        for child in ownedChildren.reversed() {
            if child.isSheet { endSheet(child) }
            else { child.orderOut(nil) }
        }
    }
}

struct HubPanelRootView: View {
    @ObservedObject var store: HubStore
    @ObservedObject var displaySettings: DisplaySettings
    let requestKeyboard: () -> Void
    let holdInteraction: (Bool) -> Void
    let openDetails: () -> Void
    let openSettings: () -> Void

    var body: some View {
        HubCardView(store: store, displaySettings: displaySettings,
                    requestKeyboard: requestKeyboard, holdInteraction: holdInteraction,
                    openDetails: openDetails, openSettings: openSettings)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

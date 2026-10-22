import Foundation

/// Monotonic pointer policy. An explicit editing/dragging hold only extends an
/// already presented card; it never opens one accidentally.
package struct HubHoverLifecycle {
    package enum Phase: Equatable { case closed, waitingToOpen, expanded, waitingToClose }
    package private(set) var phase: Phase = .closed
    private var deadline: TimeInterval?
    private var requiresExit = false

    package init() {}
    package var isVisible: Bool { phase == .expanded || phase == .waitingToClose }
    package var nextDeadline: TimeInterval? {
        phase == .waitingToOpen || phase == .waitingToClose ? deadline : nil
    }

    package mutating func update(
        now: TimeInterval, inTrigger: Bool, inCard: Bool,
        pointerDown: Bool = false, held: Bool = false, suppressed: Bool = false
    ) {
        let inside = inTrigger || inCard
        if suppressed { dismiss(); return }
        if requiresExit {
            if !inside { requiresExit = false }
            return
        }
        switch phase {
        case .closed:
            if inTrigger && !pointerDown { phase = .waitingToOpen; deadline = now + 1 }
        case .waitingToOpen:
            if !inTrigger || pointerDown { dismiss(requireExit: false) }
            else if let deadline, now >= deadline { phase = .expanded; self.deadline = nil }
        case .expanded:
            if !inside && !held { phase = .waitingToClose; deadline = now + 0.3 }
        case .waitingToClose:
            if inside || held { phase = .expanded; deadline = nil }
            else if let deadline, now >= deadline { dismiss(requireExit: false) }
        }
    }

    package mutating func expandForFileDrag() {
        phase = .expanded
        deadline = nil
        requiresExit = false
    }

    package mutating func dismiss(requireExit: Bool = true) {
        phase = .closed
        deadline = nil
        requiresExit = requireExit
    }
}

package struct NotchFileDragDwell {
    package private(set) var deadline: TimeInterval?
    package init() {}
    package mutating func enter(now: TimeInterval) {
        if deadline == nil { deadline = now + 0.5 }
    }
    package mutating func exit() { deadline = nil }
    package func isReady(now: TimeInterval) -> Bool {
        deadline.map { now >= $0 } ?? false
    }
}

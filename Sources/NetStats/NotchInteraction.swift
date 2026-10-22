import Foundation

/// Pointer state driven by caller-supplied monotonic time and fresh hit testing.
package struct NotchInteraction {
    package enum Phase: Equatable {
        case closed, waitingToOpen, expanded, waitingToClose
    }

    package private(set) var phase: Phase = .closed
    private var deadline: TimeInterval?
    private var requiresExit = false

    package var nextDeadline: TimeInterval? {
        switch phase {
        case .waitingToOpen, .waitingToClose: deadline
        case .closed, .expanded: nil
        }
    }

    package var isVisible: Bool {
        phase == .expanded || phase == .waitingToClose
    }

    package init() {}

    package mutating func update(
        now: TimeInterval,
        inTrigger: Bool,
        inCard: Bool,
        mouseDown: Bool = false,
        suppressed: Bool = false
    ) {
        let isInside = inTrigger || inCard
        if suppressed {
            dismiss()
            return
        }
        if requiresExit {
            if !isInside { requiresExit = false }
            return
        }

        switch phase {
        case .closed:
            if inTrigger && !mouseDown {
                phase = .waitingToOpen
                deadline = now + 1
            }
        case .waitingToOpen:
            if !inTrigger || mouseDown {
                dismiss(requireExit: false)
            } else if let deadline, now >= deadline {
                phase = .expanded
                self.deadline = nil
            }
        case .expanded:
            if !isInside {
                phase = .waitingToClose
                deadline = now + 0.3
            }
        case .waitingToClose:
            if isInside {
                phase = .expanded
                deadline = nil
            } else if let deadline, now >= deadline {
                dismiss(requireExit: false)
            }
        }
    }

    package mutating func dismiss(requireExit: Bool = true) {
        phase = .closed
        deadline = nil
        requiresExit = requireExit
    }
}

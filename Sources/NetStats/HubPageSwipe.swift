import Foundation

enum HubPageDirection { case previous, next }

struct HubPageSwipe {
    enum Phase { case none, began, changed, ended, cancelled }
    struct Decision {
        var direction: HubPageDirection?
        var consumed = false
    }

    private enum Axis { case undecided, horizontal, vertical, blocked }
    private var active = false
    private var axis = Axis.undecided
    private var displacementX = 0.0
    private var travelX = 0.0
    private var travelY = 0.0
    private var navigated = false
    private var consumesMomentum = false

    mutating func reset() { self = Self() }

    mutating func update(x: Double, y: Double, phase: Phase, precise: Bool = true,
                         momentum: Bool = false, suppressed: Bool = false) -> Decision {
        if momentum { return Decision(consumed: consumesMomentum && !suppressed) }
        guard precise else { reset(); return Decision() }
        if phase == .began {
            reset()
            active = true
        }
        guard active else { return Decision() }
        if suppressed {
            axis = .blocked
            consumesMomentum = false
        }
        if phase == .cancelled {
            let consumed = axis == .horizontal
            reset()
            return Decision(consumed: consumed)
        }
        if phase == .ended {
            active = false
            consumesMomentum = axis == .horizontal
            return Decision(consumed: consumesMomentum)
        }
        guard phase == .began || phase == .changed,
              axis != .blocked, axis != .vertical else { return Decision() }
        guard x.isFinite, y.isFinite else { axis = .blocked; return Decision() }

        displacementX += x
        travelX += abs(x)
        travelY += abs(y)
        if axis == .undecided {
            // Lock to the initial dominant axis so a list scroll cannot later
            // become page navigation just because the fingers drift sideways.
            if travelY >= 8, travelY >= travelX * 1.5 { axis = .vertical }
            else if travelX >= 8, travelX >= travelY * 1.5 { axis = .horizontal }
        }
        guard axis == .horizontal else { return Decision() }
        consumesMomentum = true
        if !navigated, abs(displacementX) >= 40, abs(displacementX) >= travelY * 1.5 {
            navigated = true
            return Decision(direction: displacementX < 0 ? .next : .previous, consumed: true)
        }
        return Decision(consumed: true)
    }
}

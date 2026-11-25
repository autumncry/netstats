import SwiftUI

enum HubPageMotion {
    static let duration: TimeInterval = 0.24
    static let reducedDuration: TimeInterval = 0.12

    static func animation(reduceMotion: Bool) -> Animation {
        .easeOut(duration: reduceMotion ? reducedDuration : duration)
    }

    static func transition(direction: HubPageDirection?, reduceMotion: Bool) -> AnyTransition {
        guard !reduceMotion, let direction else { return .opacity }
        return .asymmetric(
            insertion: .move(edge: direction == .next ? .trailing : .leading).combined(with: .opacity),
            removal: .move(edge: direction == .next ? .leading : .trailing).combined(with: .opacity)
        )
    }
}

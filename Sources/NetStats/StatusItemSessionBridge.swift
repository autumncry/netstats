import Foundation
import ObjectiveC

/// Uses the documented macOS 27 Objective-C interface without making SDK 27
/// types a build-time requirement. Older runtimes simply fail capability checks.
@MainActor
final class StatusItemSessionBridge: NSObject {
    private static let delegateGetter = NSSelectorFromString("expandedInterfaceDelegate")
    private static let delegateSetter = NSSelectorFromString("setExpandedInterfaceDelegate:")
    private static let sessionGetter = NSSelectorFromString("expandedInterfaceSession")
    private static let cancelSelector = NSSelectorFromString("cancel")

    private weak var statusItem: NSObject?
    private var onBegin: (() -> Void)?
    private var onEnd: ((Bool) -> Void)?
    private var activeSessionID: ObjectIdentifier?
    private var cancellationRequestedID: ObjectIdentifier?
    private var stopped = false

    init?(statusItem: NSObject, onBegin: @escaping () -> Void, onEnd: @escaping (Bool) -> Void) {
        guard statusItem.responds(to: Self.delegateGetter), statusItem.responds(to: Self.delegateSetter),
              statusItem.responds(to: Self.sessionGetter) else { return nil }
        self.statusItem = statusItem
        self.onBegin = onBegin
        self.onEnd = onEnd
        super.init()

        if let delegateProtocol = NSProtocolFromString("NSStatusItemExpandedInterfaceDelegate") {
            if !class_conformsToProtocol(Self.self, delegateProtocol) {
                class_addProtocol(Self.self, delegateProtocol)
            }
            guard class_conformsToProtocol(Self.self, delegateProtocol) else { return nil }
        }
        _ = statusItem.perform(Self.delegateSetter, with: self)
        guard ownsDelegate(of: statusItem) else { return nil }
    }

    var isActive: Bool {
        guard !stopped, let statusItem, ownsDelegate(of: statusItem) else { return false }
        return object(from: statusItem, selector: Self.sessionGetter) != nil
    }

    func cancel() {
        guard !stopped, let statusItem, ownsDelegate(of: statusItem),
              let session = object(from: statusItem, selector: Self.sessionGetter),
              session.responds(to: Self.cancelSelector) else { return }
        let identifier = ObjectIdentifier(session)
        guard cancellationRequestedID != identifier else { return }
        cancellationRequestedID = identifier
        _ = session.perform(Self.cancelSelector)
    }

    func stop() {
        guard !stopped else { return }
        onBegin = nil
        onEnd = nil
        // Cancellation may call the delegate synchronously. Keep those callbacks
        // silent, and never detach a delegate installed by another owner.
        cancel()
        stopped = true
        if let statusItem, ownsDelegate(of: statusItem) {
            _ = statusItem.perform(Self.delegateSetter, with: nil)
        }
        statusItem = nil
        activeSessionID = nil
        cancellationRequestedID = nil
    }

    @objc(statusItem:didBeginExpandedInterfaceSession:)
    func statusItem(_ item: NSObject, didBegin session: NSObject) {
        guard !stopped, item === statusItem, ownsDelegate(of: item),
              object(from: item, selector: Self.sessionGetter) === session else { return }
        let identifier = ObjectIdentifier(session)
        guard activeSessionID != identifier else { return }
        activeSessionID = identifier
        cancellationRequestedID = nil
        onBegin?()
    }

    @objc(statusItemDidEndExpandedInterfaceSession:animated:)
    func statusItemDidEndExpandedInterfaceSession(_ item: NSObject, animated: Bool) {
        guard !stopped, item === statusItem, ownsDelegate(of: item), activeSessionID != nil,
              object(from: item, selector: Self.sessionGetter) == nil else { return }
        activeSessionID = nil
        cancellationRequestedID = nil
        onEnd?(animated)
    }

    private func ownsDelegate(of item: NSObject) -> Bool {
        object(from: item, selector: Self.delegateGetter) === self
    }

    private func object(from object: NSObject, selector: Selector) -> NSObject? {
        guard object.responds(to: selector) else { return nil }
        return object.perform(selector)?.takeUnretainedValue() as? NSObject
    }
}

import AppKit

/// Registered on the physical notch and as an ancestor of the card content.
/// Keeping the collapsed destination ordered in avoids a global drag monitor
/// and allows a real AppKit drop without Accessibility permission.
@MainActor
final class NotchDropDestinationView: NSView {
    var acceptsFiles: () -> Bool = { true }
    var onEnter: (() -> Void)?
    var onExit: (() -> Void)?
    var onDrop: (([URL]) -> Void)?
    private(set) var validDragActive = false
    private var activePasteboard: NSPasteboard?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        registerForDraggedTypes([.fileURL])
    }
    required init?(coder: NSCoder) { return nil }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    func embed(_ view: NSView) {
        view.translatesAutoresizingMaskIntoConstraints = false
        addSubview(view)
        NSLayoutConstraint.activate([
            view.leadingAnchor.constraint(equalTo: leadingAnchor),
            view.trailingAnchor.constraint(equalTo: trailingAnchor),
            view.topAnchor.constraint(equalTo: topAnchor),
            view.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation { update(sender) }
    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation { update(sender) }
    override func draggingExited(_ sender: NSDraggingInfo?) { finish() }
    override func draggingEnded(_ sender: NSDraggingInfo) { finish() }
    override func prepareForDragOperation(_ sender: NSDraggingInfo) -> Bool {
        acceptsFiles() && !Self.fileURLs(from: sender.draggingPasteboard).isEmpty
    }
    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let urls = Self.fileURLs(from: sender.draggingPasteboard)
        guard acceptsFiles(), !urls.isEmpty else { finish(); return false }
        onDrop?(urls)
        finish()
        return true
    }

    var hasValidFiles: Bool {
        validDragActive && acceptsFiles() && activePasteboard.map { !Self.fileURLs(from: $0).isEmpty } == true
    }

    func cancel() { finish() }

    private func update(_ sender: NSDraggingInfo) -> NSDragOperation {
        guard acceptsFiles(), !Self.fileURLs(from: sender.draggingPasteboard).isEmpty,
              sender.draggingSourceOperationMask.contains(.copy)
        else { finish(); return [] }
        activePasteboard = sender.draggingPasteboard
        if !validDragActive { validDragActive = true; onEnter?() }
        return .copy
    }

    private func finish() {
        let wasActive = validDragActive
        validDragActive = false
        activePasteboard = nil
        if wasActive { onExit?() }
    }

    static func fileURLs(from pasteboard: NSPasteboard) -> [URL] {
        (pasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL] ?? [])
            .filter { $0.isFileURL && FileManager.default.fileExists(atPath: $0.path) }
    }
}

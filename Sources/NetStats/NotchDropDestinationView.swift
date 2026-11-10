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
    var onClick: (() -> Void)?
    private var topBarMaterial: NSVisualEffectView?
    private(set) var validDragActive = false
    private var activePasteboard: NSPasteboard?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        registerForDraggedTypes([.fileURL])
    }
    required init?(coder: NSCoder) { return nil }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    func setTopBarAppearance(_ enabled: Bool, language: AppLanguage) {
        setAccessibilityElement(enabled)
        setAccessibilityRole(enabled ? .button : .unknown)
        setAccessibilityLabel(enabled ? (language == .simplifiedChinese ? "打开 NetStats 屏顶卡片" : "Open NetStats top-edge card") : nil)
        toolTip = enabled ? (language == .simplifiedChinese ? "NetStats · 悬停 1 秒或点击展开" : "NetStats · Hover for 1 second or click to open") : nil
        if enabled {
            if topBarMaterial == nil {
                let material = TopBarMaterialView(frame: bounds)
                material.autoresizingMask = [.width, .height]
                material.material = .hudWindow
                material.blendingMode = .behindWindow
                material.state = .active
                material.wantsLayer = true
                material.layer?.cornerRadius = 4
                material.layer?.masksToBounds = true
                addSubview(material)
                topBarMaterial = material
            }
        } else {
            topBarMaterial?.removeFromSuperview()
            topBarMaterial = nil
        }
    }

    override func mouseDown(with event: NSEvent) {
        if let onClick { onClick() }
        else { super.mouseDown(with: event) }
    }
    override func accessibilityPerformPress() -> Bool {
        guard let onClick else { return false }
        onClick()
        return true
    }

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

private final class TopBarMaterialView: NSVisualEffectView {
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}

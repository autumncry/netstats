import AppKit

enum StatusItemClickAction: Equatable {
    case toggleCard, contextMenu

    static func resolve(type: NSEvent.EventType?, modifiers: NSEvent.ModifierFlags) -> Self {
        if type == .rightMouseUp || (type == .leftMouseUp && modifiers.contains(.control)) {
            return .contextMenu
        }
        return .toggleCard
    }
    @MainActor static func sessionAction(for event: NSEvent, button: NSView, expanded: Bool) -> Self? {
        guard event.type == .rightMouseDown || event.type == .leftMouseDown,
              let window = button.window, event.window === window,
              button.bounds.contains(button.convert(event.locationInWindow, from: nil)) else { return nil }
        if event.type == .rightMouseDown || event.modifierFlags.contains(.control) { return .contextMenu }
        return expanded ? .toggleCard : nil
    }

}

@MainActor
final class StatusItemContextMenu: NSObject, NSMenuDelegate {
    enum Command: Int { case showCard = 1, showDetails, settings, quit }
    let menu = NSMenu()
    private let language: () -> AppLanguage
    private let overviewLines: () -> [String]
    private let onTrackingChanged: (Bool) -> Void
    private var displayedLanguage: AppLanguage?
    private var displayedLines: [String] = []
    private let showCard: () -> Void
    private let showDetails: () -> Void
    private let settings: () -> Void
    private let quit: () -> Void

    init(language: @escaping () -> AppLanguage, overviewLines: @escaping () -> [String],
         onTrackingChanged: @escaping (Bool) -> Void, showCard: @escaping () -> Void, showDetails: @escaping () -> Void,
         settings: @escaping () -> Void, quit: @escaping () -> Void) {
        self.language = language
        self.overviewLines = overviewLines
        self.onTrackingChanged = onTrackingChanged
        self.showCard = showCard
        self.showDetails = showDetails
        self.settings = settings
        self.quit = quit
        super.init()
        menu.delegate = self
        menu.autoenablesItems = false
        menuNeedsUpdate(menu)
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        let language = language()
        let lines = overviewLines()
        guard displayedLanguage != language || displayedLines != lines else { return }
        displayedLanguage = language
        displayedLines = lines
        menu.removeAllItems()
        for line in lines {
            let metric = NSMenuItem(title: line, action: nil, keyEquivalent: "")
            metric.isEnabled = false
            menu.addItem(metric)
        }
        if !lines.isEmpty { menu.addItem(.separator()) }
        let chinese = language == .simplifiedChinese
        add(chinese ? "打开卡片" : "Open Card", command: .showCard)
        add(chinese ? "查看详情" : "Show Details", command: .showDetails)
        add(chinese ? "设置…" : "Settings…", command: .settings, key: ",")
        menu.addItem(.separator())
        add(chinese ? "退出 NetStats" : "Quit NetStats", command: .quit, key: "q")
    }

    func menuWillOpen(_ menu: NSMenu) { onTrackingChanged(true) }

    func menuDidClose(_ menu: NSMenu) { onTrackingChanged(false) }

    private func add(_ title: String, command: Command, key: String = "") {
        let item = NSMenuItem(title: title, action: #selector(performCommand(_:)), keyEquivalent: key)
        item.target = self
        item.tag = command.rawValue
        item.keyEquivalentModifierMask = .command
        menu.addItem(item)
    }

    @objc private func performCommand(_ sender: NSMenuItem) {
        guard let command = Command(rawValue: sender.tag) else { return }
        switch command {
        case .showCard: showCard()
        case .showDetails: showDetails()
        case .settings: settings()
        case .quit: quit()
        }
    }
}

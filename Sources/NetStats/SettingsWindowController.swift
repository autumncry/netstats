import AppKit
import Combine
import SwiftUI

/// A reusable, regular window with its own focus and lifetime, outside hover cards.
@MainActor
final class SettingsWindowController: NSWindowController, NSWindowDelegate {
    var onVisibilityChange: ((Bool) -> Void)?
    var onRequestShowSettings: (() -> Void)?
    private var subscriptions = Set<AnyCancellable>()
    private var previousApplication: NSRunningApplication?
    private var reportedVisible = false
    private var hasBeenPresented = false
    private var editingMenu: NSMenu?
    var isPresented: Bool { window?.isVisible == true && window?.isMiniaturized == false }

    init(hubStore: HubStore, displaySettings: DisplaySettings, metricsStore: MetricsStore) {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 780, height: 620),
                              styleMask: [.titled, .closable, .miniaturizable, .resizable],
                              backing: .buffered, defer: false)
        window.minSize = NSSize(width: 640, height: 480)
        window.isReleasedWhenClosed = false
        window.collectionBehavior = [.moveToActiveSpace]
        window.contentViewController = NSHostingController(rootView: HubSettingsView(
            store: hubStore, displaySettings: displaySettings, metricsStore: metricsStore))
        super.init(window: window)
        window.delegate = self
        displaySettings.$language.receive(on: RunLoop.main).sink { [weak window] language in
            window?.title = language == .simplifiedChinese ? "NetStats 设置" : "NetStats Settings"
        }.store(in: &subscriptions)
        window.title = displaySettings.language == .simplifiedChinese ? "NetStats 设置" : "NetStats Settings"
        installEditingMenuIfNeeded()
    }
    required init?(coder: NSCoder) { nil }

    func showSettings(activate: Bool = true) {
        guard let window else { return }
        installEditingMenuIfNeeded()
        if activate, let previous = NSWorkspace.shared.frontmostApplication,
           previous.processIdentifier != ProcessInfo.processInfo.processIdentifier {
            previousApplication = previous
        }
        if !hasBeenPresented { window.center(); hasBeenPresented = true }
        if window.isMiniaturized { window.deminiaturize(nil) }
        if let screen = NSScreen.main {
            window.setFrame(window.constrainFrameRect(window.frame, to: screen), display: false)
        }
        if activate {
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
        } else {
            window.orderFront(nil)
        }
        publishVisibility()
    }

    func stop() {
        previousApplication = nil
        window?.close()
        subscriptions.removeAll()
        if let editingMenu, NSApp.mainMenu === editingMenu { NSApp.mainMenu = nil }
        editingMenu = nil
    }

    func windowWillClose(_ notification: Notification) {
        publishVisibility(false)
        // Do not steal focus back if the user already switched to another app.
        if NSApp.isActive, let previousApplication, !previousApplication.isTerminated {
            previousApplication.activate(options: [])
        }
        previousApplication = nil
    }
    func windowDidMiniaturize(_ notification: Notification) { publishVisibility(false) }
    func windowDidDeminiaturize(_ notification: Notification) { publishVisibility() }

    private func publishVisibility(_ value: Bool? = nil) {
        let visible = value ?? isPresented
        guard visible != reportedVisible else { return }
        reportedVisible = visible
        onVisibilityChange?(visible)
    }

    // Accessory apps do not receive a storyboard's standard menu. Supply the
    // responder-chain commands so native text fields support normal editing.
    private func installEditingMenuIfNeeded() {
        guard NSApp.mainMenu == nil || NSApp.mainMenu === editingMenu else { return }
        let chinese = window?.title.contains("设置") == true
        func tr(_ zh: String, _ en: String) -> String { chinese ? zh : en }
        let menu = NSMenu()
        let appItem = NSMenuItem(title: "NetStats", action: nil, keyEquivalent: "")
        let appMenu = NSMenu(title: "NetStats")
        appMenu.addItem(withTitle: tr("设置…", "Settings…"), action: #selector(requestSettingsFromMenu(_:)), keyEquivalent: ",").target = self
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: tr("退出 NetStats", "Quit NetStats"), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q").target = NSApp
        appItem.submenu = appMenu
        menu.addItem(appItem)

        let fileItem = NSMenuItem(title: tr("文件", "File"), action: nil, keyEquivalent: "")
        let fileMenu = NSMenu(title: fileItem.title)
        fileMenu.addItem(withTitle: tr("关闭窗口", "Close Window"), action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        fileItem.submenu = fileMenu
        menu.addItem(fileItem)

        let editItem = NSMenuItem(title: tr("编辑", "Edit"), action: nil, keyEquivalent: "")
        let editMenu = NSMenu(title: editItem.title)
        editMenu.addItem(withTitle: tr("撤销", "Undo"), action: Selector(("undo:")), keyEquivalent: "z")
        let redo = editMenu.addItem(withTitle: tr("重做", "Redo"), action: Selector(("redo:")), keyEquivalent: "z")
        redo.keyEquivalentModifierMask = [.command, .shift]
        editMenu.addItem(.separator())
        for (title, action, key) in [(tr("剪切", "Cut"), "cut:", "x"), (tr("拷贝", "Copy"), "copy:", "c"),
                                     (tr("粘贴", "Paste"), "paste:", "v"), (tr("全选", "Select All"), "selectAll:", "a")] {
            editMenu.addItem(withTitle: title, action: Selector(action), keyEquivalent: key)
        }
        editItem.submenu = editMenu
        menu.addItem(editItem)
        editingMenu = menu
        NSApp.mainMenu = menu
    }

    @objc private func requestSettingsFromMenu(_ sender: Any?) {
        if let onRequestShowSettings { onRequestShowSettings() }
        else { showSettings() }
    }
}

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
    private var presentationGeneration = 0
    private var authorizingCalendar = false
    var isPresented: Bool { window?.isVisible == true && window?.isMiniaturized == false }

    init(hubStore: HubStore, displaySettings: DisplaySettings, metricsStore: MetricsStore) {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 780, height: 620),
                              styleMask: [.titled, .closable, .miniaturizable, .resizable],
                              backing: .buffered, defer: false)
        window.minSize = NSSize(width: 640, height: 480)
        window.isReleasedWhenClosed = false
        window.collectionBehavior = [.moveToActiveSpace]
        super.init(window: window)
        window.delegate = self
        let calendar = hubStore.calendar
        window.contentViewController = NSHostingController(rootView: HubSettingsView(
            store: hubStore, displaySettings: displaySettings, metricsStore: metricsStore,
            requestCalendarAccess: { [weak self] in
                await self?.requestCalendarAccess(calendar)
            }))
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

    // Only the explicit Settings button owns this round trip. Routine EventKit
    // refreshes must never present a prompt or move the user's window.
    func requestCalendarAccess(_ calendar: CalendarStore,
                               frontmost: () -> NSRunningApplication? = { NSWorkspace.shared.frontmostApplication }) async {
        guard isPresented, !authorizingCalendar, let window else { return }
        authorizingCalendar = true
        defer { authorizingCalendar = false }
        let generation = presentationGeneration
        let handoff = CalendarPromptFocus(previousPID: previousApplication?.processIdentifier)
        let center = NSWorkspace.shared.notificationCenter
        let observer = center.addObserver(forName: NSWorkspace.didActivateApplicationNotification,
                                          object: nil, queue: .main) { note in
            guard let application = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
            MainActor.assumeIsolated {
                handoff.didActivate(Self.focusOwner(application), at: ProcessInfo.processInfo.systemUptime)
            }
        }
        defer { center.removeObserver(observer) }
        await calendar.requestAccess {
            // Make the focus decision before querying potentially large calendars.
            guard generation == presentationGeneration, !window.isMiniaturized,
                  !NSApp.isHidden, window.isOnActiveSpace,
                  handoff.shouldReturn(to: Self.focusOwner(frontmost()),
                                       at: ProcessInfo.processInfo.systemUptime) else { return }
            if !NSApp.isActive { NSApp.activate() }
            window.makeKeyAndOrderFront(nil)
            publishVisibility()
        }
    }

    private static func focusOwner(_ app: NSRunningApplication?) -> CalendarPromptFocus.Owner {
        guard let app else { return .unknown }
        if app.processIdentifier == ProcessInfo.processInfo.processIdentifier { return .settings }
        switch app.bundleIdentifier {
        case "com.apple.UserNotificationCenter", "com.apple.SecurityAgent": return .permissionDialog
        default: return .other(app.processIdentifier)
        }
    }

    func stop() {
        previousApplication = nil
        window?.close()
        subscriptions.removeAll()
        if let editingMenu, NSApp.mainMenu === editingMenu { NSApp.mainMenu = nil }
        editingMenu = nil
    }

    func windowWillClose(_ notification: Notification) {
        presentationGeneration += 1
        publishVisibility(false)
        // Do not steal focus back if the user already switched to another app.
        if NSApp.isActive, let previousApplication, !previousApplication.isTerminated {
            previousApplication.activate(options: [])
        }
        previousApplication = nil
    }
    func windowWillMiniaturize(_ notification: Notification) { presentationGeneration += 1 }
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

/// An accessory app's permission dialog can dismiss to the previous foreground
/// app immediately *before* EventKit delivers its result. Accept that specific
/// handoff, but do not interrupt a user who moved on to another app.
@MainActor
final class CalendarPromptFocus {
    enum Owner: Equatable { case settings, permissionDialog, other(pid_t), unknown }
    private let previousPID: pid_t?
    private var sawPrompt = false
    private var userSwitchedAway = false
    private var returnedAt: TimeInterval?

    init(previousPID: pid_t?) { self.previousPID = previousPID }

    func didActivate(_ owner: Owner, at time: TimeInterval) {
        switch owner {
        case .permissionDialog: sawPrompt = true
        case .other(let pid):
            if sawPrompt, pid == previousPID, returnedAt == nil { returnedAt = time }
            else { userSwitchedAway = true }
        case .settings, .unknown: break
        }
    }

    func shouldReturn(to owner: Owner, at time: TimeInterval) -> Bool {
        if owner == .settings { return true }
        guard !userSwitchedAway else { return false }
        switch owner {
        case .permissionDialog: return true
        case .other(let pid):
            guard sawPrompt, pid == previousPID else { return false }
            // Workspace's activation notification and EventKit's completion
            // can arrive in either order during the prompt's dismissal.
            return returnedAt.map { time - $0 <= 0.3 } ?? true
        case .unknown, .settings: return false
        }
    }
}

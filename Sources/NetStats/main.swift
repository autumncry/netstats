import AppKit

@MainActor
private func runApplication() {
    let application = NSApplication.shared
    let delegate = AppDelegate()

    application.delegate = delegate
    application.setActivationPolicy(.accessory)
    application.run()
}

runApplication()

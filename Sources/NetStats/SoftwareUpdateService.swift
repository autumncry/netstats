import Combine
import Foundation
import Sparkle

/// One updater for the app's lifetime, including when Settings is closed.
@MainActor
final class SoftwareUpdateService: NSObject, ObservableObject, SPUUpdaterDelegate, @preconcurrency SPUStandardUserDriverDelegate {
    static let shared = SoftwareUpdateService()
    private lazy var controller = SPUStandardUpdaterController(
        startingUpdater: false, updaterDelegate: self, userDriverDelegate: self)
    private var observers = Set<AnyCancellable>()
    private var started = false

    @Published private(set) var canCheck = false
    @Published private(set) var automaticChecks = false
    @Published private(set) var automaticDownloads = false
    @Published private(set) var pendingVersion: String?
    @Published private(set) var startupError: String?

    func start() {
        guard !started else { return }
        let updater = controller.updater
        do {
            try updater.start()
            started = true
            startupError = nil
            updater.publisher(for: \.canCheckForUpdates).removeDuplicates()
                .sink { [weak self] in self?.canCheck = $0 }.store(in: &observers)
            updater.publisher(for: \.automaticallyChecksForUpdates).removeDuplicates()
                .sink { [weak self] in self?.automaticChecks = $0 }.store(in: &observers)
            updater.publisher(for: \.automaticallyDownloadsUpdates).removeDuplicates()
                .sink { [weak self] in self?.automaticDownloads = $0 }.store(in: &observers)
        } catch {
            startupError = error.localizedDescription
        }
    }

    func check() {
        start()
        if started && controller.updater.canCheckForUpdates { controller.checkForUpdates(nil) }
    }

    func setAutomaticChecks(_ enabled: Bool) {
        guard started else { return }
        if !enabled { controller.updater.automaticallyDownloadsUpdates = false }
        controller.updater.automaticallyChecksForUpdates = enabled
    }

    func setAutomaticDownloads(_ enabled: Bool) {
        guard started, automaticChecks else { return }
        controller.updater.automaticallyDownloadsUpdates = enabled
    }

    func feedURLString(for updater: SPUUpdater) -> String? {
        Bundle.main.object(forInfoDictionaryKey: "SUFeedURL") as? String
    }

    var supportsGentleScheduledUpdateReminders: Bool { true }

    func standardUserDriverWillHandleShowingUpdate(_ handleShowingUpdate: Bool, forUpdate update: SUAppcastItem,
                                                   state: SPUUserUpdateState) {
        pendingVersion = update.displayVersionString
    }

    func standardUserDriverWillFinishUpdateSession() { pendingVersion = nil }
}

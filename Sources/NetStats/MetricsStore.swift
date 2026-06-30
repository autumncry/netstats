import Combine
import Foundation

@MainActor
final class MetricsStore: ObservableObject {
    @Published private(set) var snapshot = SystemSnapshot.empty
    @Published private(set) var history = MetricHistory()
    @Published private(set) var processSnapshot = ProcessSnapshot.empty

    private let systemSampler = SystemSampler()
    private let processSampler = ProcessMetricSampler()
    private var systemTimer: Timer?
    private var processTimer: Timer?
    private var isRefreshingProcesses = false

    func start() {
        refreshSystem()
        refreshProcesses()

        systemTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refreshSystem()
            }
        }
        if let systemTimer {
            RunLoop.main.add(systemTimer, forMode: .common)
        }

        processTimer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refreshProcesses()
            }
        }
        if let processTimer {
            RunLoop.main.add(processTimer, forMode: .common)
        }
    }

    func stop() {
        systemTimer?.invalidate()
        systemTimer = nil
        processTimer?.invalidate()
        processTimer = nil
    }

    private func refreshSystem() {
        let nextSnapshot = systemSampler.sample()
        snapshot = nextSnapshot
        history.append(nextSnapshot)
    }

    private func refreshProcesses() {
        guard !isRefreshingProcesses else {
            return
        }

        isRefreshingProcesses = true
        let sampler = processSampler
        DispatchQueue.global(qos: .utility).async {
            let processSnapshot = sampler.sample()
            DispatchQueue.main.async {
                self.processSnapshot = processSnapshot
                self.isRefreshingProcesses = false
            }
        }
    }
}

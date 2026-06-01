import Combine
import Foundation

@MainActor
final class MetricsStore: ObservableObject {
    @Published private(set) var snapshot = SystemSnapshot.empty

    private let sampler = SystemSampler()
    private var timer: Timer?

    func start() {
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refresh()
            }
        }
        RunLoop.main.add(timer!, forMode: .common)
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func refresh() {
        snapshot = sampler.sample()
    }
}

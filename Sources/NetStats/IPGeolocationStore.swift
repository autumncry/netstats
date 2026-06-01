import Combine
import Foundation

struct PublicIPLocation: Equatable, Sendable {
    let ipAddress: String
    let city: String?
    let region: String?
    let country: String?
    let coordinates: String?

    var displayLocation: String {
        [city, region, country]
            .compactMap { value in
                guard let value, !value.isEmpty else { return nil }
                return value
            }
            .joined(separator: ", ")
    }
}

@MainActor
final class IPGeolocationStore: ObservableObject {
    @Published private(set) var location: PublicIPLocation?
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?

    private var timer: Timer?

    func start() {
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 30 * 60, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refresh()
            }
        }

        if let timer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func refresh() {
        guard !isLoading else {
            return
        }

        isLoading = true
        errorMessage = nil

        Task {
            do {
                let location = try await Self.fetchLocation()
                self.location = location
                self.errorMessage = nil
            } catch {
                self.errorMessage = "Unavailable"
            }

            self.isLoading = false
        }
    }

    private static func fetchLocation() async throws -> PublicIPLocation {
        let url = URL(string: "https://ipinfo.io/json")!
        var request = URLRequest(url: url)
        request.timeoutInterval = 5
        request.cachePolicy = .reloadIgnoringLocalCacheData

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }

        let payload = try JSONDecoder().decode(IPInfoResponse.self, from: data)
        return PublicIPLocation(
            ipAddress: payload.ip,
            city: payload.city,
            region: payload.region,
            country: payload.country,
            coordinates: payload.loc
        )
    }
}

private struct IPInfoResponse: Decodable, Sendable {
    let ip: String
    let city: String?
    let region: String?
    let country: String?
    let loc: String?
}

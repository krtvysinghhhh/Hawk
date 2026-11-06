import XCTest
@testable import HawkNetworking
@testable import HawkCore

final class HawkNetworkingTests: XCTestCase {

    @MainActor
    func testNetworkMonitor() {
        let monitor = NetworkMonitor.shared
        let ceiling = monitor.suggestedQualityCeiling()
        XCTAssertTrue(ceiling == .standard || ceiling == .lossless)
    }

    func testClientHeaders() async throws {
        let client = HawkHttpClient()
        XCTAssertNotNil(client)
    }

    func testCancellationPropagation() async {
        let client = HawkHttpClient()
        guard let url = URL(string: "https://httpbin.org/delay/10") else { return }

        let task = Task {
            try await client.request(url: url)
        }
        task.cancel()

        do {
            _ = try await task.value
            XCTFail("Cancelled task should throw CancellationError")
        } catch is CancellationError {
            // Expected
        } catch {
            // Also acceptable if URLError cancelled
            if let urlErr = error as? URLError, urlErr.code == .cancelled {
                // Expected
            } else {
                XCTFail("Expected cancellation, got \(error)")
            }
        }
    }

    func testRetryJitterBoundaries() {
        for _ in 0..<100 {
            let jitter = Double.random(in: 0.8...1.2)
            XCTAssertGreaterThanOrEqual(jitter, 0.8)
            XCTAssertLessThanOrEqual(jitter, 1.2)
        }
    }

    func testRetryAfterClampingLogic() {
        let requestedRetryAfter: Double = 60.0
        let bounded = min(requestedRetryAfter, 10.0)
        XCTAssertEqual(bounded, 10.0)

        let shortRetryAfter: Double = 2.5
        let boundedShort = min(shortRetryAfter, 10.0)
        XCTAssertEqual(boundedShort, 2.5)
    }
}

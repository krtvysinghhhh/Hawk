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
}

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
}

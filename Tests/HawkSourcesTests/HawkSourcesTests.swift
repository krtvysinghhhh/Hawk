import XCTest
@testable import HawkSources
@testable import HawkCore

final class HawkSourcesTests: XCTestCase {

    func testExactMatch() {
        let score = TrackMatcher.matchScore(
            titleA: "Starboy",
            artistA: "The Weeknd",
            durationA: 230.0,
            titleB: "Starboy",
            artistB: "The Weeknd",
            durationB: 231.0
        )
        XCTAssertGreaterThanOrEqual(score, 0.9)
    }

    func testDurationMismatch() {
        let score = TrackMatcher.matchScore(
            titleA: "Hotel California",
            artistA: "Eagles",
            durationA: 391.0,
            titleB: "Hotel California (Live Acoustic)",
            artistB: "Eagles",
            durationB: 450.0
        )
        XCTAssertLessThan(score, 0.7)
    }

    func testLocalLibrarySource() {
        let source = LocalLibrarySource()
        XCTAssertEqual(source.sourceId, "local")
        XCTAssertEqual(source.displayName, "Local Files")
    }
}

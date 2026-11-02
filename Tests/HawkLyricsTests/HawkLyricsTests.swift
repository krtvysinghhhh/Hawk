import XCTest
@testable import HawkLyrics
@testable import HawkCore

final class HawkLyricsTests: XCTestCase {

    func testLrcParser() {
        let sampleLrc = """
        [00:12.50]Line 1 of song
        [01:05.123]Line 2 of song with millis
        [02:30]Line 3 integer seconds
        """

        let lines = LrcParser.parse(sampleLrc)
        XCTAssertEqual(lines.count, 3)

        XCTAssertEqual(lines[0].timestamp, 12.5, accuracy: 0.01)
        XCTAssertEqual(lines[0].text, "Line 1 of song")

        XCTAssertEqual(lines[1].timestamp, 65.123, accuracy: 0.01)
        XCTAssertEqual(lines[1].text, "Line 2 of song with millis")

        XCTAssertEqual(lines[2].timestamp, 150.0, accuracy: 0.01)
        XCTAssertEqual(lines[2].text, "Line 3 integer seconds")
    }

    func testMalformedLrc() {
        let sample = """
        [ti:Track Title]
        [ar:Artist Name]
        [al:Album Name]
        [00:05.00]First real line
        """
        let lines = LrcParser.parse(sample)
        XCTAssertEqual(lines.count, 1)
        XCTAssertEqual(lines[0].text, "First real line")
    }
}

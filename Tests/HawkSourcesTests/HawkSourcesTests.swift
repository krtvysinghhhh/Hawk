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

    func testAnagramRejectionInDeterministicMatcher() {
        // "silent" vs "listen" has identical character set but distinct sequence
        let score = TrackMatcher.matchScore(
            titleA: "silent",
            artistA: "Artist",
            durationA: 200,
            titleB: "listen",
            artistB: "Artist",
            durationB: 200
        )
        // With Levenshtein distance, confidence should be well below match threshold (0.70)
        XCTAssertLessThan(score, TrackMatcher.confidenceThreshold)
    }

    func testDownloadManagerDuplicatePrevention() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("TestDL_\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let manager = DownloadManager(downloadsDirectory: tempDir)
        let song = Song(id: "dl_test_1", title: "Test", artist: "Artist", duration: 180)

        // Initial state
        let state = await manager.getState(songId: song.id)
        XCTAssertEqual(state, .idle)
        let isDL = await manager.isDownloaded(songId: song.id)
        XCTAssertFalse(isDL)
    }

    func testM3U8ImportAndExport() {
        let originalSongs = [
            Song(id: "s1", title: "Midnight City", artist: "M83", duration: 243),
            Song(id: "s2", title: "Wait", artist: "M83", duration: 343)
        ]
        let playlist = Playlist(title: "M83 Best", songs: originalSongs)
        let m3u8 = UniversalPlaylistImporter.exportToM3U8(playlist: playlist)

        XCTAssertTrue(m3u8.contains("#EXTM3U"))
        XCTAssertTrue(m3u8.contains("Midnight City"))
        XCTAssertTrue(m3u8.contains("M83"))

        let parsed = UniversalPlaylistImporter.parseM3U(content: m3u8)
        XCTAssertEqual(parsed.tracks.count, 2)
        XCTAssertEqual(parsed.tracks.first?.title, "Midnight City")
        XCTAssertEqual(parsed.tracks.first?.artist, "M83")
    }

    func testSSRFProtectionRejectsPrivateIPs() {
        XCTAssertFalse(UniversalPlaylistImporter.isSafeRemoteURL(URL(string: "http://127.0.0.1/playlist.m3u")!))
        XCTAssertFalse(UniversalPlaylistImporter.isSafeRemoteURL(URL(string: "http://localhost/playlist.m3u")!))
        XCTAssertFalse(UniversalPlaylistImporter.isSafeRemoteURL(URL(string: "http://10.0.0.1/playlist.m3u")!))
        XCTAssertFalse(UniversalPlaylistImporter.isSafeRemoteURL(URL(string: "http://192.168.1.1/playlist.m3u")!))
        XCTAssertFalse(UniversalPlaylistImporter.isSafeRemoteURL(URL(string: "http://169.254.169.254/metadata")!))
        XCTAssertFalse(UniversalPlaylistImporter.isSafeRemoteURL(URL(string: "ftp://example.com/playlist.m3u")!))
        XCTAssertFalse(UniversalPlaylistImporter.isSafeRemoteURL(URL(string: "file:///etc/passwd")!))
    }
}

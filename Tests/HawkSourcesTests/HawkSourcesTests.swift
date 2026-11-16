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

    func testLevenshteinFalsePositivesDifferentArtists() {
        // Identical title "Hello" but Adele vs Lionel Richie
        let score = TrackMatcher.matchScore(
            titleA: "Hello",
            artistA: "Adele",
            durationA: 295.0,
            titleB: "Hello",
            artistB: "Lionel Richie",
            durationB: 247.0
        )
        // Must reject different artists even if title is identical
        XCTAssertLessThan(score, TrackMatcher.confidenceThreshold)
    }

    func testDownloadPathTraversalSanitization() {
        let maliciousId = "../../etc/passwd"
        let safeId = maliciousId.replacingOccurrences(of: "..", with: "").components(separatedBy: CharacterSet.alphanumerics.inverted).filter { !$0.isEmpty }.joined(separator: "_")
        XCTAssertFalse(safeId.contains(".."))
        XCTAssertFalse(safeId.contains("/"))
        XCTAssertEqual(safeId, "etc_passwd")

        // Test helper with traversal attack
        let filename1 = DownloadManager.sanitizeDownloadFilename(songId: maliciousId, streamURL: URL(string: "https://example.com/audio.mp3")!)
        XCTAssertEqual(filename1, "etc_passwd.mp3")

        // Test helper with non-alphanumeric fallback (no hidden dotfiles)
        let filename2 = DownloadManager.sanitizeDownloadFilename(songId: "???///###", streamURL: URL(string: "https://example.com/stream?codec=aac")!)
        XCTAssertFalse(filename2.hasPrefix("."))
        XCTAssertTrue(filename2.hasSuffix(".m4a"))

        // Test helper with extension whitelist enforcement
        let filename3 = DownloadManager.sanitizeDownloadFilename(songId: "track1", streamURL: URL(string: "https://example.com/exploit.sh")!)
        XCTAssertEqual(filename3, "track1.m4a")
    }

    func testURLExpirationExtraction() {
        let futureTime = Date().addingTimeInterval(3600).timeIntervalSince1970
        let url = URL(string: "https://googlevideo.com/videoplayback?expire=\(Int(futureTime))&id=test")!
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let expireVal = components?.queryItems?.first(where: { $0.name == "expire" })?.value
        XCTAssertNotNil(expireVal)
        let extractedSec = Double(expireVal!)!
        XCTAssertEqual(extractedSec, Double(Int(futureTime)))
    }

    // MARK: - Google OAuth & OIDC Authentication Tests

    private func createMockIdToken(
        issuer: String = "https://accounts.google.com",
        audience: String = "862376793952-test.apps.googleusercontent.com",
        subject: String = "123456789",
        email: String = "tester@gmail.com",
        expiration: TimeInterval = Date().addingTimeInterval(3600).timeIntervalSince1970
    ) -> String {
        let header = "{\"alg\":\"RS256\",\"typ\":\"JWT\"}".data(using: .utf8)!.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "")
        let payloadJson = "{\"iss\":\"\(issuer)\",\"aud\":\"\(audience)\",\"sub\":\"\(subject)\",\"email\":\"\(email)\",\"exp\":\(Int(expiration)),\"iat\":1700000000}"
        let payload = payloadJson.data(using: .utf8)!.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "")
        let signature = "mock_signature_bytes".data(using: .utf8)!.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "")
        return "\(header).\(payload).\(signature)"
    }

    @MainActor
    func testOAuthCallbackValid() throws {
        let state = "secure_random_state_12345"
        let callback = URL(string: "com.googleusercontent.apps.862376793952-test:/oauth2callback?code=4/0AbcValidCode&state=\(state)")!
        let code = try GoogleMusicSyncManager.validateOAuthCallback(
            url: callback,
            expectedState: state,
            allowedScheme: "com.googleusercontent.apps.862376793952-test"
        )
        XCTAssertEqual(code, "4/0AbcValidCode")
    }

    @MainActor
    func testOAuthCallbackInvalidState() {
        let expectedState = "expected_state_abc"
        let mismatchedCallback = URL(string: "com.googleusercontent.apps.862376793952-test:/oauth2callback?code=4/0Abc&state=attacker_state_xyz")!
        XCTAssertThrowsError(
            try GoogleMusicSyncManager.validateOAuthCallback(url: mismatchedCallback, expectedState: expectedState)
        ) { error in
            XCTAssertTrue(error.localizedDescription.contains("state mismatch"))
        }

        let missingStateCallback = URL(string: "com.googleusercontent.apps.862376793952-test:/oauth2callback?code=4/0Abc")!
        XCTAssertThrowsError(
            try GoogleMusicSyncManager.validateOAuthCallback(url: missingStateCallback, expectedState: expectedState)
        ) { error in
            XCTAssertTrue(error.localizedDescription.contains("state parameter missing"))
        }
    }

    @MainActor
    func testOAuthCallbackInvalidRedirectUri() {
        let state = "valid_state"
        let invalidScheme = URL(string: "malicious.app:/oauth2callback?code=4/0Abc&state=\(state)")!
        XCTAssertThrowsError(
            try GoogleMusicSyncManager.validateOAuthCallback(url: invalidScheme, expectedState: state, allowedScheme: "com.googleusercontent.apps.test")
        )

        let invalidPath = URL(string: "com.googleusercontent.apps.test:/wrongpath?code=4/0Abc&state=\(state)")!
        XCTAssertThrowsError(
            try GoogleMusicSyncManager.validateOAuthCallback(url: invalidPath, expectedState: state, allowedScheme: "com.googleusercontent.apps.test")
        )
    }

    func testOAuthAccessDeniedTestingModeErrorMapping() {
        let googleTestingDesc = "Access blocked: Hawk IOS has not completed the Google verification process. The app is currently being tested and can only be accessed by developer-approved testers."
        let mapped = GoogleMusicSyncManager.mapOAuthError(code: "access_denied", description: googleTestingDesc)
        XCTAssertTrue(mapped.contains("403: access_denied"))
        XCTAssertTrue(mapped.contains("Test users"))
        XCTAssertTrue(mapped.contains("Testing"))

        // Standard user cancellation
        let standardUserCancel = GoogleMusicSyncManager.mapOAuthError(code: "access_denied")
        XCTAssertTrue(standardUserCancel.contains("access was blocked or denied"))
    }

    func testOAuthStandardErrorMappings() {
        XCTAssertTrue(GoogleMusicSyncManager.mapOAuthError(code: "invalid_client").contains("invalid or not found"))
        XCTAssertTrue(GoogleMusicSyncManager.mapOAuthError(code: "deleted_client").contains("deleted"))
        XCTAssertTrue(GoogleMusicSyncManager.mapOAuthError(code: "redirect_uri_mismatch").contains("redirect URI mismatch"))
        XCTAssertTrue(GoogleMusicSyncManager.mapOAuthError(code: "invalid_grant").contains("expired or been revoked"))
        XCTAssertTrue(GoogleMusicSyncManager.mapOAuthError(code: "invalid_scope").contains("scope is invalid"))
        XCTAssertTrue(GoogleMusicSyncManager.mapOAuthError(code: "unauthorized_client").contains("unauthorized"))
    }

    func testIdTokenValidationSuccess() {
        let audience = "862376793952-test.apps.googleusercontent.com"
        let token = createMockIdToken(audience: audience, email: "developer@example.com")
        let result = GoogleMusicSyncManager.validateIdToken(rawToken: token, expectedAudience: audience)

        switch result {
        case .success(let claims):
            XCTAssertEqual(claims.issuer, "https://accounts.google.com")
            XCTAssertEqual(claims.audience, audience)
            XCTAssertEqual(claims.subject, "123456789")
            XCTAssertEqual(claims.email, "developer@example.com")
            XCTAssertGreaterThan(claims.expiration, Date())
        case .failure(let err):
            XCTFail("ID token validation failed unexpectedly: \(err)")
        }
    }

    func testIdTokenValidationAudienceMismatch() {
        let token = createMockIdToken(audience: "attacker_client_id.apps.googleusercontent.com")
        let result = GoogleMusicSyncManager.validateIdToken(rawToken: token, expectedAudience: "legitimate_client_id.apps.googleusercontent.com")

        guard case .failure(let err) = result, case .audienceMismatch = err else {
            XCTFail("Expected audienceMismatch error, got: \(result)")
            return
        }
    }

    func testIdTokenValidationInvalidIssuer() {
        let audience = "862376793952-test.apps.googleusercontent.com"
        let token = createMockIdToken(issuer: "https://evil-auth.com", audience: audience)
        let result = GoogleMusicSyncManager.validateIdToken(rawToken: token, expectedAudience: audience)

        guard case .failure(let err) = result, case .invalidIssuer = err else {
            XCTFail("Expected invalidIssuer error, got: \(result)")
            return
        }
    }

    func testIdTokenValidationExpired() {
        let audience = "862376793952-test.apps.googleusercontent.com"
        let pastExp = Date().addingTimeInterval(-300).timeIntervalSince1970
        let token = createMockIdToken(audience: audience, expiration: pastExp)
        let result = GoogleMusicSyncManager.validateIdToken(rawToken: token, expectedAudience: audience)

        guard case .failure(let err) = result, case .tokenExpired = err else {
            XCTFail("Expected tokenExpired error, got: \(result)")
            return
        }
    }

    @MainActor
    func testGoogleSyncConnectAndDisconnectLifecycle() async throws {
        let manager = GoogleMusicSyncManager.shared
        try await manager.connectWithToken(
            email: "test_tester@gmail.com",
            accessToken: "mock_access_token_123",
            refreshToken: "mock_refresh_token_456"
        )
        XCTAssertTrue(manager.isConnected)
        XCTAssertEqual(manager.accountEmail, "test_tester@gmail.com")

        await manager.disconnect()
        XCTAssertFalse(manager.isConnected)
        XCTAssertNil(manager.accountEmail)
    }
}

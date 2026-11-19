import XCTest
import Security
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

    // MARK: - Google OAuth & Cryptographic OIDC Authentication Tests

    private static let testRsaKeyId = "hawk-test-key-2026"
    private static let (testPrivateKey, testPublicKey): (SendableSecKey, SendableSecKey) = {
        let attrs: [CFString: Any] = [
            kSecAttrKeyType: kSecAttrKeyTypeRSA,
            kSecAttrKeySizeInBits: 2048
        ]
        var err: Unmanaged<CFError>?
        let priv = SecKeyCreateRandomKey(attrs as CFDictionary, &err)!
        let pub = SecKeyCopyPublicKey(priv)!
        return (SendableSecKey(priv), SendableSecKey(pub))
    }()

    private static func testKeyResolver(kid: String) async throws -> SendableSecKey? {
        if kid == Self.testRsaKeyId {
            return Self.testPublicKey
        }
        return nil
    }

    private func createSignedTestIdToken(
        keyId: String? = testRsaKeyId,
        alg: String = "RS256",
        issuer: String = "https://accounts.google.com",
        audience: String = "862376793952-test.apps.googleusercontent.com",
        subject: String = "123456789",
        email: String? = "tester@gmail.com",
        nonce: String? = nil,
        expiration: TimeInterval = Date().addingTimeInterval(3600).timeIntervalSince1970,
        issuedAt: TimeInterval = Date().timeIntervalSince1970,
        signWithKey: SecKey? = nil,
        corruptSignature: Bool = false
    ) -> String {
        let activeKey = signWithKey ?? Self.testPrivateKey.rawKey
        var headerDict: [String: Any] = ["alg": alg, "typ": "JWT"]
        if let kid = keyId {
            headerDict["kid"] = kid
        }
        let headerData = try! JSONSerialization.data(withJSONObject: headerDict)
        let headerB64 = GoogleMusicSyncManager.base64UrlEncode(headerData)

        var payloadDict: [String: Any] = [
            "iss": issuer,
            "aud": audience,
            "sub": subject,
            "exp": expiration,
            "iat": issuedAt
        ]
        if let email = email {
            payloadDict["email"] = email
            payloadDict["email_verified"] = true
        }
        if let nonce = nonce {
            payloadDict["nonce"] = nonce
        }
        let payloadData = try! JSONSerialization.data(withJSONObject: payloadDict)
        let payloadB64 = GoogleMusicSyncManager.base64UrlEncode(payloadData)

        let signingInput = "\(headerB64).\(payloadB64)".data(using: .ascii)!

        let signatureB64: String
        if alg == "RS256" {
            var err: Unmanaged<CFError>?
            let sigData = SecKeyCreateSignature(activeKey, .rsaSignatureMessagePKCS1v15SHA256, signingInput as CFData, &err)! as Data
            if corruptSignature {
                var corrupted = sigData
                corrupted[0] ^= 0xFF
                signatureB64 = GoogleMusicSyncManager.base64UrlEncode(corrupted)
            } else {
                signatureB64 = GoogleMusicSyncManager.base64UrlEncode(sigData)
            }
        } else {
            signatureB64 = GoogleMusicSyncManager.base64UrlEncode("mock_dummy_signature".data(using: .utf8)!)
        }

        return "\(headerB64).\(payloadB64).\(signatureB64)"
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

    func testIdTokenValidationSuccess() async {
        let audience = "862376793952-test.apps.googleusercontent.com"
        let token = createSignedTestIdToken(audience: audience, email: "developer@example.com", nonce: "test_nonce_123")
        let result = await GoogleMusicSyncManager.validateIdToken(
            rawToken: token,
            expectedAudience: audience,
            expectedNonce: "test_nonce_123",
            customKeyResolver: Self.testKeyResolver
        )

        switch result {
        case .success(let claims):
            XCTAssertEqual(claims.issuer, "https://accounts.google.com")
            XCTAssertEqual(claims.audience, audience)
            XCTAssertEqual(claims.subject, "123456789")
            XCTAssertEqual(claims.email, "developer@example.com")
            XCTAssertTrue(claims.emailVerified)
            XCTAssertEqual(claims.nonce, "test_nonce_123")
            XCTAssertGreaterThan(claims.expiration, Date())
        case .failure(let err):
            XCTFail("ID token validation failed unexpectedly: \(err)")
        }
    }

    func testIdTokenValidationInvalidSignature() async {
        let audience = "862376793952-test.apps.googleusercontent.com"
        let token = createSignedTestIdToken(audience: audience, corruptSignature: true)
        let result = await GoogleMusicSyncManager.validateIdToken(
            rawToken: token,
            expectedAudience: audience,
            customKeyResolver: Self.testKeyResolver
        )

        guard case .failure(let err) = result, case .invalidSignature = err else {
            XCTFail("Expected .invalidSignature error, got: \(result)")
            return
        }
    }

    func testIdTokenValidationAlteredPayload() async {
        let audience = "862376793952-test.apps.googleusercontent.com"
        let token = createSignedTestIdToken(audience: audience, email: "legit@example.com")
        let parts = token.components(separatedBy: ".")
        XCTAssertEqual(parts.count, 3)

        // Attacker alters payload claim
        let tamperedPayload = GoogleMusicSyncManager.base64UrlEncode(
            "{\"iss\":\"https://accounts.google.com\",\"aud\":\"\(audience)\",\"sub\":\"123456789\",\"email\":\"attacker@evil.com\",\"exp\":\(Date().addingTimeInterval(3600).timeIntervalSince1970),\"iat\":\(Date().timeIntervalSince1970)}".data(using: .utf8)!
        )
        let tamperedToken = "\(parts[0]).\(tamperedPayload).\(parts[2])"

        let result = await GoogleMusicSyncManager.validateIdToken(
            rawToken: tamperedToken,
            expectedAudience: audience,
            customKeyResolver: Self.testKeyResolver
        )

        guard case .failure(let err) = result, case .invalidSignature = err else {
            XCTFail("Expected .invalidSignature for altered payload, got: \(result)")
            return
        }
    }

    func testIdTokenValidationUnknownKeyId() async {
        let audience = "862376793952-test.apps.googleusercontent.com"
        let token = createSignedTestIdToken(keyId: "unknown-kid-999", audience: audience)
        let result = await GoogleMusicSyncManager.validateIdToken(
            rawToken: token,
            expectedAudience: audience,
            customKeyResolver: Self.testKeyResolver
        )

        guard case .failure(let err) = result, case .unknownSigningKey(let kid) = err, kid == "unknown-kid-999" else {
            XCTFail("Expected .unknownSigningKey('unknown-kid-999'), got: \(result)")
            return
        }
    }

    func testIdTokenValidationMissingKeyId() async {
        let audience = "862376793952-test.apps.googleusercontent.com"
        let token = createSignedTestIdToken(keyId: nil, audience: audience)
        let result = await GoogleMusicSyncManager.validateIdToken(
            rawToken: token,
            expectedAudience: audience,
            customKeyResolver: Self.testKeyResolver
        )

        guard case .failure(let err) = result, case .missingKeyId = err else {
            XCTFail("Expected .missingKeyId, got: \(result)")
            return
        }
    }

    func testIdTokenValidationAlgorithmNoneRejected() async {
        let audience = "862376793952-test.apps.googleusercontent.com"
        let token = createSignedTestIdToken(alg: "none", audience: audience)
        let result = await GoogleMusicSyncManager.validateIdToken(
            rawToken: token,
            expectedAudience: audience,
            customKeyResolver: Self.testKeyResolver
        )

        guard case .failure(let err) = result, case .algorithmNoneRejected = err else {
            XCTFail("Expected .algorithmNoneRejected, got: \(result)")
            return
        }
    }

    func testIdTokenValidationUnsupportedAlgorithm() async {
        let audience = "862376793952-test.apps.googleusercontent.com"
        let token = createSignedTestIdToken(alg: "HS256", audience: audience)
        let result = await GoogleMusicSyncManager.validateIdToken(
            rawToken: token,
            expectedAudience: audience,
            customKeyResolver: Self.testKeyResolver
        )

        guard case .failure(let err) = result, case .unsupportedAlgorithm(let alg) = err, alg == "HS256" else {
            XCTFail("Expected .unsupportedAlgorithm('HS256'), got: \(result)")
            return
        }
    }

    func testIdTokenValidationAudienceMismatch() async {
        let token = createSignedTestIdToken(audience: "attacker_client_id.apps.googleusercontent.com")
        let result = await GoogleMusicSyncManager.validateIdToken(
            rawToken: token,
            expectedAudience: "legitimate_client_id.apps.googleusercontent.com",
            customKeyResolver: Self.testKeyResolver
        )

        guard case .failure(let err) = result, case .audienceMismatch = err else {
            XCTFail("Expected audienceMismatch error, got: \(result)")
            return
        }
    }

    func testIdTokenValidationInvalidIssuer() async {
        let audience = "862376793952-test.apps.googleusercontent.com"
        let token = createSignedTestIdToken(issuer: "https://evil-auth.com", audience: audience)
        let result = await GoogleMusicSyncManager.validateIdToken(
            rawToken: token,
            expectedAudience: audience,
            customKeyResolver: Self.testKeyResolver
        )

        guard case .failure(let err) = result, case .invalidIssuer = err else {
            XCTFail("Expected invalidIssuer error, got: \(result)")
            return
        }
    }

    func testIdTokenValidationExpired() async {
        let audience = "862376793952-test.apps.googleusercontent.com"
        let pastExp = Date().addingTimeInterval(-300).timeIntervalSince1970
        let token = createSignedTestIdToken(audience: audience, expiration: pastExp)
        let result = await GoogleMusicSyncManager.validateIdToken(
            rawToken: token,
            expectedAudience: audience,
            customKeyResolver: Self.testKeyResolver
        )

        guard case .failure(let err) = result, case .tokenExpired = err else {
            XCTFail("Expected tokenExpired error, got: \(result)")
            return
        }
    }

    func testIdTokenValidationNonceMismatch() async {
        let audience = "862376793952-test.apps.googleusercontent.com"
        let token = createSignedTestIdToken(audience: audience, nonce: "token_nonce_123")
        let result = await GoogleMusicSyncManager.validateIdToken(
            rawToken: token,
            expectedAudience: audience,
            expectedNonce: "expected_nonce_456",
            customKeyResolver: Self.testKeyResolver
        )

        guard case .failure(let err) = result, case .nonceMismatch(let expected, let actual) = err else {
            XCTFail("Expected nonceMismatch error, got: \(result)")
            return
        }
        XCTAssertEqual(expected, "expected_nonce_456")
        XCTAssertEqual(actual, "token_nonce_123")
    }

    func testJwksDerPublicKeyParsingAndVerification() throws {
        // Export test public key bytes
        var error: Unmanaged<CFError>?
        guard let pubData = SecKeyCopyExternalRepresentation(Self.testPublicKey.rawKey, &error) as Data? else {
            XCTFail("Failed to export public key representation")
            return
        }
        // In PKCS#1 DER format:
        // Tag 0x30 [len] Tag 0x02 [len] [modulus] Tag 0x02 [len] [exponent]
        // Modulus starts after seq header (4 bytes) and int header (4 bytes + 1 byte for 0x00) -> 256 bytes
        let modulus = pubData.subdata(in: 9..<9+256)
        let exponent = pubData.suffix(3)

        guard let reconstructed = GoogleJwksService.createRsaPublicKey(modulus: modulus, exponent: exponent) else {
            XCTFail("Failed to reconstruct RSA SecKey from modulus and exponent")
            return
        }

        let message = "testing DER parsing".data(using: .utf8)!
        guard let sig = SecKeyCreateSignature(Self.testPrivateKey.rawKey, .rsaSignatureMessagePKCS1v15SHA256, message as CFData, &error) as Data? else {
            XCTFail("Failed to sign message")
            return
        }

        let verified = SecKeyVerifySignature(reconstructed, .rsaSignatureMessagePKCS1v15SHA256, message as CFData, sig as CFData, &error)
        XCTAssertTrue(verified)
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

    func testArtworkResolutionURLUpgrades() {
        let saavn150 = URL(string: "https://c.saavncdn.com/123/song-150x150.jpg")!
        let saavnUpgraded = ArtworkResolver.upgradeResolution(of: saavn150)
        XCTAssertEqual(saavnUpgraded.absoluteString, "https://c.saavncdn.com/123/song-500x500.jpg")

        let saavn50 = URL(string: "https://c.saavncdn.com/123/song-50x50.jpg")!
        let saavn50Upgraded = ArtworkResolver.upgradeResolution(of: saavn50)
        XCTAssertEqual(saavn50Upgraded.absoluteString, "https://c.saavncdn.com/123/song-500x500.jpg")

        let ytDefault = URL(string: "https://i.ytimg.com/vi/abc123xyz/default.jpg")!
        let ytUpgraded = ArtworkResolver.upgradeResolution(of: ytDefault)
        XCTAssertEqual(ytUpgraded.absoluteString, "https://i.ytimg.com/vi/abc123xyz/maxresdefault.jpg")

        let appleMusic = URL(string: "https://is1-ssl.mzstatic.com/image/thumb/Music123/v4/100x100bb.jpg")!
        let appleUpgraded = ArtworkResolver.upgradeResolution(of: appleMusic)
        XCTAssertEqual(appleUpgraded.absoluteString, "https://is1-ssl.mzstatic.com/image/thumb/Music123/v4/600x600bb.jpg")
    }

    func testArtworkResolverCachingAndPruning() async {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("ArtworkTest_\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let resolver = ArtworkResolver(customCacheDirectory: tempDir)
        let dummyURL = URL(string: "https://c.saavncdn.com/test/dummy-150x150.jpg")!

        let resolved = await resolver.resolveArtworkURL(for: Song(id: "art_1", title: "T", artist: "A", duration: 100, artworkURL: dummyURL))
        XCTAssertEqual(resolved?.absoluteString, "https://c.saavncdn.com/test/dummy-500x500.jpg")

        // Test clear caches
        await resolver.clearMemoryCache()
        await resolver.clearDiskCache()
        let size = await resolver.diskCacheSize()
        XCTAssertEqual(size, 0)
    }

    func testParseLikedVideosResponseFiltersNonMusicCategories() throws {
        let jsonString = """
        {
            "nextPageToken": "next_page_token_abc",
            "items": [
                {
                    "id": "song_valid_1",
                    "snippet": {
                        "title": "Blinding Lights",
                        "videoOwnerChannelTitle": "The Weeknd - Topic",
                        "categoryId": "10",
                        "thumbnails": {
                            "high": { "url": "https://i.ytimg.com/vi/song_valid_1/hqdefault.jpg" }
                        }
                    },
                    "contentDetails": {
                        "duration": "PT3M20S"
                    }
                },
                {
                    "id": "gameplay_vid_2",
                    "snippet": {
                        "title": "GTA 6 Gameplay Walkthrough Part 1",
                        "channelTitle": "Gamer123",
                        "categoryId": "20",
                        "thumbnails": {
                            "high": { "url": "https://i.ytimg.com/vi/gameplay_vid_2/hqdefault.jpg" }
                        }
                    },
                    "contentDetails": {
                        "duration": "PT15M30S"
                    }
                },
                {
                    "id": "vlog_vid_3",
                    "snippet": {
                        "title": "Daily Vlog in Tokyo Japan",
                        "channelTitle": "Traveler",
                        "categoryId": "22",
                        "thumbnails": {
                            "high": { "url": "https://i.ytimg.com/vi/vlog_vid_3/hqdefault.jpg" }
                        }
                    },
                    "contentDetails": {
                        "duration": "PT10M00S"
                    }
                },
                {
                    "id": "podcast_vid_4",
                    "snippet": {
                        "title": "AI Technology Podcast Episode 42",
                        "channelTitle": "Tech Channel",
                        "categoryId": "10",
                        "thumbnails": {
                            "high": { "url": "https://i.ytimg.com/vi/podcast_vid_4/hqdefault.jpg" }
                        }
                    },
                    "contentDetails": {
                        "duration": "PT45M12S"
                    }
                },
                {
                    "id": "deleted_vid_5",
                    "snippet": {
                        "title": "Deleted video",
                        "channelTitle": "Unknown",
                        "categoryId": "10"
                    }
                }
            ]
        }
        """

        guard let data = jsonString.data(using: .utf8) else {
            XCTFail("Failed to encode test JSON")
            return
        }

        let result = try GoogleMusicSyncManager.parseLikedVideosResponse(data: data)
        XCTAssertEqual(result.nextPageToken, "next_page_token_abc")

        // Only the valid music song (category 10, no non-music keywords, not deleted) must be accepted
        XCTAssertEqual(result.songs.count, 1)
        let accepted = result.songs[0]
        XCTAssertEqual(accepted.id, "song_valid_1")
        XCTAssertEqual(accepted.title, "Blinding Lights")
        XCTAssertEqual(accepted.artist, "The Weeknd")
        XCTAssertEqual(accepted.duration, 200) // 3 mins 20 secs = 200 seconds
        XCTAssertEqual(accepted.artworkURL?.absoluteString, "https://i.ytimg.com/vi/song_valid_1/hqdefault.jpg")
    }

    func testParseISO8601Duration() {
        XCTAssertEqual(GoogleMusicSyncManager.parseISO8601Duration("PT3M20S"), 200)
        XCTAssertEqual(GoogleMusicSyncManager.parseISO8601Duration("PT1H2M10S"), 3730)
        XCTAssertEqual(GoogleMusicSyncManager.parseISO8601Duration("PT45S"), 45)
        XCTAssertEqual(GoogleMusicSyncManager.parseISO8601Duration("PT4M"), 240)
        XCTAssertEqual(GoogleMusicSyncManager.parseISO8601Duration("PT1H"), 3600)
        XCTAssertEqual(GoogleMusicSyncManager.parseISO8601Duration("invalid"), 0)
        XCTAssertEqual(GoogleMusicSyncManager.parseISO8601Duration(""), 0)
    }

    func testIdTokenValidationMalformedJWT() async {
        let audience = "862376793952-test.apps.googleusercontent.com"

        // 1. Empty string
        let emptyResult = await GoogleMusicSyncManager.validateIdToken(
            rawToken: "",
            expectedAudience: audience,
            customKeyResolver: Self.testKeyResolver
        )
        guard case .failure(let err1) = emptyResult, case .malformedJwt = err1 else {
            XCTFail("Expected malformedJwt on empty string, got: \(emptyResult)")
            return
        }

        // 2. Single token segment without dots
        let singleSegment = await GoogleMusicSyncManager.validateIdToken(
            rawToken: "not_a_valid_jwt_token",
            expectedAudience: audience,
            customKeyResolver: Self.testKeyResolver
        )
        guard case .failure(let err2) = singleSegment, case .malformedJwt = err2 else {
            XCTFail("Expected malformedJwt on single segment, got: \(singleSegment)")
            return
        }

        // 3. Two segments without signature
        let twoSegments = await GoogleMusicSyncManager.validateIdToken(
            rawToken: "header.payload",
            expectedAudience: audience,
            customKeyResolver: Self.testKeyResolver
        )
        guard case .failure(let err3) = twoSegments, case .malformedJwt = err3 else {
            XCTFail("Expected malformedJwt on 2 segments, got: \(twoSegments)")
            return
        }
    }

    func testIdTokenValidationKeyResolverFailure() async {
        let audience = "862376793952-test.apps.googleusercontent.com"
        let token = createSignedTestIdToken(audience: audience, email: "dev@example.com")

        // Fail-closed test: custom resolver simulates network failure by returning nil
        let networkFailureResolver: @Sendable (String) async throws -> SendableSecKey? = { _ in nil }

        let result = await GoogleMusicSyncManager.validateIdToken(
            rawToken: token,
            expectedAudience: audience,
            customKeyResolver: networkFailureResolver
        )

        guard case .failure(let err) = result, case .unknownSigningKey(let kid) = err else {
            XCTFail("Expected unknownSigningKey on network resolver failure, got: \(result)")
            return
        }
        XCTAssertEqual(kid, Self.testRsaKeyId)
    }
}

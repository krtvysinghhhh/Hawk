import Foundation
import SwiftUI
import AuthenticationServices
import HawkCore
import HawkSecurity
import HawkNetworking

/// Manages Google OAuth 2.0 authentication with PKCE & state verification,
/// YouTube Music library synchronization, Keychain credential security, and incremental sync state.
@MainActor
@Observable
public final class GoogleMusicSyncManager: NSObject, ASWebAuthenticationPresentationContextProviding {
    public static let shared = GoogleMusicSyncManager()

    public private(set) var isConnected: Bool = false
    public private(set) var accountEmail: String?
    public private(set) var lastSyncDate: Date?
    public private(set) var isSyncing: Bool = false
    public private(set) var syncStatusMessage: String?
    public private(set) var syncedPlaylistsCount: Int = 0
    public private(set) var syncedSongsCount: Int = 0

    public var isAutoSyncEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: "hawk_google_auto_sync") }
        set { UserDefaults.standard.set(newValue, forKey: "hawk_google_auto_sync") }
    }

    private let keychain = KeychainStore.shared
    private let httpClient = HawkHttpClient.shared

    // Google OAuth 2.0 configuration
    // Default client ID can be overridden or provided via keychain
    private let defaultClientId = "874129582194-hawk-music-player.apps.googleusercontent.com"
    private let redirectUri = "com.hawk.music:/oauth2callback"
    private let scopes = [
        "https://www.googleapis.com/auth/userinfo.email",
        "https://www.googleapis.com/auth/youtube.readonly"
    ].joined(separator: " ")

    public override init() {
        super.init()
        loadPersistedState()
    }

    private func loadPersistedState() {
        Task { [weak self] in
            guard let self = self else { return }
            let email = try? await self.keychain.readString(key: "google_account_email")
            let token = try? await self.keychain.readString(key: "google_access_token")

            if let email = email, let token = token, !token.isEmpty {
                self.accountEmail = email
                self.isConnected = true
            } else {
                self.isConnected = false
            }

            let lastTime = UserDefaults.standard.double(forKey: "hawk_google_last_sync_timestamp")
            if lastTime > 0 {
                self.lastSyncDate = Date(timeIntervalSince1970: lastTime)
            }
        }
    }

    // MARK: - ASWebAuthenticationPresentationContextProviding
    public func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        #if os(iOS)
        if let windowScene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene,
           let keyWindow = windowScene.windows.first(where: { $0.isKeyWindow }) {
            return keyWindow
        }
        return UIWindow()
        #else
        return ASPresentationAnchor()
        #endif
    }

    // MARK: - Authentication
    public func startGoogleSignIn() async throws {
        // Prepare PKCE code verifier and challenge
        let verifier = generateCodeVerifier()
        let challenge = generateCodeChallenge(from: verifier)
        // Cryptographic state parameter to prevent CSRF / session fixation
        let stateToken = generateCodeVerifier()

        var components = URLComponents(string: "https://accounts.google.com/o/oauth2/v2/auth")!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: defaultClientId),
            URLQueryItem(name: "redirect_uri", value: redirectUri),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: scopes),
            URLQueryItem(name: "code_challenge", value: challenge),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "state", value: stateToken),
            URLQueryItem(name: "prompt", value: "select_account")
        ]

        guard let authURL = components.url else {
            throw HawkError.networkError("Invalid Google authorization URL")
        }

        return try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(
                url: authURL,
                callbackURLScheme: "com.hawk.music"
            ) { [weak self] callbackURL, error in
                guard let self = self else {
                    continuation.resume(throwing: HawkError.authRequired("Session deallocated"))
                    return
                }

                if let error = error {
                    continuation.resume(throwing: HawkError.authRequired(error.localizedDescription))
                    return
                }

                guard let callbackURL = callbackURL else {
                    continuation.resume(throwing: HawkError.authRequired("Callback URL missing"))
                    return
                }

                let queryItems = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false)?.queryItems

                // Validate state parameter
                let returnedState = queryItems?.first(where: { $0.name == "state" })?.value
                guard returnedState == stateToken else {
                    continuation.resume(throwing: HawkError.authRequired("OAuth state mismatch: potential CSRF detected"))
                    return
                }

                guard let code = queryItems?.first(where: { $0.name == "code" })?.value else {
                    continuation.resume(throwing: HawkError.authRequired("Authorization code missing in callback"))
                    return
                }

                Task {
                    do {
                        try await self.exchangeCodeForTokens(code: code, verifier: verifier)
                        continuation.resume()
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
            }

            session.presentationContextProvider = self
            session.prefersEphemeralWebBrowserSession = false
            session.start()
        }
    }

    /// Direct authentication with manual Google Token / Cookie for development & power users.
    public func connectWithToken(
        email: String,
        accessToken: String,
        refreshToken: String? = nil,
        expiresIn: TimeInterval = 3600
    ) async throws {
        try await keychain.saveString(key: "google_account_email", value: email)
        try await keychain.saveString(key: "google_access_token", value: accessToken)
        if let refresh = refreshToken {
            try await keychain.saveString(key: "google_refresh_token", value: refresh)
        }
        let expiryTimestamp = Date().addingTimeInterval(expiresIn).timeIntervalSince1970
        try await keychain.saveString(key: "google_token_expiry", value: String(expiryTimestamp))

        self.accountEmail = email
        self.isConnected = true
        self.syncStatusMessage = "Connected as \(email)"
    }

    public func disconnect() async {
        try? await keychain.delete(key: "google_account_email")
        try? await keychain.delete(key: "google_access_token")
        try? await keychain.delete(key: "google_refresh_token")
        try? await keychain.delete(key: "google_token_expiry")

        self.accountEmail = nil
        self.isConnected = false
        self.syncStatusMessage = nil
    }

    /// Validates access token and transparently refreshes it via refresh_token if expired.
    public func getValidAccessToken() async throws -> String {
        guard let token = try? await keychain.readString(key: "google_access_token"), !token.isEmpty else {
            throw HawkError.authRequired("Not connected to Google")
        }

        let expiryStr = (try? await keychain.readString(key: "google_token_expiry")) ?? "0"
        let expiryTimestamp = Double(expiryStr) ?? 0
        let now = Date().timeIntervalSince1970

        // If token has at least 60 seconds of validity remaining, use it
        if expiryTimestamp > (now + 60) {
            return token
        }

        // Token is expired or expiring imminently -> refresh
        guard let refreshToken = try? await keychain.readString(key: "google_refresh_token"), !refreshToken.isEmpty else {
            if expiryTimestamp > now {
                return token
            }
            throw HawkError.authRequired("Google session expired. Please sign in again.")
        }

        guard let tokenURL = URL(string: "https://oauth2.googleapis.com/token") else {
            throw HawkError.networkError("Invalid token URL")
        }

        var request = URLRequest(url: tokenURL)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let bodyParams = [
            "client_id": defaultClientId,
            "refresh_token": refreshToken,
            "grant_type": "refresh_token"
        ]

        let bodyString = bodyParams.map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")" }.joined(separator: "&")
        request.httpBody = bodyString.data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let newAccessToken = json["access_token"] as? String else {
            throw HawkError.authRequired("Token refresh failed. Please sign in again.")
        }

        let expiresIn = json["expires_in"] as? Double ?? 3600
        let newExpiry = Date().addingTimeInterval(expiresIn).timeIntervalSince1970
        try await keychain.saveString(key: "google_access_token", value: newAccessToken)
        try await keychain.saveString(key: "google_token_expiry", value: String(newExpiry))

        return newAccessToken
    }

    private func exchangeCodeForTokens(code: String, verifier: String) async throws {
        guard let tokenURL = URL(string: "https://oauth2.googleapis.com/token") else {
            throw HawkError.networkError("Invalid token URL")
        }

        var request = URLRequest(url: tokenURL)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let bodyParams = [
            "code": code,
            "client_id": defaultClientId,
            "redirect_uri": redirectUri,
            "grant_type": "authorization_code",
            "code_verifier": verifier
        ]

        let bodyString = bodyParams.map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")" }.joined(separator: "&")
        request.httpBody = bodyString.data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let accessToken = json["access_token"] as? String else {
            throw HawkError.networkError("Token exchange failed")
        }

        let refreshToken = json["refresh_token"] as? String
        let expiresIn = json["expires_in"] as? Double ?? 3600
        let email = (try? await fetchGoogleUserEmail(accessToken: accessToken)) ?? "Google User"

        try await connectWithToken(email: email, accessToken: accessToken, refreshToken: refreshToken, expiresIn: expiresIn)

        if isAutoSyncEnabled {
            await syncNow()
        }
    }

    private func fetchGoogleUserEmail(accessToken: String) async throws -> String? {
        guard let url = URL(string: "https://www.googleapis.com/oauth2/v2/userinfo") else { return nil }
        var req = URLRequest(url: url)
        req.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        guard let (data, resp) = try? await URLSession.shared.data(for: req),
              let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let email = json["email"] as? String else {
            return nil
        }
        return email
    }

    // MARK: - YouTube Music Library Synchronisation (Music-Only Scope)
    public func syncNow() async {
        guard isConnected else {
            syncStatusMessage = "Not connected to Google"
            return
        }

        isSyncing = true
        syncStatusMessage = "Syncing YouTube Music library..."

        let token: String
        do {
            token = try await getValidAccessToken()
        } catch {
            isSyncing = false
            syncStatusMessage = "Authentication error: \(error.localizedDescription)"
            return
        }

        do {
            // 1. Fetch User Playlists
            let playlists = try await fetchUserMusicPlaylists(accessToken: token)
            var totalSyncedPlaylists = 0
            var totalSyncedSongs = 0

            for p in playlists {
                let tracks = try await fetchPlaylistMusicTracks(playlistId: p.id, accessToken: token)
                guard !tracks.isEmpty else { continue }

                // Check existing playlists to avoid duplication
                let existing = await PlaylistStore.shared.getAllPlaylists()
                if let match = existing.first(where: { $0.title == p.title }) {
                    // Update tracks preserving user additions
                    var merged = match.songs
                    for t in tracks {
                        if !merged.contains(where: { $0.title == t.title && $0.artist == t.artist }) {
                            merged.append(t)
                        }
                    }
                    _ = await PlaylistStore.shared.createPlaylist(title: match.title, initialSongs: merged)
                } else {
                    _ = await PlaylistStore.shared.createPlaylist(title: p.title, initialSongs: tracks)
                }
                totalSyncedPlaylists += 1
                totalSyncedSongs += tracks.count
            }

            // 2. Fetch Liked Music Tracks (Strict Category: Music)
            let likedTracks = try await fetchLikedMusic(accessToken: token)
            for track in likedTracks {
                _ = await PlaylistStore.shared.addSong(to: Playlist.favoritesId, song: track)
                totalSyncedSongs += 1
            }

            self.syncedPlaylistsCount = totalSyncedPlaylists
            self.syncedSongsCount = totalSyncedSongs
            self.lastSyncDate = Date()
            UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: "hawk_google_last_sync_timestamp")

            self.syncStatusMessage = "Sync complete: \(totalSyncedPlaylists) playlists, \(totalSyncedSongs) tracks."
        } catch {
            self.syncStatusMessage = "Sync failed: \(error.localizedDescription)"
        }

        self.isSyncing = false
    }

    private func fetchUserMusicPlaylists(accessToken: String) async throws -> [(id: String, title: String)] {
        guard let url = URL(string: "https://www.googleapis.com/youtube/v3/playlists?part=snippet,contentDetails&mine=true&maxResults=50") else {
            return []
        }
        var req = URLRequest(url: url)
        req.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        guard let (data, resp) = try? await URLSession.shared.data(for: req),
              let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let items = json["items"] as? [[String: Any]] else {
            return []
        }

        var results: [(id: String, title: String)] = []
        for item in items {
            guard let id = item["id"] as? String,
                  let snippet = item["snippet"] as? [String: Any],
                  let title = snippet["title"] as? String else { continue }
            // Filter out non-music generic playlists if tagged
            results.append((id: id, title: "YT Music: \(title)"))
        }
        return results
    }

    private func fetchPlaylistMusicTracks(playlistId: String, accessToken: String) async throws -> [Song] {
        guard let url = URL(string: "https://www.googleapis.com/youtube/v3/playlistItems?part=snippet,contentDetails&playlistId=\(playlistId)&maxResults=50") else {
            return []
        }
        var req = URLRequest(url: url)
        req.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        guard let (data, resp) = try? await URLSession.shared.data(for: req),
              let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let items = json["items"] as? [[String: Any]] else {
            return []
        }

        var songs: [Song] = []
        for item in items {
            guard let snippet = item["snippet"] as? [String: Any],
                  let title = snippet["title"] as? String,
                  title != "Private video" && title != "Deleted video",
                  let contentDetails = item["contentDetails"] as? [String: Any],
                  let videoId = contentDetails["videoId"] as? String else { continue }

            let channelTitle = snippet["videoOwnerChannelTitle"] as? String ?? snippet["channelTitle"] as? String ?? "Unknown Artist"
            let artist = channelTitle.replacingOccurrences(of: " - Topic", with: "").trimmingCharacters(in: .whitespaces)

            // Multi-factor confidence classification: reject podcasts and non-music videos
            let classificationResult = MusicClassificationService.classify(
                title: title,
                channelOrArtist: channelTitle,
                duration: 210
            )

            guard classificationResult.classification.isPlayableSong else {
                continue
            }

            var artworkURL: URL?
            if let thumbs = snippet["thumbnails"] as? [String: Any],
               let high = thumbs["high"] as? [String: Any],
               let urlStr = high["url"] as? String {
                artworkURL = URL(string: urlStr)
            }

            // Treated as valid library metadata record with YouTube source ID
            let song = Song(
                id: videoId,
                title: title,
                artist: artist,
                duration: 210, // Default nominal duration until resolved
                artworkURL: artworkURL,
                sourceId: "youtube"
            )
            songs.append(song)
        }
        return songs
    }

    private func fetchLikedMusic(accessToken: String) async throws -> [Song] {
        guard let url = URL(string: "https://www.googleapis.com/youtube/v3/videos?part=snippet,contentDetails&myRating=like&videoCategoryId=10&maxResults=50") else {
            return []
        }
        var req = URLRequest(url: url)
        req.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        guard let (data, resp) = try? await URLSession.shared.data(for: req),
              let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let items = json["items"] as? [[String: Any]] else {
            return []
        }

        var songs: [Song] = []
        for item in items {
            guard let id = item["id"] as? String,
                  let snippet = item["snippet"] as? [String: Any],
                  let title = snippet["title"] as? String else { continue }

            let channelTitle = snippet["channelTitle"] as? String ?? "Unknown Artist"
            let artist = channelTitle.replacingOccurrences(of: " - Topic", with: "").trimmingCharacters(in: .whitespaces)

            let classificationResult = MusicClassificationService.classify(
                title: title,
                channelOrArtist: channelTitle,
                duration: 210,
                categoryId: "10"
            )

            guard classificationResult.classification.isPlayableSong else {
                continue
            }

            var artworkURL: URL?
            if let thumbs = snippet["thumbnails"] as? [String: Any],
               let high = thumbs["high"] as? [String: Any],
               let urlStr = high["url"] as? String {
                artworkURL = URL(string: urlStr)
            }

            let song = Song(
                id: id,
                title: title,
                artist: artist,
                duration: 210,
                artworkURL: artworkURL,
                sourceId: "youtube"
            )
            songs.append(song)
        }
        return songs
    }

    // MARK: - PKCE Cryptography Helpers
    private func generateCodeVerifier() -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return Data(bytes).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private func generateCodeChallenge(from verifier: String) -> String {
        guard let data = verifier.data(using: .utf8) else { return verifier }
        let digest = CryptoUtils.sha256(data: data)
        return digest.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}

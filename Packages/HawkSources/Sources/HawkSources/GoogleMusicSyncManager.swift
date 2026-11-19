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
    public private(set) var syncProgress: Double = 0.0
    private var isCancellationRequested: Bool = false
    private var activeSyncTask: Task<Void, Never>?

    public var isAutoSyncEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: "hawk_google_auto_sync") }
        set { UserDefaults.standard.set(newValue, forKey: "hawk_google_auto_sync") }
    }

    private let keychain = KeychainStore.shared
    private let httpClient = HawkHttpClient.shared
    private var inFlightRefreshTask: Task<String, Error>?

    // Google OAuth 2.0 configuration
    private let scopes = [
        "openid",
        "https://www.googleapis.com/auth/userinfo.email",
        "https://www.googleapis.com/auth/youtube.readonly"
    ].joined(separator: " ")

    /// Represents the strict configuration and readiness state of Google OAuth in this build.
    public enum OAuthConfigurationState: Equatable, Sendable {
        case notConfigured
        case invalidFormat(reason: String)
        case schemeNotRegisteredInBuild(expectedScheme: String, registeredSchemes: [String])
        case ready(clientId: String, reversedScheme: String, redirectUri: String)
    }

    /// Internal test flag allowing unit tests in CLI/SPM environments to bypass iOS Bundle.main check.
    public static var bypassBundleSchemeCheckForTesting: Bool = false

    /// Resolves active Google OAuth Client ID with single authoritative configuration source:
    /// 1. User/Developer custom Client ID stored in UserDefaults (`hawk_google_client_id`).
    /// 2. Bundle Info.plist (`GoogleClientID` key).
    /// Returns nil if neither source is configured or if the value is empty/placeholder.
    public var configuredClientId: String? {
        if let custom = UserDefaults.standard.string(forKey: "hawk_google_client_id"),
           !custom.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return custom.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if let bundleId = Bundle.main.object(forInfoDictionaryKey: "GoogleClientID") as? String,
           !bundleId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return bundleId.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return nil
    }

    /// Specific errors encountered when validating a Google Cloud Client ID string.
    public enum ClientIdValidationError: Error, CustomStringConvertible, Sendable, Equatable {
        case empty
        case placeholderForbidden
        case missingGoogleSuffix
        case invalidPrefixFormat
        case missingNumericProjectNumber

        public var description: String {
            switch self {
            case .empty:
                return "Client ID cannot be empty."
            case .placeholderForbidden:
                return "Placeholder Client IDs are not permitted. A genuine Google Cloud iOS Client ID is required."
            case .missingGoogleSuffix:
                return "Google Client ID must end with '.apps.googleusercontent.com'."
            case .invalidPrefixFormat:
                return "Google Client ID prefix must follow '<project-number>-<client-hash>' format."
            case .missingNumericProjectNumber:
                return "Google Client ID must begin with a numeric Google Cloud project number."
            }
        }
    }

    /// Validates client ID format against genuine Google Cloud iOS OAuth patterns.
    public static func validateClientIdFormat(_ id: String) -> Result<String, ClientIdValidationError> {
        let trimmed = id.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return .failure(.empty)
        }
        let lower = trimmed.lowercased()
        if lower.contains("hawk-music-player") || lower.contains("placeholder") || lower.contains("your_client_id") || lower.contains("example") || lower.contains("dummy") {
            return .failure(.placeholderForbidden)
        }
        guard trimmed.hasSuffix(".apps.googleusercontent.com") else {
            return .failure(.missingGoogleSuffix)
        }
        let prefix = String(trimmed.dropLast(".apps.googleusercontent.com".count))
        guard prefix.contains("-") else {
            return .failure(.invalidPrefixFormat)
        }
        let parts = prefix.split(separator: "-", maxSplits: 1)
        guard let projectNumber = parts.first, CharacterSet.decimalDigits.isSuperset(of: CharacterSet(charactersIn: String(projectNumber))) else {
            return .failure(.missingNumericProjectNumber)
        }
        return .success(trimmed)
    }

    /// Returns URL schemes registered in the installed application's CFBundleURLTypes.
    public static func registeredBundleSchemes() -> [String] {
        guard let urlTypes = Bundle.main.object(forInfoDictionaryKey: "CFBundleURLTypes") as? [[String: Any]] else {
            return []
        }
        var result: [String] = []
        for dict in urlTypes {
            if let schemes = dict["CFBundleURLSchemes"] as? [String] {
                result.append(contentsOf: schemes)
            }
        }
        return result
    }

    /// Verifies if a given scheme is registered in the compiled application bundle.
    public static func isSchemeRegisteredInBundle(_ scheme: String) -> Bool {
        let lower = scheme.lowercased()
        let registered = registeredBundleSchemes().map { $0.lowercased() }
        return registered.contains(lower)
    }

    /// Current validated configuration state for Google OAuth.
    public var configurationState: OAuthConfigurationState {
        guard let raw = configuredClientId, !raw.isEmpty else {
            return .notConfigured
        }
        switch Self.validateClientIdFormat(raw) {
        case .failure(let error):
            return .invalidFormat(reason: error.description)
        case .success(let validId):
            let scheme = Self.reversedScheme(for: validId)
            let isRegistered = Self.bypassBundleSchemeCheckForTesting || Self.isSchemeRegisteredInBundle(scheme)
            if isRegistered {
                return .ready(
                    clientId: validId,
                    reversedScheme: scheme,
                    redirectUri: Self.redirectUri(for: validId)
                )
            } else {
                return .schemeNotRegisteredInBuild(
                    expectedScheme: scheme,
                    registeredSchemes: Self.registeredBundleSchemes()
                )
            }
        }
    }

    /// Indicates whether a valid client ID is configured and its reversed scheme is registered in the build.
    public var isConfiguredAndReady: Bool {
        if case .ready = configurationState { return true }
        return false
    }

    /// Updates or clears custom Google Cloud OAuth Client ID in authoritative storage (UserDefaults).
    public func setCustomClientId(_ id: String?) {
        let cleaned = id?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let cleaned = cleaned, !cleaned.isEmpty {
            UserDefaults.standard.set(cleaned, forKey: "hawk_google_client_id")
        } else {
            UserDefaults.standard.removeObject(forKey: "hawk_google_client_id")
        }
    }

    /// Derives standard Google iOS reversed Client ID scheme (RFC 8252) from Client ID.
    /// E.g. `123456-abc.apps.googleusercontent.com` -> `com.googleusercontent.apps.123456-abc`
    nonisolated public static func reversedScheme(for clientId: String) -> String {
        let trimmed = clientId.trimmingCharacters(in: .whitespacesAndNewlines)
        let suffix = ".apps.googleusercontent.com"
        if trimmed.hasSuffix(suffix) {
            let prefix = String(trimmed.dropLast(suffix.count))
            return "com.googleusercontent.apps.\(prefix)"
        }
        return "com.hawk.music"
    }

    /// Derives standard Google iOS OAuth 2.0 redirect URI from Client ID.
    nonisolated public static func redirectUri(for clientId: String) -> String {
        let scheme = reversedScheme(for: clientId)
        return "\(scheme):/oauth2callback"
    }

    /// Maps Google OAuth 2.0 error codes to user-friendly, actionable diagnostic guidance.
    nonisolated public static func mapOAuthError(code: String, description: String? = nil) -> String {
        switch code.lowercased() {
        case "invalid_client":
            return "Google OAuth Client ID is invalid or not found in Google Cloud Console. Please configure an authorized iOS Client ID for bundle identifier 'com.hawk.music'."
        case "deleted_client":
            return "The configured Google OAuth client has been deleted from Google Cloud Console. Please configure an active iOS Client ID."
        case "redirect_uri_mismatch":
            return "Google OAuth redirect URI mismatch. In Google Cloud Console, ensure the iOS client has bundle ID 'com.hawk.music' and redirect URI matching your reversed client ID."
        case "invalid_grant":
            return "Authorization code or refresh token has expired or been revoked (invalid_grant). Please sign in again."
        case "access_denied":
            if let desc = description, !desc.isEmpty {
                if desc.localizedCaseInsensitiveContains("testing") ||
                   desc.localizedCaseInsensitiveContains("verification") ||
                   desc.localizedCaseInsensitiveContains("developer-approved") ||
                   desc.localizedCaseInsensitiveContains("tester") {
                    return "Google OAuth Access Blocked (403: access_denied): The app is in Google Cloud 'Testing' mode. Your Google account email must be added to 'Test users' in Google Cloud Console (APIs & Services → OAuth consent screen → Test users)."
                }
                return "Google sign-in access denied: \(desc)"
            }
            return "Google sign-in access was blocked or denied (403: access_denied). If your Google Cloud project is in 'Testing' mode, your email must be added to 'Test users' in Google Cloud Console (OAuth consent screen → Test users)."
        case "invalid_scope":
            return "Requested OAuth scope is invalid. Ensure YouTube Data API v3 and Google userinfo scopes are enabled in Google Cloud Console."
        case "unauthorized_client":
            return "This OAuth client is unauthorized for the authorization code grant type. Verify your Google Cloud client is configured as an 'iOS' application."
        case "interaction_required":
            return "Google user interaction is required to complete authentication. Please sign in again."
        default:
            if let desc = description, !desc.isEmpty {
                return "Google authentication failed: \(desc) (\(code))"
            }
            return "Google authentication failed (\(code)). Please try again."
        }
    }

    // MARK: - OpenID Connect (OIDC) ID Token Validation
    public struct IdTokenClaims: Sendable, Equatable {
        public let issuer: String
        public let audience: String
        public let subject: String
        public let email: String?
        public let emailVerified: Bool
        public let nonce: String?
        public let expiration: Date
        public let issuedAt: Date

        public init(
            issuer: String,
            audience: String,
            subject: String,
            email: String?,
            emailVerified: Bool = false,
            nonce: String? = nil,
            expiration: Date,
            issuedAt: Date
        ) {
            self.issuer = issuer
            self.audience = audience
            self.subject = subject
            self.email = email
            self.emailVerified = emailVerified
            self.nonce = nonce
            self.expiration = expiration
            self.issuedAt = issuedAt
        }
    }

    public enum IdTokenValidationError: Error, CustomStringConvertible, Sendable, Equatable {
        case malformedJwt
        case invalidBase64(String)
        case invalidJson(String)
        case missingKeyId
        case unknownSigningKey(String)
        case unsupportedAlgorithm(String)
        case algorithmNoneRejected
        case invalidSignature
        case invalidIssuer(String)
        case audienceMismatch(expected: String, actual: String)
        case tokenExpired(expiration: Date, now: Date)
        case tokenIssuedInFuture(issuedAt: Date, now: Date)
        case missingSubject
        case nonceMismatch(expected: String, actual: String?)
        case networkError(String)
        case invalidPublicKeyData

        public var description: String {
            switch self {
            case .malformedJwt:
                return "ID token does not have 3 segments (header.payload.signature)."
            case .invalidBase64(let part):
                return "Failed to decode base64url \(part) in ID token."
            case .invalidJson(let part):
                return "ID token \(part) is not valid JSON."
            case .missingKeyId:
                return "ID token header is missing required 'kid' (Key ID)."
            case .unknownSigningKey(let kid):
                return "Signing key '\(kid)' not found in Google JWKS."
            case .unsupportedAlgorithm(let alg):
                return "Unsupported JWT signing algorithm: '\(alg)'. Expected 'RS256'."
            case .algorithmNoneRejected:
                return "CRITICAL: JWT 'alg=none' rejected. Unsigned tokens are strictly prohibited."
            case .invalidSignature:
                return "CRITICAL: JWT RSA signature verification failed. Token is invalid or has been tampered with."
            case .invalidIssuer(let iss):
                return "Invalid ID token issuer: '\(iss)'. Expected 'accounts.google.com'."
            case .audienceMismatch(let expected, let actual):
                return "ID token audience mismatch: expected '\(expected)', got '\(actual)'."
            case .tokenExpired(let exp, let now):
                return "ID token has expired (exp: \(exp), now: \(now))."
            case .tokenIssuedInFuture(let iat, let now):
                return "ID token issued in the future (iat: \(iat), now: \(now))."
            case .missingSubject:
                return "ID token missing 'sub' claim."
            case .nonceMismatch(let expected, let actual):
                return "ID token nonce mismatch: expected '\(expected)', got '\(actual ?? "nil")'."
            case .networkError(let msg):
                return "Network error while resolving Google JWKS: \(msg)"
            case .invalidPublicKeyData:
                return "Failed to construct valid RSA public key from JWKS."
            }
        }
    }

    /// Cryptographically validates OIDC ID token signature against Google's JWKS and verifies claims.
    ///
    /// Critical security invariants:
    /// 1. Enforces 3-part JWT structure.
    /// 2. Header algorithm MUST be 'RS256'; explicitly rejects 'none' and algorithm confusion.
    /// 3. Resolves signing key from Google's JWKS endpoint with automated rotation and safe caching.
    /// 4. Cryptographically verifies RS256 signature over ASCII(header + "." + payload) using Apple Security framework.
    /// 5. Validates signature BEFORE trusting or evaluating any claims.
    /// 6. Validates issuer, audience, subject, expiration, issued-at, and nonce.
    /// 7. Never trusts or extracts email claims from an unverified token.
    nonisolated public static func validateIdToken(
        rawToken: String,
        expectedAudience: String,
        expectedNonce: String? = nil,
        now: Date = Date(),
        jwksService: GoogleJwksService = GoogleJwksService.shared,
        customKeyResolver: (@Sendable (String) async throws -> SendableSecKey?)? = nil
    ) async -> Result<IdTokenClaims, IdTokenValidationError> {
        let parts = rawToken.components(separatedBy: ".")
        guard parts.count == 3 else {
            return .failure(.malformedJwt)
        }

        // 1. Decode & validate Header
        guard let headerData = base64UrlDecode(parts[0]),
              let headerJson = try? JSONSerialization.jsonObject(with: headerData) as? [String: Any] else {
            return .failure(.invalidBase64("header"))
        }

        guard let rawAlg = headerJson["alg"] as? String else {
            return .failure(.unsupportedAlgorithm("missing"))
        }
        let alg = rawAlg.trimmingCharacters(in: .whitespacesAndNewlines)
        if alg.lowercased() == "none" {
            return .failure(.algorithmNoneRejected)
        }
        guard alg == "RS256" else {
            return .failure(.unsupportedAlgorithm(alg))
        }

        guard let kid = headerJson["kid"] as? String, !kid.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return .failure(.missingKeyId)
        }

        // 2. Resolve Public Key from JWKS
        let publicKey: SecKey
        do {
            if let customResolver = customKeyResolver {
                guard let sendableKey = try await customResolver(kid) else {
                    return .failure(.unknownSigningKey(kid))
                }
                publicKey = sendableKey.rawKey
            } else {
                let sendableKey = try await jwksService.getKey(for: kid)
                publicKey = sendableKey.rawKey
            }
        } catch let valErr as IdTokenValidationError {
            return .failure(valErr)
        } catch {
            return .failure(.networkError(error.localizedDescription))
        }

        // 3. Decode Signature
        guard let signatureData = base64UrlDecode(parts[2]), !signatureData.isEmpty else {
            return .failure(.invalidSignature)
        }

        // 4. CRYPTOGRAPHICALLY VERIFY SIGNATURE BEFORE TRUSTING ANY CLAIMS
        guard let signedData = "\(parts[0]).\(parts[1])".data(using: .ascii) else {
            return .failure(.malformedJwt)
        }

        var secError: Unmanaged<CFError>?
        let isSignatureValid = SecKeyVerifySignature(
            publicKey,
            .rsaSignatureMessagePKCS1v15SHA256,
            signedData as CFData,
            signatureData as CFData,
            &secError
        )

        guard isSignatureValid else {
            return .failure(.invalidSignature)
        }

        // 5. PARSE & VALIDATE CLAIMS (ONLY REACHED AFTER CRYPTOGRAPHIC SIGNATURE VERIFICATION)
        guard let payloadData = base64UrlDecode(parts[1]),
              let json = try? JSONSerialization.jsonObject(with: payloadData) as? [String: Any] else {
            return .failure(.invalidJson("payload"))
        }

        guard let iss = json["iss"] as? String, (iss == "https://accounts.google.com" || iss == "accounts.google.com") else {
            return .failure(.invalidIssuer(json["iss"] as? String ?? "missing"))
        }

        guard let aud = json["aud"] as? String, aud == expectedAudience else {
            return .failure(.audienceMismatch(expected: expectedAudience, actual: json["aud"] as? String ?? "missing"))
        }

        guard let sub = json["sub"] as? String, !sub.isEmpty else {
            return .failure(.missingSubject)
        }

        let expSec = (json["exp"] as? Double) ?? 0
        let expDate = Date(timeIntervalSince1970: expSec)
        if expDate.addingTimeInterval(60) <= now {
            return .failure(.tokenExpired(expiration: expDate, now: now))
        }

        let iatSec = (json["iat"] as? Double) ?? 0
        let iatDate = Date(timeIntervalSince1970: iatSec)
        if iatDate > now.addingTimeInterval(300) {
            return .failure(.tokenIssuedInFuture(issuedAt: iatDate, now: now))
        }

        if let expectedNonce = expectedNonce {
            let tokenNonce = json["nonce"] as? String
            guard let tokenNonce = tokenNonce, tokenNonce == expectedNonce else {
                return .failure(.nonceMismatch(expected: expectedNonce, actual: tokenNonce))
            }
        }

        let email = json["email"] as? String
        let emailVerified = json["email_verified"] as? Bool ?? false
        let nonce = json["nonce"] as? String

        return .success(IdTokenClaims(
            issuer: iss,
            audience: aud,
            subject: sub,
            email: email,
            emailVerified: emailVerified,
            nonce: nonce,
            expiration: expDate,
            issuedAt: iatDate
        ))
    }

    nonisolated public static func base64UrlEncode(_ data: Data) -> String {
        return data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    nonisolated public static func base64UrlDecode(_ string: String) -> Data? {
        var base64 = string
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        while base64.count % 4 != 0 {
            base64.append("=")
        }
        return Data(base64Encoded: base64)
    }

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

    // MARK: - OAuth 2.0 Callback Validation (Public for Testing)
    /// Validates an incoming OAuth 2.0 callback URL against state, redirect scheme, path, and error conditions.
    nonisolated public static func validateOAuthCallback(url: URL, expectedState: String, allowedScheme: String? = nil) throws -> String {
        guard let scheme = url.scheme?.lowercased() else {
            throw HawkError.authRequired("OAuth callback missing URL scheme")
        }

        if let expected = allowedScheme?.lowercased() {
            guard scheme == expected || scheme == "com.hawk.music" else {
                throw HawkError.authRequired("Invalid OAuth callback URL scheme: '\(scheme)'. Expected: '\(expected)'.")
            }
        } else {
            let isGoogleScheme = scheme.starts(with: "com.googleusercontent.apps.")
            let isHawkScheme = scheme == "com.hawk.music"
            guard isGoogleScheme || isHawkScheme else {
                throw HawkError.authRequired("Invalid OAuth callback URL scheme: \(scheme)")
            }
        }

        let path = url.path
        if !path.isEmpty && path != "/oauth2callback" && path != "/" {
            throw HawkError.authRequired("Invalid OAuth callback URL path: '\(path)'. Expected '/oauth2callback'")
        }

        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let queryItems = components?.queryItems ?? []

        // Check for error parameters (e.g. invalid_client, access_denied, redirect_uri_mismatch)
        if let err = queryItems.first(where: { $0.name == "error" })?.value {
            let desc = queryItems.first(where: { $0.name == "error_description" })?.value
            let actionableMessage = mapOAuthError(code: err, description: desc)
            throw HawkError.authRequired(actionableMessage)
        }

        // Validate state token to prevent CSRF
        guard let returnedState = queryItems.first(where: { $0.name == "state" })?.value, !returnedState.isEmpty else {
            throw HawkError.authRequired("OAuth state parameter missing from callback")
        }

        guard returnedState == expectedState else {
            throw HawkError.authRequired("OAuth state mismatch: potential CSRF detected")
        }

        // Validate authorization code
        guard let code = queryItems.first(where: { $0.name == "code" })?.value, !code.isEmpty else {
            throw HawkError.authRequired("Authorization code missing in callback")
        }

        return code
    }

    // MARK: - Authentication
    public func startGoogleSignIn() async throws {
        guard case .ready(let activeClientId, let activeReversedScheme, let activeRedirectUri) = configurationState else {
            switch configurationState {
            case .notConfigured:
                throw HawkError.authRequired("Google Cloud iOS Client ID is not configured. Please open Settings and configure an authorized iOS Client ID.")
            case .invalidFormat(let reason):
                throw HawkError.authRequired("Invalid Google Client ID: \(reason)")
            case .schemeNotRegisteredInBuild(let expectedScheme, let registered):
                let regList = registered.isEmpty ? "None" : registered.joined(separator: ", ")
                throw HawkError.authRequired("Reversed scheme '\(expectedScheme)' is not registered in this installed build's Info.plist (Registered: [\(regList)]). Rebuilding HAWK with this Client ID in project.yml is required for iOS URL scheme routing.")
            case .ready:
                break
            }
            return
        }

        // Prepare PKCE code verifier and challenge (RFC 7636)
        let verifier = Self.generateCodeVerifier()
        let challenge = Self.generateCodeChallenge(from: verifier)
        // Cryptographic state parameter to prevent CSRF / session fixation
        let stateToken = Self.generateStateToken()
        // Cryptographic nonce parameter to prevent token replay attacks (OIDC Core 1.0)
        let nonceToken = Self.generateNonce()

        var components = URLComponents(string: "https://accounts.google.com/o/oauth2/v2/auth")!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: activeClientId),
            URLQueryItem(name: "redirect_uri", value: activeRedirectUri),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: scopes),
            URLQueryItem(name: "code_challenge", value: challenge),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "state", value: stateToken),
            URLQueryItem(name: "nonce", value: nonceToken),
            URLQueryItem(name: "prompt", value: "select_account")
        ]

        guard let authURL = components.url else {
            throw HawkError.networkError("Invalid Google authorization URL")
        }

        return try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(
                url: authURL,
                callbackURLScheme: activeReversedScheme
            ) { [weak self] callbackURL, error in
                guard let self = self else {
                    continuation.resume(throwing: HawkError.authRequired("Session deallocated"))
                    return
                }

                if let error = error {
                    let nsError = error as NSError
                    if nsError.domain == ASWebAuthenticationSessionErrorDomain &&
                        nsError.code == ASWebAuthenticationSessionError.canceledLogin.rawValue {
                        continuation.resume(throwing: HawkError.authRequired("Google sign-in was closed. If Google displayed 'Access blocked: Hawk IOS has not completed the Google verification process (403: access_denied)', add your signing-in Google email to 'Test users' in Google Cloud Console (OAuth consent screen → Test users)."))
                    } else {
                        continuation.resume(throwing: HawkError.authRequired(error.localizedDescription))
                    }
                    return
                }

                guard let callbackURL = callbackURL else {
                    continuation.resume(throwing: HawkError.authRequired("Callback URL missing"))
                    return
                }

                do {
                    let code = try Self.validateOAuthCallback(
                        url: callbackURL,
                        expectedState: stateToken,
                        allowedScheme: activeReversedScheme
                    )
                    Task {
                        do {
                            try await self.exchangeCodeForTokens(
                                code: code,
                                verifier: verifier,
                                nonce: nonceToken,
                                clientId: activeClientId,
                                redirectUri: activeRedirectUri
                            )
                            continuation.resume()
                        } catch {
                            continuation.resume(throwing: error)
                        }
                    }
                } catch {
                    continuation.resume(throwing: error)
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
        try? await keychain.delete(key: "yt_cookie")

        self.accountEmail = nil
        self.isConnected = false
        self.lastSyncDate = nil
        self.syncedPlaylistsCount = 0
        self.syncedSongsCount = 0
        self.syncStatusMessage = nil
    }

    /// Validates access token and transparently refreshes it via refresh_token if expired,
    /// coordinating concurrent requests to eliminate duplicate token refresh calls.
    public func getValidAccessToken() async throws -> String {
        guard let token = try? await keychain.readString(key: "google_access_token"), !token.isEmpty else {
            throw HawkError.authRequired("Not connected to Google")
        }

        let expiryStr = (try? await keychain.readString(key: "google_token_expiry")) ?? "0"
        let expiryTimestamp = Double(expiryStr) ?? 0
        let now = Date().timeIntervalSince1970

        // If token has at least 60 seconds of validity remaining, return it
        if expiryTimestamp > (now + 60) {
            return token
        }

        // Coordinate concurrent refresh operations
        if let existingTask = inFlightRefreshTask {
            return try await existingTask.value
        }

        let refreshTask = Task<String, Error> { @MainActor [weak self] in
            guard let self = self else { throw HawkError.authRequired("Session deallocated") }
            return try await self.performTokenRefresh(cachedToken: token, expiryTimestamp: expiryTimestamp, now: now)
        }
        self.inFlightRefreshTask = refreshTask
        defer { self.inFlightRefreshTask = nil }
        return try await refreshTask.value
    }

    private func performTokenRefresh(cachedToken: String, expiryTimestamp: Double, now: Double) async throws -> String {
        // Token is expired or expiring imminently -> refresh
        guard let refreshToken = try? await keychain.readString(key: "google_refresh_token"), !refreshToken.isEmpty else {
            if expiryTimestamp > now {
                return cachedToken
            }
            throw HawkError.authRequired("Google session expired. Please sign in again.")
        }

        guard let tokenURL = URL(string: "https://oauth2.googleapis.com/token") else {
            throw HawkError.networkError("Invalid token URL")
        }

        var request = URLRequest(url: tokenURL)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        guard let activeClientId = configuredClientId, !activeClientId.isEmpty else {
            throw HawkError.authRequired("Cannot refresh token: Google OAuth Client ID is not configured.")
        }

        let bodyParams = [
            "client_id": activeClientId,
            "refresh_token": refreshToken,
            "grant_type": "refresh_token"
        ]

        let bodyString = bodyParams.map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")" }.joined(separator: "&")
        request.httpBody = bodyString.data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw HawkError.networkError("Token refresh server returned invalid response")
        }

        if httpResponse.statusCode == 400 || httpResponse.statusCode == 401 {
            let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            let errStr = errorJson?["error"] as? String ?? "token_refresh_failed"
            let errDesc = errorJson?["error_description"] as? String
            if errStr == "invalid_grant" {
                // User revoked access from their Google account
                await disconnect()
                throw HawkError.authRequired("Google access has been revoked or expired (invalid_grant). Please reconnect your account.")
            }
            let actionableMessage = Self.mapOAuthError(code: errStr, description: errDesc)
            throw HawkError.authRequired("Token refresh failed: \(actionableMessage)")
        }

        guard (200...299).contains(httpResponse.statusCode),
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

    private func exchangeCodeForTokens(
        code: String,
        verifier: String,
        nonce: String? = nil,
        clientId: String? = nil,
        redirectUri: String? = nil
    ) async throws {
        guard let tokenURL = URL(string: "https://oauth2.googleapis.com/token") else {
            throw HawkError.networkError("Invalid token URL")
        }

        var request = URLRequest(url: tokenURL)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        guard let activeClientId = clientId ?? configuredClientId, !activeClientId.isEmpty else {
            throw HawkError.authRequired("Cannot exchange authorization code: Google OAuth Client ID is not configured.")
        }
        let activeRedirectUri = redirectUri ?? Self.redirectUri(for: activeClientId)

        let bodyParams = [
            "code": code,
            "client_id": activeClientId,
            "redirect_uri": activeRedirectUri,
            "grant_type": "authorization_code",
            "code_verifier": verifier
        ]

        let bodyString = bodyParams.map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")" }.joined(separator: "&")
        request.httpBody = bodyString.data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw HawkError.networkError("Token exchange server returned invalid response")
        }

        if httpResponse.statusCode == 400 || httpResponse.statusCode == 401 {
            let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            let errStr = errorJson?["error"] as? String ?? "token_exchange_failed"
            let errDesc = errorJson?["error_description"] as? String
            let actionableMessage = Self.mapOAuthError(code: errStr, description: errDesc)
            throw HawkError.authRequired("Token exchange failed: \(actionableMessage)")
        }

        guard (200...299).contains(httpResponse.statusCode),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let accessToken = json["access_token"] as? String else {
            throw HawkError.networkError("Token exchange failed")
        }

        let refreshToken = json["refresh_token"] as? String
        let expiresIn = json["expires_in"] as? Double ?? 3600
        var resolvedEmail = "Google User"

        // 1. Prefer authenticated user email from cryptographically verified OIDC ID token
        if let idToken = json["id_token"] as? String {
            let validationResult = await Self.validateIdToken(
                rawToken: idToken,
                expectedAudience: activeClientId,
                expectedNonce: nonce
            )
            switch validationResult {
            case .success(let claims):
                if let tokenEmail = claims.email, !tokenEmail.isEmpty {
                    resolvedEmail = tokenEmail
                }
            case .failure(let valErr):
                print("[GoogleOAuth] Cryptographic OIDC ID token verification rejected: \(valErr.description)")
            }
        }

        // 2. Fall back to userinfo endpoint if ID token was absent or cryptographically rejected
        if resolvedEmail == "Google User", let fetchedEmail = try? await fetchGoogleUserEmail(accessToken: accessToken) {
            resolvedEmail = fetchedEmail
        }

        try await connectWithToken(email: resolvedEmail, accessToken: accessToken, refreshToken: refreshToken, expiresIn: expiresIn)

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

    // MARK: - YouTube Music Library Synchronisation (Music-Only Scope & Robust Pagination)
    public func cancelSync() {
        isCancellationRequested = true
        activeSyncTask?.cancel()
        activeSyncTask = nil
        isSyncing = false
        syncProgress = 0.0
        syncStatusMessage = "Sync cancelled by user."
    }

    public func syncNow() async {
        guard isConnected else {
            syncStatusMessage = "Not connected to Google"
            return
        }

        isCancellationRequested = false
        isSyncing = true
        syncProgress = 0.05
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
            // 1. Fetch User Playlists with Pagination
            let playlists = try await fetchUserMusicPlaylists(accessToken: token)
            var totalSyncedPlaylists = 0
            var totalSyncedSongs = 0

            let totalSteps = max(playlists.count + 1, 1)

            for (index, p) in playlists.enumerated() {
                if isCancellationRequested || Task.isCancelled {
                    throw CancellationError()
                }

                let tracks: [Song]
                do {
                    tracks = try await fetchPlaylistMusicTracks(playlistId: p.id, accessToken: token)
                } catch {
                    // Soft error handling: preserve sync if an individual playlist fails
                    continue
                }
                guard !tracks.isEmpty else { continue }

                // Check existing playlists to avoid duplication and preserve local user additions
                let existing = await PlaylistStore.shared.getAllPlaylists()
                if let match = existing.first(where: { $0.title == p.title }) {
                    var merged = match.songs
                    for t in tracks {
                        if !merged.contains(where: { $0.canonicalKey == t.canonicalKey || $0.id == t.id }) {
                            merged.append(t)
                        }
                    }
                    _ = await PlaylistStore.shared.createPlaylist(title: match.title, initialSongs: merged)
                } else {
                    _ = await PlaylistStore.shared.createPlaylist(title: p.title, initialSongs: tracks)
                }
                totalSyncedPlaylists += 1
                totalSyncedSongs += tracks.count

                self.syncProgress = Double(index + 1) / Double(totalSteps)
                self.syncStatusMessage = "Synced \(totalSyncedPlaylists) playlists (\(p.title))..."
            }

            if isCancellationRequested || Task.isCancelled {
                throw CancellationError()
            }

            // 2. Fetch Liked Music Tracks (Strict Category: Music)
            let likedTracks = try await fetchLikedMusic(accessToken: token)
            if !likedTracks.isEmpty {
                _ = await PlaylistStore.shared.createPlaylist(title: "YT Music: Liked Music", initialSongs: likedTracks)
                for track in likedTracks {
                    if isCancellationRequested || Task.isCancelled { break }
                    _ = await PlaylistStore.shared.addSong(to: Playlist.favoritesId, song: track)
                    totalSyncedSongs += 1
                }
            }

            self.syncedPlaylistsCount = totalSyncedPlaylists
            self.syncedSongsCount = totalSyncedSongs
            self.syncProgress = 1.0
            self.lastSyncDate = Date()
            UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: "hawk_google_last_sync_timestamp")

            self.syncStatusMessage = "Sync complete: \(totalSyncedPlaylists) playlists, \(totalSyncedSongs) tracks."
        } catch is CancellationError {
            self.syncStatusMessage = "Sync cancelled by user."
        } catch {
            self.syncStatusMessage = "Sync failed: \(error.localizedDescription)"
        }

        self.isSyncing = false
    }

    /// Retrieves all playlists imported from YouTube Music.
    public func getYouTubeImportedPlaylists() async -> [Playlist] {
        let all = await PlaylistStore.shared.getAllPlaylists()
        return all.filter { playlist in
            playlist.id != Playlist.favoritesId &&
            (playlist.title.starts(with: "YT Music:") || playlist.songs.contains(where: { $0.sourceId == "youtube" }))
        }
    }

    private func fetchUserMusicPlaylists(accessToken: String) async throws -> [(id: String, title: String)] {
        var playlists: [(id: String, title: String)] = []
        var nextPageToken: String? = nil
        var pageCount = 0
        let maxPages = 5 // Fetch up to 250 playlists

        repeat {
            pageCount += 1
            var urlString = "https://www.googleapis.com/youtube/v3/playlists?part=snippet,contentDetails&mine=true&maxResults=50"
            if let token = nextPageToken {
                urlString += "&pageToken=\(token)"
            }
            guard let url = URL(string: urlString) else { break }

            var req = URLRequest(url: url)
            req.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

            let (data, resp) = try await URLSession.shared.data(for: req)
            guard let http = resp as? HTTPURLResponse else { break }

            if http.statusCode == 403 {
                let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
                if let errorObj = json?["error"] as? [String: Any],
                   let errors = errorObj["errors"] as? [[String: Any]],
                   let reason = errors.first?["reason"] as? String,
                   reason == "quotaExceeded" || reason == "rateLimitExceeded" {
                    throw HawkError.networkError("YouTube API daily quota exceeded (10,000 units/day). Sync will resume after quota resets.")
                }
                break
            }

            guard (200...299).contains(http.statusCode),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let items = json["items"] as? [[String: Any]] else {
                break
            }

            for item in items {
                guard let id = item["id"] as? String,
                      let snippet = item["snippet"] as? [String: Any],
                      let title = snippet["title"] as? String else { continue }
                playlists.append((id: id, title: "YT Music: \(title)"))
            }

            nextPageToken = json["nextPageToken"] as? String
        } while nextPageToken != nil && pageCount < maxPages

        return playlists
    }

    private func fetchPlaylistMusicTracks(playlistId: String, accessToken: String) async throws -> [Song] {
        var songs: [Song] = []
        var nextPageToken: String? = nil
        var pageCount = 0
        let maxPages = 5 // Fetch up to 250 tracks per playlist

        repeat {
            pageCount += 1
            var urlString = "https://www.googleapis.com/youtube/v3/playlistItems?part=snippet,contentDetails&playlistId=\(playlistId)&maxResults=50"
            if let token = nextPageToken {
                urlString += "&pageToken=\(token)"
            }
            guard let url = URL(string: urlString) else { break }

            var req = URLRequest(url: url)
            req.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

            let (data, resp) = try await URLSession.shared.data(for: req)
            guard let http = resp as? HTTPURLResponse else { break }

            if http.statusCode == 403 {
                let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
                if let errorObj = json?["error"] as? [String: Any],
                   let errors = errorObj["errors"] as? [[String: Any]],
                   let reason = errors.first?["reason"] as? String,
                   reason == "quotaExceeded" || reason == "rateLimitExceeded" {
                    throw HawkError.networkError("YouTube API daily quota exceeded (10,000 units/day). Sync will resume after quota resets.")
                }
                break
            }

            guard (200...299).contains(http.statusCode),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let items = json["items"] as? [[String: Any]] else {
                break
            }

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

                let song = Song(
                    id: videoId,
                    title: title,
                    artist: artist,
                    duration: 210,
                    artworkURL: artworkURL,
                    sourceId: "youtube"
                )
                songs.append(song)
            }

            nextPageToken = json["nextPageToken"] as? String
        } while nextPageToken != nil && pageCount < maxPages

        return songs
    }

    // MARK: - ISO 8601 Duration Parser
    nonisolated public static func parseISO8601Duration(_ text: String) -> TimeInterval {
        // Formats: "PT4M13S", "PT1H2M10S", "PT45S", "PT1H"
        var str = text
        guard str.hasPrefix("PT") else { return 0 }
        str.removeFirst(2)

        var hours: Double = 0
        var minutes: Double = 0
        var seconds: Double = 0

        if let hRange = str.range(of: "H") {
            let hStr = String(str[..<hRange.lowerBound])
            hours = Double(hStr) ?? 0
            str = String(str[hRange.upperBound...])
        }
        if let mRange = str.range(of: "M") {
            let mStr = String(str[..<mRange.lowerBound])
            minutes = Double(mStr) ?? 0
            str = String(str[mRange.upperBound...])
        }
        if let sRange = str.range(of: "S") {
            let sStr = String(str[..<sRange.lowerBound])
            seconds = Double(sStr) ?? 0
        }

        return hours * 3600 + minutes * 60 + seconds
    }

    /// Parses YouTube Data API v3 `videos.list?myRating=like` JSON response.
    /// Filters out non-music category videos (YouTube category 10 is Music), podcasts, gaming, sound effects, and deleted items.
    nonisolated public static func parseLikedVideosResponse(data: Data) throws -> (songs: [Song], nextPageToken: String?) {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw HawkError.decodeError("Invalid YouTube API JSON response")
        }

        let nextPageToken = json["nextPageToken"] as? String
        guard let items = json["items"] as? [[String: Any]] else {
            return ([], nextPageToken)
        }

        var songs: [Song] = []
        for item in items {
            guard let id = item["id"] as? String,
                  let snippet = item["snippet"] as? [String: Any],
                  let title = snippet["title"] as? String,
                  title != "Private video" && title != "Deleted video" else { continue }

            let channelTitle = snippet["videoOwnerChannelTitle"] as? String ?? snippet["channelTitle"] as? String ?? "Unknown Artist"
            let artist = channelTitle.replacingOccurrences(of: " - Topic", with: "").trimmingCharacters(in: .whitespaces)
            let categoryId = snippet["categoryId"] as? String

            var duration: TimeInterval = 210
            if let contentDetails = item["contentDetails"] as? [String: Any],
               let durStr = contentDetails["duration"] as? String {
                let parsed = parseISO8601Duration(durStr)
                if parsed > 0 { duration = parsed }
            }

            // Strict classification: requires categoryId == "10" (Music) and checks non-music keywords
            let classificationResult = MusicClassificationService.classify(
                title: title,
                channelOrArtist: channelTitle,
                duration: duration,
                categoryId: categoryId
            )

            guard classificationResult.classification.isPlayableSong else {
                continue
            }

            var artworkURL: URL?
            if let thumbs = snippet["thumbnails"] as? [String: Any] {
                if let maxres = thumbs["maxres"] as? [String: Any], let urlStr = maxres["url"] as? String {
                    artworkURL = URL(string: urlStr)
                } else if let high = thumbs["high"] as? [String: Any], let urlStr = high["url"] as? String {
                    artworkURL = URL(string: urlStr)
                } else if let standard = thumbs["standard"] as? [String: Any], let urlStr = standard["url"] as? String {
                    artworkURL = URL(string: urlStr)
                }
            }

            let song = Song(
                id: id,
                title: title,
                artist: artist,
                duration: duration,
                artworkURL: artworkURL,
                sourceId: "youtube"
            )
            songs.append(song)
        }

        return (songs, nextPageToken)
    }

    private func fetchLikedMusic(accessToken: String) async throws -> [Song] {
        var songs: [Song] = []
        var nextPageToken: String? = nil
        var pageCount = 0
        let maxPages = 5 // Fetch up to 250 liked songs

        repeat {
            pageCount += 1
            // Official YouTube Data API v3: myRating=like returns all user liked videos.
            // videoCategoryId is mutually exclusive with myRating in videos.list and cannot be passed in query params.
            var urlString = "https://www.googleapis.com/youtube/v3/videos?part=snippet,contentDetails&myRating=like&maxResults=50"
            if let token = nextPageToken {
                urlString += "&pageToken=\(token)"
            }
            guard let url = URL(string: urlString) else { break }

            var req = URLRequest(url: url)
            req.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

            let (data, resp) = try await URLSession.shared.data(for: req)
            guard let http = resp as? HTTPURLResponse else { break }

            if http.statusCode == 403 {
                let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
                if let errorObj = json?["error"] as? [String: Any],
                   let errors = errorObj["errors"] as? [[String: Any]],
                   let reason = errors.first?["reason"] as? String,
                   reason == "quotaExceeded" || reason == "rateLimitExceeded" {
                    throw HawkError.networkError("YouTube API daily quota exceeded (10,000 units/day). Sync will resume after quota resets.")
                }
                break
            }

            guard (200...299).contains(http.statusCode) else {
                break
            }

            let result = try Self.parseLikedVideosResponse(data: data)
            songs.append(contentsOf: result.songs)
            nextPageToken = result.nextPageToken
        } while nextPageToken != nil && pageCount < maxPages

        return songs
    }

    // MARK: - PKCE & Cryptography Helpers (RFC 7636 & OIDC Core 1.0)
    nonisolated public static func generateCodeVerifier() -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return Data(bytes).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    nonisolated public static func generateCodeChallenge(from verifier: String) -> String {
        guard let data = verifier.data(using: .utf8) else { return verifier }
        let digest = CryptoUtils.sha256(data: data)
        return digest.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    nonisolated public static func generateStateToken() -> String {
        generateCodeVerifier()
    }

    nonisolated public static func generateNonce() -> String {
        generateCodeVerifier()
    }
}

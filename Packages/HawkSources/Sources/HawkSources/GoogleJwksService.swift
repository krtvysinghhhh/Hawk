import Foundation
import Security
import HawkCore

/// Thread-safe wrapper around immutable CoreFoundation `SecKey` for Swift concurrency boundaries.
public struct SendableSecKey: @unchecked Sendable {
    public let rawKey: SecKey
    public init(_ rawKey: SecKey) {
        self.rawKey = rawKey
    }
}

/// Thread-safe service for fetching, parsing, caching, and rotating Google's OpenID Connect JSON Web Key Set (JWKS).
///
/// Google signs OpenID Connect ID tokens with RSA keys published at:
/// `https://www.googleapis.com/oauth2/v3/certs`
///
/// Security characteristics:
/// - RFC 7517 compliant JSON Web Key parser
/// - Derives native Apple Security `SecKey` RSA public keys via PKCS#1 DER encoding
/// - Safe cache expiration honoring HTTP `Cache-Control: max-age=...` (clamped [300s, 86400s])
/// - Outbound network rate-limiting (min 10s interval) to protect against DoS/cache-busting attacks
/// - Seamless key rotation support on cache invalidation or encountering an un-cached `kid`
public actor GoogleJwksService {
    public static let shared = GoogleJwksService()

    private let jwksURL: URL
    private var cachedKeys: [String: SecKey]
    private var cacheExpiration: Date
    private var lastFetchTime: Date
    private let minFetchInterval: TimeInterval

    public init(
        jwksURL: URL = URL(string: "https://www.googleapis.com/oauth2/v3/certs")!,
        preloadedKeys: [String: SecKey] = [:],
        minFetchInterval: TimeInterval = 10.0
    ) {
        self.jwksURL = jwksURL
        self.cachedKeys = preloadedKeys
        self.cacheExpiration = preloadedKeys.isEmpty ? .distantPast : .distantFuture
        self.lastFetchTime = .distantPast
        self.minFetchInterval = minFetchInterval
    }

    /// Retrieves an RSA public `SecKey` for the given Key ID (`kid`).
    /// If not present or if cache has expired, fetches fresh keys from Google's JWKS endpoint.
    public func getKey(for kid: String, forceRefresh: Bool = false) async throws -> SendableSecKey {
        let now = Date()

        // 1. Return cached key if valid and not forcing refresh
        if !forceRefresh, now < cacheExpiration, let key = cachedKeys[kid] {
            return SendableSecKey(key)
        }

        // 2. Fetch fresh JWKS if expired or missing key
        try await fetchJwksIfNeeded(force: forceRefresh || cachedKeys[kid] == nil)

        // 3. Look up key after fetch
        guard let key = cachedKeys[kid] else {
            throw GoogleMusicSyncManager.IdTokenValidationError.unknownSigningKey(kid)
        }

        return SendableSecKey(key)
    }

    /// Preloads keys directly into cache (used for testing without network requests).
    public func preloadKey(kid: String, key: SecKey) {
        self.cachedKeys[kid] = key
        self.cacheExpiration = .distantFuture
    }

    /// Fetches and parses JWKS from Google's endpoint with safe HTTP caching and rate limiting.
    private func fetchJwksIfNeeded(force: Bool) async throws {
        let now = Date()

        // Protect against cache-busting floods from attacker-crafted unknown `kid`s
        if !force && now.timeIntervalSince(lastFetchTime) < minFetchInterval && !cachedKeys.isEmpty {
            return
        }

        var request = URLRequest(url: jwksURL)
        request.timeoutInterval = 15.0
        request.cachePolicy = .reloadIgnoringLocalCacheData

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw GoogleMusicSyncManager.IdTokenValidationError.networkError("Failed to reach Google JWKS: \(error.localizedDescription)")
        }

        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            let status = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw GoogleMusicSyncManager.IdTokenValidationError.networkError("Google JWKS returned HTTP status \(status)")
        }

        self.lastFetchTime = now

        // Parse Cache-Control header max-age
        let ttl = parseCacheControlMaxAge(from: httpResponse) ?? 21600 // Default 6 hours
        self.cacheExpiration = now.addingTimeInterval(ttl)

        // Parse keys from JWKS JSON
        let parsedKeys = try Self.parseJwks(data: data)
        self.cachedKeys = parsedKeys
    }

    /// Parses the `max-age` value from `Cache-Control` header, clamped to safe boundaries [300s, 86400s].
    private func parseCacheControlMaxAge(from response: HTTPURLResponse) -> TimeInterval? {
        guard let cacheControl = response.value(forHTTPHeaderField: "Cache-Control") else {
            return nil
        }
        let directives = cacheControl.components(separatedBy: ",")
        for directive in directives {
            let trimmed = directive.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if trimmed.hasPrefix("max-age=") {
                let valStr = trimmed.dropFirst("max-age=".count)
                if let sec = Double(valStr) {
                    return max(300, min(86400, sec)) // Clamp between 5 minutes and 24 hours
                }
            }
        }
        return nil
    }

    /// Parses JWKS JSON into a dictionary of `[kid: SecKey]`.
    nonisolated public static func parseJwks(data: Data) throws -> [String: SecKey] {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let keysArray = json["keys"] as? [[String: Any]] else {
            throw GoogleMusicSyncManager.IdTokenValidationError.invalidJson("JWKS payload is not valid JSON")
        }

        var result: [String: SecKey] = [:]
        for keyDict in keysArray {
            guard let kid = keyDict["kid"] as? String, !kid.isEmpty,
                  let kty = keyDict["kty"] as? String, kty == "RSA",
                  let nStr = keyDict["n"] as? String,
                  let eStr = keyDict["e"] as? String else {
                continue
            }

            // Enforce algorithm if present: must be RS256
            if let alg = keyDict["alg"] as? String, alg != "RS256" {
                continue
            }

            // Enforce key use if present: must be sig
            if let use = keyDict["use"] as? String, use != "sig" {
                continue
            }

            guard let nData = GoogleMusicSyncManager.base64UrlDecode(nStr),
                  let eData = GoogleMusicSyncManager.base64UrlDecode(eStr),
                  let secKey = createRsaPublicKey(modulus: nData, exponent: eData) else {
                continue
            }

            result[kid] = secKey
        }

        guard !result.isEmpty else {
            throw GoogleMusicSyncManager.IdTokenValidationError.invalidPublicKeyData
        }

        return result
    }

    /// Constructs an RSA Public `SecKey` in PKCS#1 DER format from raw modulus and exponent bytes.
    nonisolated public static func createRsaPublicKey(modulus: Data, exponent: Data) -> SecKey? {
        let modInt = encodeAsn1Integer(modulus)
        let expInt = encodeAsn1Integer(exponent)
        let seq = encodeAsn1Sequence([modInt, expInt])

        let attributes: [CFString: Any] = [
            kSecAttrKeyType: kSecAttrKeyTypeRSA,
            kSecAttrKeyClass: kSecAttrKeyClassPublic
        ]
        var error: Unmanaged<CFError>?
        return SecKeyCreateWithData(seq as CFData, attributes as CFDictionary, &error)
    }

    /// Encodes raw binary data as an ASN.1 INTEGER (Tag: 0x02) with leading 0x00 if high bit is set.
    nonisolated public static func encodeAsn1Integer(_ data: Data) -> Data {
        var result = Data([0x02])
        var val = data
        if let first = val.first, first >= 0x80 {
            val.insert(0x00, at: 0)
        }
        let length = val.count
        if length < 128 {
            result.append(UInt8(length))
        } else if length < 256 {
            result.append(contentsOf: [0x81, UInt8(length)])
        } else {
            result.append(contentsOf: [0x82, UInt8(length >> 8), UInt8(length & 0xFF)])
        }
        result.append(val)
        return result
    }

    /// Encodes a list of ASN.1 DER elements into an ASN.1 SEQUENCE (Tag: 0x30).
    nonisolated public static func encodeAsn1Sequence(_ elements: [Data]) -> Data {
        let combined = elements.reduce(Data(), +)
        var result = Data([0x30])
        let length = combined.count
        if length < 128 {
            result.append(UInt8(length))
        } else if length < 256 {
            result.append(contentsOf: [0x81, UInt8(length)])
        } else {
            result.append(contentsOf: [0x82, UInt8(length >> 8), UInt8(length & 0xFF)])
        }
        result.append(combined)
        return result
    }
}

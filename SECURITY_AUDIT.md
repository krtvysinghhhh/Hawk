# PROJECT HAWK — SECURITY ENGINEERING & THREAT MODEL

**Document ID:** HAWK-DOC-M1-005  
**Project:** HAWK (Native iOS Music Application)  
**Security Posture:** Local-First, Zero Telemetry, Hardware-Backed Secure Storage  
**Audit Date:** 2026-11-02  

---

## 1. Threat Modeling & Security Principles

HAWK adheres strictly to the Absolute Engineering Rules (Rules 8, 9, 10, 16, 19). The security architecture is designed around four non-negotiable principles:

1. **Zero Hardcoded Secrets:** No API keys, OAuth client secrets, private signing keys, or server passwords will ever exist in source code, configuration files, or Git history.
2. **Hardware-Backed Credential Storage:** All sensitive session cookies (YouTube Music SAPISID/HSID), Spotify OAuth tokens, and scrobbling credentials must reside in the **Apple Keychain Services** (`kSecClassGenericPassword` with `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`).
3. **Mandatory Secure Transport (TLS 1.3):** Every network call uses HTTPS with strict system certificate validation. Cleartext HTTP (`usesCleartextTraffic`) is forbidden via `App Transport Security (ATS)`.
4. **Local-First Privacy & Zero Telemetry:** HAWK collects no analytics, contains no third-party tracking SDKs (Firebase, AppsFlyer, Sentry), and transmits zero telemetry. Listening statistics never leave the local device sandbox.

---

## 2. Threat Vector Analysis & Mitigation Matrix

| Threat Vector | Description / Risk | HAWK Mitigation Strategy |
|---|---|---|
| **Credential Theft from Disk** | Attacker extracts application data from unencrypted backups or local storage | Passwords, bearer tokens, and session cookies are stored exclusively in the iOS Keychain with `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`. Credentials are excluded from iTunes/iCloud backups. |
| **Man-in-the-Middle (MitM) Attack** | Network attacker intercepts audio stream requests or user authentication | Strict ATS configuration in `Info.plist`. System trust store enforcement. No certificate pinning bypasses or TLS downgrades permitted. |
| **Path Traversal / Sandbox Escape** | Malicious audio file or downloaded playlist attempts directory traversal | Strict URL sanitization and normalization using Swift `URL.standardized`. All local files reside within isolated `FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)` subdirectories. |
| **Credential Leakage in Logs** | Sensitive cookies or auth headers dumped to console or crash reports | Strict logging policy: `Logger` / `os_log` redaction filters strip `Cookie`, `Authorization`, and `SAPISIDHASH` headers before outputting to debug logs. |
| **Memory Scraping of Tokens** | Sensitive tokens linger in plaintext memory | Tokens are loaded into memory only on-demand during request construction and encapsulated within isolated actors (`AuthManager`). |
| **Arbitrary Code Execution via Plugins** | Malicious JavaScript injected via external module sources | Module sources run in sandboxed Apple `JSContext` with restricted global objects (no filesystem, no arbitrary networking beyond controlled HTTP fetch delegate). |
| **DRM / Policy Violation** | Scraping encrypted streams or circumventing access controls | HAWK accesses only authorized, publicly accessible, or lawful user-authenticated streams. No DRM bypasses are implemented. |

---

## 3. Apple Keychain Implementation Architecture

In HAWK, the `KeychainStore` actor implements secure, type-safe credential persistence:

```swift
// HawkSecurity / KeychainStore.swift
import Foundation
import Security

public actor KeychainStore {
    public static let shared = KeychainStore()
    private let service = "com.hawk.music.auth"

    public func save(key: String, data: Data) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
        SecItemDelete(query as CFDictionary)
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else { throw KeychainError.secFailure(status) }
    }

    public func read(key: String) throws -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = item as? Data else {
            throw KeychainError.secFailure(status)
        }
        return data
    }

    public func delete(key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(query as CFDictionary)
    }
}
```

---

## 4. App Sandbox & Privacy Enforcements

1. **Microphone / Camera:** Not requested. HAWK does not require audio recording or camera permissions.
2. **Local Music Import:** Handled via standard system `UIDocumentPickerViewController` with security-scoped bookmarks (`startAccessingSecurityScopedResource()`), ensuring user consent for file access.
3. **Background Audio:** Declared in `Info.plist` under `UIBackgroundModes` with `audio` key, strictly constrained to active playback sessions.
4. **Data Deletion:** A one-tap "Erase All Data" option in Settings completely wipes the app's document directory, caches, and Keychain items.

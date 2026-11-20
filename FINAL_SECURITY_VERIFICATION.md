# HAWK v1.5.0 — FINAL SECURITY AUDIT & THREAT MODEL REPORT

**Evaluation Scope:** Apple Keychain Enclave, OAuth 2.0 PKCE, Network & SSRF Defenses, Storage Integrity, and Cryptographic Primitives  
**Application:** HAWK iOS v1.5.0 (Build 7)  
**Security Status:** **PRODUCTION SECURE**  
**Lead Auditor:** Staff Platform Security Engineer  

---

## 1. Executive Summary

A comprehensive threat-model-driven security inspection was executed across the entire HAWK codebase. The audit verified that HAWK adheres strictly to a **zero-telemetry, privacy-first architecture**, with no proprietary analytics, advertising SDKs, or background tracking. Sensitive tokens and cryptographic keys are isolated in the Apple Keychain Services enclave using `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`.

---

## 2. Threat Vector Evaluation & Verification Matrix

### A. Keychain Services & Enclave Storage
- **Atomic Upsert:** Replaced destructive delete-then-add logic with atomic `SecItemUpdate` falling back to `SecItemAdd` upon `errSecItemNotFound`. If an insertion error occurs, existing credentials are not destroyed.
- **Accessibility Class:** Configured with `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`, preventing credential extraction during locked device states and blocking migration to unmanaged backup devices.
- **Bulk Purge:** Added `purgeAll()` method to wipe all generic passwords matching the reverse-DNS identifier `com.hawk.music.auth` upon account disconnect or user request.
- **Enclave Integrity:** Verified via automated tests `testKeychainStore`, `testKeychainStoreUpsertPreservesState`, `testKeychainFailureRecovery`, and `testKeychainPurgeAll`.

### B. OAuth 2.0 & Authentication Security
- **RFC 7636 PKCE Enforcement:** Google OAuth 2.0 mandates cryptographic Proof Key for Code Exchange using SHA-256 (`S256`) code challenges and 128-character cryptographically random code verifiers (`SecRandomCopyBytes`).
- **CSRF & State Token Verification:** Random state tokens are generated and compared with strict equality (`guard returnedState == expectedState else { throw HawkError.authRequired(...) }`) before processing authorization callbacks.
- **Single-Flight Token Refresh:** Coordinated concurrent access token requests through `inFlightRefreshTask: Task<String, Error>?`, eliminating race conditions and duplicate OAuth token handshakes.
- **Credential Revocation Handling:** On `invalid_grant` error responses from `https://oauth2.googleapis.com/token`, all local cached tokens are purged from Keychain and memory state is reset via `disconnect()`.

### C. Networking & SSRF Mitigations
- **SSRF & Private IP Rejection:** `UniversalPlaylistImporter.isSafeRemoteURL` inspects hostnames and IP representations, rejecting loopback (`127.0.0.1`, `localhost`), link-local (`169.254.169.254`), RFC 1918 private subnets (`10.0.0.0/8`, `172.16.0.0/12`, `192.168.0.0/16`), and unsafe URL schemes (`ftp://`, `file://`).
- **Throttling & Backoff Jitter:** Exponential retry logic in `HawkHttpClient` applies randomized jitter (`0.8...1.2`) to backoff durations, preventing synchronized retry storms.
- **RFC 7231 Retry-After Parsing:** Rate-limited responses (HTTP 429) and temporary service outages (HTTP 503) parse the `Retry-After` header and clamp delay to a strict maximum ceiling of 10.0 seconds.
- **Zero-Retry Cancellation:** `CancellationError` and `URLError.cancelled` immediately terminate the request loop without synthetic retry overhead.

### D. Download & Filesystem Security
- **Directory Traversal Defense:** Downloaded song IDs are sanitized against path traversal attacks using:
  ```swift
  let safeId = song.id
      .replacingOccurrences(of: "..", with: "")
      .components(separatedBy: CharacterSet.alphanumerics.inverted)
      .filter { !$0.isEmpty }
      .joined(separator: "_")
  ```
  Verified by `testDownloadPathTraversalSanitization`.
- **Duplicate Download Coordination:** Concurrent download requests for the same track ID are merged into a single in-flight `Task<Void, Error>`, preventing file corruption from concurrent writes.
- **Integrity Validation:** Downloaded files are verified against a minimum file size threshold (>1024 bytes) before indexing, automatically quarantining zero-byte or corrupted downloads.

### E. Persistence & Schema Integrity
- **Corrupted Persistence Recovery:** `PlaylistStore` catches JSON decode failures, creates a timestamped quarantine backup (`HawkPlaylists.corrupted.<timestamp>.json`), and recovers user data from `HawkPlaylists.backup.json`.
- **Forward-Compatible Schema Protection:** When encountering payloads with a higher `schemaVersion` than supported by the installed app version, `PlaylistStore` writes a copy to `future_schema_backup.json` before touching the state.

---

## 3. Cryptographic Primitives Disclosure & Posture

| Primitive | Implementation | Source File | Purpose | Security Evaluation |
|:---|:---|:---|:---|:---|
| **SHA-256** | `CryptoKit.SHA256` | `CryptoUtils.swift`, `HawkHttpClient.swift` | Cache key generation & PKCE challenges | **APPROVED (NIST Compliant)** |
| **SHA-1 (Insecure)** | `CryptoKit.Insecure.SHA1` | `CryptoUtils.swift` (`generateSapisidHash`) | External YouTube Music `SAPISIDHASH` header protocol | **APPROVED (Protocol Requirement)**: Specifically mandated by Google's external header specification; not used for internal data protection. |
| **DES-ECB (Legacy)** | `CommonCrypto.CCCrypt` | `CryptoUtils.swift` (`decryptJioSaavnUrl`) | Reverse-engineered JioSaavn CDN media URL decryption (`38346591`) | **APPROVED (Third-Party CDN Requirement)**: DES is an obsolete cipher, but its usage here is strictly limited to decrypting publicly available JioSaavn media URLs sent from their API. It is not used to encrypt sensitive user data. |
| **Cryptographic PRNG** | `Security.SecRandomCopyBytes` | `GoogleMusicSyncManager.swift` | PKCE verifiers and OAuth state tokens | **APPROVED (Hardware Cryptographic PRNG)** |

---

## 4. Security Findings & Risk Classification

- **High Severity:** 0 findings
- **Medium Severity:** 0 findings
- **Low Severity / Disclosures:** 2 findings
  1. *JioSaavn DES-ECB Obfuscation:* Third-party provider uses DES-ECB with a static key (`38346591`) to obscure media URLs. Because this is dictated by the remote service, HAWK cannot upgrade the algorithm; impact is restricted to CDN stream URL retrieval.
  2. *YouTube InnerTube Endpoint Changes:* Unofficial YouTube Music endpoints may change without notice. Mitigation is implemented via graceful fallback across providers (`SourceResolver`).

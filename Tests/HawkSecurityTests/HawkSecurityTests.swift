import XCTest
@testable import HawkSecurity

final class HawkSecurityTests: XCTestCase {

    func testSapisidHash() {
        let timestamp: Int64 = 1700000000
        let sapisid = "test_sapisid_value"
        let origin = "https://music.youtube.com"

        let hash = CryptoUtils.generateSapisidHash(
            sapisid: sapisid,
            origin: origin,
            timestamp: timestamp
        )

        XCTAssertTrue(hash.hasPrefix("SAPISIDHASH 1700000000_"))
    }

    func testSha256Hex() {
        let hash = CryptoUtils.sha256Hex("HAWK_MUSIC_APP")
        XCTAssertEqual(hash.count, 64)
    }

    func testKeychainStore() async throws {
        let store = KeychainStore(serviceName: "com.hawk.test.auth")
        let key = "test_auth_cookie"
        let value = "SID=123; HSID=456; SSID=789;"

        try await store.saveString(key: key, value: value)
        let retrieved = try await store.readString(key: key)

        XCTAssertEqual(retrieved, value)

        try await store.delete(key: key)
        let afterDelete = try await store.readString(key: key)
        XCTAssertNil(afterDelete)
    }

    func testKeychainStoreUpsertPreservesState() async throws {
        let store = KeychainStore(serviceName: "com.hawk.test.upsert", inMemoryOnly: true)
        let key = "sync_token"

        try await store.saveString(key: key, value: "initial_token_123")
        let first = try await store.readString(key: key)
        XCTAssertEqual(first, "initial_token_123")

        // Overwrite via atomic upsert
        try await store.saveString(key: key, value: "updated_token_456")
        let updated = try await store.readString(key: key)
        XCTAssertEqual(updated, "updated_token_456")

        try await store.delete(key: key)
        let deleted = try await store.readString(key: key)
        XCTAssertNil(deleted)
    }

    func testKeychainFailureRecovery() async throws {
        let store = KeychainStore(serviceName: "com.hawk.test.recovery", inMemoryOnly: true)
        // Reading non-existent key returns nil
        let nonExistent = try await store.readString(key: "non_existent_key")
        XCTAssertNil(nonExistent)

        // Deleting non-existent key succeeds without throwing
        try await store.delete(key: "non_existent_key")
    }

    func testKeychainPurgeAll() async throws {
        let store = KeychainStore(serviceName: "com.hawk.test.purge", inMemoryOnly: true)
        try await store.saveString(key: "k1", value: "v1")
        try await store.saveString(key: "k2", value: "v2")

        try await store.purgeAll()

        let v1 = try await store.readString(key: "k1")
        let v2 = try await store.readString(key: "k2")
        XCTAssertNil(v1)
        XCTAssertNil(v2)
    }
}

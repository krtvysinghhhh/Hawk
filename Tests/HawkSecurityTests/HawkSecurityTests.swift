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

        await store.delete(key: key)
        let afterDelete = try await store.readString(key: key)
        XCTAssertNil(afterDelete)
    }
}

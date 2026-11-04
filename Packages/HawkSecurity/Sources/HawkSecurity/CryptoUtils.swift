import Foundation
import CryptoKit
import CommonCrypto
import HawkCore

/// Cryptographic primitives for authentication and stream URL decryption.
public enum CryptoUtils {

    /// Generates YouTube's SAPISIDHASH authentication authorization header.
    /// Format: `SAPISIDHASH {timestamp}_{sha1(timestamp + " " + sapisid + " " + origin)}`
    public static func generateSapisidHash(
        sapisid: String,
        origin: String = "https://music.youtube.com",
        timestamp: Int64 = Int64(Date().timeIntervalSince1970)
    ) -> String {
        let payload = "\(timestamp) \(sapisid) \(origin)"
        guard let data = payload.data(using: .utf8) else { return "" }
        let digest = Insecure.SHA1.hash(data: data)
        let hashString = digest.map { String(format: "%02x", $0) }.joined()
        return "SAPISIDHASH \(timestamp)_\(hashString)"
    }

    /// Computes standard SHA-256 hex string for cache keys.
    public static func sha256Hex(_ input: String) -> String {
        guard let data = input.data(using: .utf8) else { return "" }
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    /// Computes SHA-256 data digest.
    public static func sha256(data: Data) -> Data {
        Data(SHA256.hash(data: data))
    }

    /// Decrypts JioSaavn's DES-encrypted media URL string using the key "38346591".
    public static func decryptJioSaavnUrl(
        encryptedUrl: String,
        desKey: String = "38346591"
    ) throws -> String {
        guard let cipherData = Data(base64Encoded: encryptedUrl),
              let keyData = desKey.data(using: .utf8) else {
            throw HawkError.decodeError("Invalid Base64 or Key for JioSaavn DES")
        }

        var decryptedBytes = [UInt8](repeating: 0, count: cipherData.count + kCCBlockSizeDES)
        var numBytesDecrypted: size_t = 0

        let status = CCCrypt(
            CCOperation(kCCDecrypt),
            CCAlgorithm(kCCAlgorithmDES),
            CCOptions(kCCOptionPKCS7Padding | kCCOptionECBMode),
            (keyData as NSData).bytes,
            kCCKeySizeDES,
            nil,
            (cipherData as NSData).bytes,
            cipherData.count,
            &decryptedBytes,
            decryptedBytes.count,
            &numBytesDecrypted
        )

        guard status == kCCSuccess else {
            throw HawkError.decodeError("DES decryption failed with status \(status)")
        }

        let decryptedData = Data(bytes: decryptedBytes, count: numBytesDecrypted)
        guard let decryptedString = String(data: decryptedData, encoding: .utf8) else {
            throw HawkError.decodeError("Decrypted data is not valid UTF-8")
        }

        return decryptedString
    }
}

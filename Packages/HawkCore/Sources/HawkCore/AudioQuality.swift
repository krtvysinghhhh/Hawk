import Foundation

/// Audio quality representation and ceiling limits for network connections.
public enum AudioQuality: String, Codable, Sendable, CaseIterable {
    case low = "LOW"
    case standard = "STANDARD"
    case high = "HIGH"
    case lossless = "LOSSLESS"

    public var maxKbps: Int {
        switch self {
        case .low: return 96
        case .standard: return 160
        case .high: return 320
        case .lossless: return Int.max
        }
    }

    public var displayName: String {
        switch self {
        case .low: return "Data Saver (96 kbps)"
        case .standard: return "Standard (160 kbps)"
        case .high: return "High (320 kbps)"
        case .lossless: return "Lossless (FLAC/ALAC)"
        }
    }

    public var isLossless: BooleanLiteralType {
        self == .lossless
    }
}

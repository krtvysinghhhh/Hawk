import Foundation

/// Unified typed errors across HAWK subsystems.
public enum HawkError: LocalizedError, Sendable, Hashable {
    case networkError(String)
    case invalidResponse(Int)
    case streamNotFound(String)
    case playbackFailed(String)
    case keychainError(String)
    case storageError(String)
    case decodeError(String)
    case unauthorized
    case cancelled

    public var errorDescription: String? {
        switch self {
        case .networkError(let msg): return "Network connection error: \(msg)"
        case .invalidResponse(let code): return "Server responded with status \(code)"
        case .streamNotFound(let id): return "Unable to resolve audio stream for track: \(id)"
        case .playbackFailed(let msg): return "Audio playback error: \(msg)"
        case .keychainError(let msg): return "Secure Keychain error: \(msg)"
        case .storageError(let msg): return "Storage error: \(msg)"
        case .decodeError(let msg): return "Data parsing error: \(msg)"
        case .unauthorized: return "Authentication required"
        case .cancelled: return "Operation cancelled"
        }
    }
}

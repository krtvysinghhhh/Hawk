import Foundation

/// Unified typed errors across HAWK subsystems.
public enum HawkError: LocalizedError, Sendable, Hashable {
    case networkError(String)
    case invalidResponse(Int)
    case streamNotFound(String)
    case sourceUnavailable(String)
    case playbackUnsupported(String)
    case playbackFailed(String)
    case regionRestricted(String)
    case formatUnsupported(String)
    case lyricsUnavailable(String)
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
        case .sourceUnavailable(let src): return "Music source '\(src)' is temporarily unavailable"
        case .playbackUnsupported(let msg): return "Playback unsupported: \(msg)"
        case .playbackFailed(let msg): return "Audio playback error: \(msg)"
        case .regionRestricted(let msg): return "Track is restricted in this region: \(msg)"
        case .formatUnsupported(let fmt): return "Audio format '\(fmt)' is unsupported"
        case .lyricsUnavailable(let msg): return "Lyrics aren't available for this track."
        case .keychainError(let msg): return "Secure Keychain error: \(msg)"
        case .storageError(let msg): return "Storage error: \(msg)"
        case .decodeError(let msg): return "Data parsing error: \(msg)"
        case .unauthorized: return "Provider authentication required"
        case .cancelled: return "Operation cancelled"
        }
    }
}

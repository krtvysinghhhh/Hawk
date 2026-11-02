import Foundation

/// Tier of an item in the playback queue.
///
/// HAWK preserves queue stability by isolating user-inserted tracks from contextual album/playlist tracks.
public enum QueueTier: String, Codable, Sendable, CaseIterable {
    /// Explicitly queued by the user ("Play Next", "Add to Queue").
    case userQueue = "USER_QUEUE"

    /// Part of the active Album, Playlist, or Artist collection context.
    case context = "CONTEXT"

    /// Dynamically generated recommendations appended when context or user queue concludes.
    case autoplay = "AUTOPLAY"

    public var displayName: String {
        switch self {
        case .userQueue: return "Up Next"
        case .context: return "Current Context"
        case .autoplay: return "Similar Music"
        }
    }
}

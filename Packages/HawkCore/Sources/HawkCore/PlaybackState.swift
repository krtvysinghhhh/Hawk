import Foundation

/// State of the audio playback engine.
public enum PlaybackState: Sendable, Equatable {
    case idle
    case loading(Song)
    case buffering(Song)
    case ready(Song)
    case playing(Song)
    case paused(Song)
    case seeking(Song, TimeInterval)
    case ended(Song)
    case failed(Song?, HawkError)

    public var isPlaying: Bool {
        if case .playing = self { return true }
        return false
    }

    public var isPaused: Bool {
        if case .paused = self { return true }
        return false
    }

    public var isBuffering: Bool {
        switch self {
        case .buffering, .loading: return true
        default: return false
        }
    }

    public var currentSong: Song? {
        switch self {
        case .loading(let song),
             .buffering(let song),
             .ready(let song),
             .playing(let song),
             .paused(let song),
             .seeking(let song, _),
             .ended(let song):
            return song
        case .failed(let song, _):
            return song
        case .idle:
            return nil
        }
    }

    public var errorMessage: String? {
        if case .failed(_, let err) = self {
            return err.localizedDescription
        }
        return nil
    }
}

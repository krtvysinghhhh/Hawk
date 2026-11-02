import Foundation

/// State of the audio playback engine.
public enum PlaybackState: Sendable, Equatable {
    case idle
    case loading(Song)
    case playing(Song)
    case paused(Song)
    case completed
    case failed(HawkError)

    public var isPlaying: Bool {
        if case .playing = self { return true }
        return false
    }

    public var currentSong: Song? {
        switch self {
        case .loading(let song), .playing(let song), .paused(let song):
            return song
        default:
            return nil
        }
    }
}

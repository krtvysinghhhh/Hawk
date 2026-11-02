import Foundation
import HawkCore

public struct TrackPlayStat: Codable, Sendable, Identifiable {
    public var id: String { songId }
    public let songId: String
    public let title: String
    public let artist: String
    public var playCount: Int
    public var totalSeconds: Double

    public init(songId: String, title: String, artist: String, playCount: Int = 1, totalSeconds: Double = 0) {
        self.songId = songId
        self.title = title
        self.artist = artist
        self.playCount = playCount
        self.totalSeconds = totalSeconds
    }
}

public struct ArtistPlayStat: Codable, Sendable, Identifiable {
    public var id: String { name }
    public let name: String
    public var playCount: Int
    public var totalSeconds: Double

    public init(name: String, playCount: Int = 1, totalSeconds: Double = 0) {
        self.name = name
        self.playCount = playCount
        self.totalSeconds = totalSeconds
    }
}

/// Monthly aggregate listening bucket stored in a local JSON document.
public struct MonthlyBucket: Codable, Sendable {
    public let monthKey: String // "YYYY-MM"
    public var totalListeningSeconds: Double
    public var tracks: [String: TrackPlayStat]
    public var artists: [String: ArtistPlayStat]
    public var dailyListeningSeconds: [Int: Double] // Day of month -> seconds

    public init(monthKey: String) {
        self.monthKey = monthKey
        self.totalListeningSeconds = 0
        self.tracks = [:]
        self.artists = [:]
        self.dailyListeningSeconds = [:]
    }

    public var topTracks: [TrackPlayStat] {
        tracks.values.sorted { $0.playCount > $1.playCount }
    }

    public var topArtists: [ArtistPlayStat] {
        artists.values.sorted { $0.playCount > $1.playCount }
    }
}

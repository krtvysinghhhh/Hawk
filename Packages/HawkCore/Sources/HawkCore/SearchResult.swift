import Foundation

/// Filter categories for catalogue searches.
public enum SearchFilter: String, Codable, Sendable, CaseIterable {
    case all = "ALL"
    case songs = "SONGS"
    case albums = "ALBUMS"
    case artists = "ARTISTS"
    case playlists = "PLAYLISTS"

    public var displayName: String {
        switch self {
        case .all: return "All"
        case .songs: return "Songs"
        case .albums: return "Albums"
        case .artists: return "Artists"
        case .playlists: return "Playlists"
        }
    }
}

/// Unified search result item across providers.
public enum SearchItem: Identifiable, Sendable, Hashable {
    case song(Song)
    case album(AlbumPreview)
    case artist(ArtistPreview)
    case playlist(PlaylistPreview)

    public var id: String {
        switch self {
        case .song(let s): return "song_\(s.id)"
        case .album(let a): return "album_\(a.id)"
        case .artist(let r): return "artist_\(r.id)"
        case .playlist(let p): return "playlist_\(p.id)"
        }
    }
}

public struct AlbumPreview: Identifiable, Codable, Sendable, Hashable {
    public let id: String
    public let title: String
    public let artist: String
    public let year: String?
    public let artworkURL: URL?

    public init(id: String, title: String, artist: String, year: String? = nil, artworkURL: URL? = nil) {
        self.id = id
        self.title = title
        self.artist = artist
        self.year = year
        self.artworkURL = artworkURL
    }
}

public struct ArtistPreview: Identifiable, Codable, Sendable, Hashable {
    public let id: String
    public let name: String
    public let subscribers: String?
    public let artworkURL: URL?

    public init(id: String, name: String, subscribers: String? = nil, artworkURL: URL? = nil) {
        self.id = id
        self.name = name
        self.subscribers = subscribers
        self.artworkURL = artworkURL
    }
}

public struct PlaylistPreview: Identifiable, Codable, Sendable, Hashable {
    public let id: String
    public let title: String
    public let author: String?
    public let trackCount: Int?
    public let artworkURL: URL?

    public init(id: String, title: String, author: String? = nil, trackCount: Int? = nil, artworkURL: URL? = nil) {
        self.id = id
        self.title = title
        self.author = author
        self.trackCount = trackCount
        self.artworkURL = artworkURL
    }
}

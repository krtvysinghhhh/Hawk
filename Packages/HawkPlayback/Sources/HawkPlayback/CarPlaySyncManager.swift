import Foundation
import HawkCore

/// Data item representation for CarPlay browsing hierarchies.
public struct CarPlayBrowsingItem: Sendable, Identifiable {
    public let id: String
    public let title: String
    public let subtitle: String
    public let song: Song?
    public let isContainer: Bool

    public init(id: String = UUID().uuidString, title: String, subtitle: String, song: Song? = nil, isContainer: Bool = false) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.song = song
        self.isContainer = isContainer
    }
}

/// Service aggregating real music data for CarPlay browsing (Recently Played, Playlists, Favourites, Songs, Artists).
public actor CarPlaySyncManager {
    public static let shared = CarPlaySyncManager()

    public init() {}

    /// Fetches user favorites formatted for CarPlay.
    public func fetchFavorites() async -> [CarPlayBrowsingItem] {
        let favorites = await PlaylistStore.shared.getFavorites()
        return favorites.songs.map { song in
            CarPlayBrowsingItem(
                id: song.id,
                title: song.title,
                subtitle: song.artist,
                song: song,
                isContainer: false
            )
        }
    }

    /// Fetches all playlists formatted for CarPlay.
    public func fetchPlaylists() async -> [CarPlayBrowsingItem] {
        let playlists = await PlaylistStore.shared.getAllPlaylists()
        return playlists.map { p in
            CarPlayBrowsingItem(
                id: p.id,
                title: p.title,
                subtitle: "\(p.songs.count) tracks",
                song: nil,
                isContainer: true
            )
        }
    }

    /// Fetches songs in a specific playlist.
    public func fetchSongs(forPlaylistId playlistId: String) async -> [CarPlayBrowsingItem] {
        guard let playlist = await PlaylistStore.shared.getPlaylist(id: playlistId) else { return [] }
        return playlist.songs.map { song in
            CarPlayBrowsingItem(
                id: song.id,
                title: song.title,
                subtitle: song.artist,
                song: song,
                isContainer: false
            )
        }
    }

    /// Fetches songs from the active queue.
    public func fetchQueueItems() async -> [CarPlayBrowsingItem] {
        let queue = await QueueManager.shared.fullTimeline
        return queue.map { song in
            CarPlayBrowsingItem(
                id: song.id,
                title: song.title,
                subtitle: song.artist,
                song: song,
                isContainer: false
            )
        }
    }

    /// Fetches library artists extracted from saved playlists and favorites.
    public func fetchArtists() async -> [CarPlayBrowsingItem] {
        var allSongs: [Song] = []
        let favs = await PlaylistStore.shared.getFavorites().songs
        allSongs.append(contentsOf: favs)
        for p in await PlaylistStore.shared.getAllPlaylists() {
            allSongs.append(contentsOf: p.songs)
        }

        var artistCounts: [String: Int] = [:]
        for s in allSongs {
            let a = s.artist.trimmingCharacters(in: .whitespaces)
            if !a.isEmpty {
                artistCounts[a, default: 0] += 1
            }
        }

        return artistCounts.keys.sorted().map { artist in
            CarPlayBrowsingItem(
                id: artist,
                title: artist,
                subtitle: "\(artistCounts[artist] ?? 0) tracks in library",
                song: nil,
                isContainer: true
            )
        }
    }
}

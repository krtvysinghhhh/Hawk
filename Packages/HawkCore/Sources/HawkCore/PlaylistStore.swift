import Foundation

/// Thread-safe actor managing persistent user playlists and favorites with atomic JSON storage.
public actor PlaylistStore {
    public static let shared = PlaylistStore()

    private let fileURL: URL
    private var playlists: [String: Playlist] = [:]

    public init(storageURL: URL? = nil) {
        let url: URL
        if let customUrl = storageURL {
            url = customUrl
        } else {
            let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            try? FileManager.default.createDirectory(at: appSupport, withIntermediateDirectories: true)
            url = appSupport.appendingPathComponent("HawkPlaylists.json")
        }
        self.fileURL = url

        var initialPlaylists: [String: Playlist] = [:]
        if let data = try? Data(contentsOf: url),
           let list = try? JSONDecoder().decode([Playlist].self, from: data) {
            for p in list {
                initialPlaylists[p.id] = p
            }
        }
        if initialPlaylists[Playlist.favoritesId] == nil {
            let initialFavs = Playlist.favoritesPlaylist()
            initialPlaylists[initialFavs.id] = initialFavs
        }
        self.playlists = initialPlaylists
    }

    // MARK: - Read Operations
    public func getAllPlaylists() -> [Playlist] {
        Array(playlists.values.sorted { $0.title < $1.title })
    }

    public func getPlaylist(id: String) -> Playlist? {
        playlists[id]
    }

    public func getFavorites() -> Playlist {
        playlists[Playlist.favoritesId] ?? Playlist.favoritesPlaylist()
    }

    public func isFavorite(songId: String) -> Bool {
        guard let favs = playlists[Playlist.favoritesId] else { return false }
        return favs.songs.contains { $0.id == songId }
    }

    // MARK: - Write Operations
    public func createPlaylist(title: String) -> Playlist {
        let newPlaylist = Playlist(title: title)
        playlists[newPlaylist.id] = newPlaylist
        save()
        return newPlaylist
    }

    public func deletePlaylist(id: String) {
        guard id != Playlist.favoritesId else { return } // Protect Favorites
        playlists.removeValue(forKey: id)
        save()
    }

    public func toggleFavorite(song: Song) -> Bool {
        var favs = getFavorites()
        let currentlyFavorited = favs.songs.contains { $0.id == song.id }

        if currentlyFavorited {
            favs.songs.removeAll { $0.id == song.id }
        } else {
            favs.songs.insert(song, at: 0) // Newest favorites first
        }

        favs.dateModified = Date()
        playlists[Playlist.favoritesId] = favs
        save()

        return !currentlyFavorited
    }

    public func addSong(to playlistId: String, song: Song) {
        guard var playlist = playlists[playlistId] else { return }
        if !playlist.songs.contains(where: { $0.id == song.id }) {
            playlist.songs.append(song)
            playlist.dateModified = Date()
            playlists[playlistId] = playlist
            save()
        }
    }

    public func removeSong(from playlistId: String, songId: String) {
        guard var playlist = playlists[playlistId] else { return }
        playlist.songs.removeAll { $0.id == songId }
        playlist.dateModified = Date()
        playlists[playlistId] = playlist
        save()
    }

    // MARK: - Persistence
    private func save() {
        guard let data = try? JSONEncoder().encode(Array(playlists.values)) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}

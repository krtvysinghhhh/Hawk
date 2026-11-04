import Foundation

/// Versioned persistence envelope with schema migration and corruption safety.
public struct PlaylistEnvelope: Codable, Sendable {
    public static let currentVersion = 1
    public var schemaVersion: Int
    public var playlists: [Playlist]
    public var timestamp: Date

    public init(playlists: [Playlist], schemaVersion: Int = PlaylistEnvelope.currentVersion, timestamp: Date = Date()) {
        self.schemaVersion = schemaVersion
        self.playlists = playlists
        self.timestamp = timestamp
    }
}

/// Thread-safe actor managing persistent user playlists and favorites with atomic JSON storage,
/// automated migration, corruption detection, and backup recovery.
public actor PlaylistStore {
    public static let shared = PlaylistStore()

    private let fileURL: URL
    private let backupURL: URL
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
        self.backupURL = url.deletingPathExtension().appendingPathExtension("backup.json")

        self.playlists = Self.loadPlaylistsWithRecovery(from: url, backupURL: self.backupURL)
    }

    private static func loadPlaylistsWithRecovery(from url: URL, backupURL: URL) -> [String: Playlist] {
        var initialPlaylists: [String: Playlist] = [:]

        guard FileManager.default.fileExists(atPath: url.path) else {
            let initialFavs = Playlist.favoritesPlaylist()
            return [initialFavs.id: initialFavs]
        }

        if let data = try? Data(contentsOf: url) {
            // Attempt 1: Versioned envelope
            if let envelope = try? JSONDecoder().decode(PlaylistEnvelope.self, from: data) {
                for p in envelope.playlists {
                    initialPlaylists[p.id] = p
                }
            }
            // Attempt 2: Legacy unversioned [Playlist] array (schema v0 migration)
            else if let list = try? JSONDecoder().decode([Playlist].self, from: data) {
                for p in list {
                    initialPlaylists[p.id] = p
                }
            }
            // Attempt 3: Corruption detected -> Quarantine corrupted file and restore from backup
            else {
                let timestamp = Int(Date().timeIntervalSince1970)
                let corruptedURL = url.deletingPathExtension().appendingPathExtension("corrupted.\(timestamp).json")
                try? FileManager.default.copyItem(at: url, to: corruptedURL)

                if FileManager.default.fileExists(atPath: backupURL.path),
                   let backupData = try? Data(contentsOf: backupURL) {
                    if let backupEnv = try? JSONDecoder().decode(PlaylistEnvelope.self, from: backupData) {
                        for p in backupEnv.playlists {
                            initialPlaylists[p.id] = p
                        }
                    } else if let backupList = try? JSONDecoder().decode([Playlist].self, from: backupData) {
                        for p in backupList {
                            initialPlaylists[p.id] = p
                        }
                    }
                }
            }
        }

        if initialPlaylists[Playlist.favoritesId] == nil {
            let initialFavs = Playlist.favoritesPlaylist()
            initialPlaylists[initialFavs.id] = initialFavs
        }

        return initialPlaylists
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
    public func createPlaylist(title: String, initialSongs: [Song] = []) -> Playlist {
        let newPlaylist = Playlist(title: title, songs: initialSongs)
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

    public func importPlaylist(_ playlist: Playlist) {
        playlists[playlist.id] = playlist
        save()
    }

    // MARK: - Persistence & Verification
    private func save() {
        let envelope = PlaylistEnvelope(playlists: Array(playlists.values))
        guard let data = try? JSONEncoder().encode(envelope) else { return }

        let tmpURL = fileURL.appendingPathExtension("tmp")
        do {
            try data.write(to: tmpURL, options: .atomic)

            // Verify write integrity before replacing primary file
            let verifyData = try Data(contentsOf: tmpURL)
            guard (try? JSONDecoder().decode(PlaylistEnvelope.self, from: verifyData)) != nil else {
                try? FileManager.default.removeItem(at: tmpURL)
                return
            }

            // Write backup copy
            try? data.write(to: backupURL, options: .atomic)

            // Atomic rename/move to destination
            if FileManager.default.fileExists(atPath: fileURL.path) {
                _ = try? FileManager.default.replaceItemAt(fileURL, withItemAt: tmpURL)
            } else {
                try? FileManager.default.moveItem(at: tmpURL, to: fileURL)
            }
        } catch {
            try? FileManager.default.removeItem(at: tmpURL)
        }
    }
}

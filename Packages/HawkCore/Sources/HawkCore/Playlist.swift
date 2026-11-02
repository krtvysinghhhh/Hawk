import Foundation

/// A persistent user playlist or smart collection.
public struct Playlist: Identifiable, Codable, Sendable, Hashable {
    public let id: String
    public var title: String
    public var songs: [Song]
    public let dateCreated: Date
    public var dateModified: Date

    public init(
        id: String = UUID().uuidString,
        title: String,
        songs: [Song] = [],
        dateCreated: Date = Date(),
        dateModified: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.songs = songs
        self.dateCreated = dateCreated
        self.dateModified = dateModified
    }

    public static let favoritesId = "hawk_favorites"

    public static func favoritesPlaylist(songs: [Song] = []) -> Playlist {
        Playlist(
            id: favoritesId,
            title: "Favorite Songs",
            songs: songs
        )
    }

    public var isFavorites: Bool {
        id == Playlist.favoritesId
    }
}

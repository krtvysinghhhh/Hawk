import Foundation

/// A playable music track across all HAWK sources.
public struct Song: Identifiable, Codable, Sendable, Hashable {
    /// Unique videoId or track identifier.
    public let id: String
    public let title: String
    public let artist: String
    public let artists: [ArtistRef]
    public let albumTitle: String?
    public let albumId: String?
    public let duration: TimeInterval
    public let durationText: String?
    public let artworkURL: URL?
    public let queueTier: QueueTier
    /// Unique immutable queue entry identifier, preserved across stream updates.
    public let queueEntryId: UUID
    public let localFileURL: URL?
    public let sourceQuality: AudioQuality?
    public let isVideo: Bool
    public let isLiked: Bool

    public init(
        id: String,
        title: String,
        artist: String,
        artists: [ArtistRef] = [],
        albumTitle: String? = nil,
        albumId: String? = nil,
        duration: TimeInterval = 0,
        durationText: String? = nil,
        artworkURL: URL? = nil,
        queueTier: QueueTier = .context,
        queueEntryId: UUID = UUID(),
        localFileURL: URL? = nil,
        sourceQuality: AudioQuality? = nil,
        isVideo: Bool = false,
        isLiked: Bool = false
    ) {
        self.id = id
        self.title = title
        self.artist = artist
        self.artists = artists.isEmpty ? [ArtistRef(name: artist)] : artists
        self.albumTitle = albumTitle
        self.albumId = albumId
        self.duration = duration
        self.durationText = durationText ?? Song.formatDuration(duration)
        self.artworkURL = artworkURL
        self.queueTier = queueTier
        self.queueEntryId = queueEntryId
        self.localFileURL = localFileURL
        self.sourceQuality = sourceQuality
        self.isVideo = isVideo
        self.isLiked = isLiked
    }

    /// Creates a copy of this song assigned to a specific queue tier and unique entry ID.
    public func withQueueMetadata(tier: QueueTier, entryId: UUID = UUID()) -> Song {
        Song(
            id: id,
            title: title,
            artist: artist,
            artists: artists,
            albumTitle: albumTitle,
            albumId: albumId,
            duration: duration,
            durationText: durationText,
            artworkURL: artworkURL,
            queueTier: tier,
            queueEntryId: entryId,
            localFileURL: localFileURL,
            sourceQuality: sourceQuality,
            isVideo: isVideo,
            isLiked: isLiked
        )
    }

    /// Formats a time interval in seconds into mm:ss or hh:mm:ss string.
    public static func formatDuration(_ duration: TimeInterval) -> String {
        guard duration > 0 && !duration.isNaN else { return "--:--" }
        let totalSeconds = Int(duration)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }
}

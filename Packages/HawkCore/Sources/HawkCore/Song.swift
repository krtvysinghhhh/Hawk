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
    public let isrc: String?
    public let mediaUri: String?
    public let sourceId: String?
    public let version: String?
    public let providerIdentifiers: [String: String]
    public let explicitStatus: Bool
    public let dateAdded: Date?

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
        isLiked: Bool = false,
        isrc: String? = nil,
        mediaUri: String? = nil,
        sourceId: String? = nil,
        version: String? = nil,
        providerIdentifiers: [String: String] = [:],
        explicitStatus: Bool = false,
        dateAdded: Date? = Date()
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
        self.isrc = isrc
        self.mediaUri = mediaUri
        self.sourceId = sourceId
        self.version = version ?? Song.extractVersion(from: title)
        var pIds = providerIdentifiers
        if let sId = sourceId, pIds[sId] == nil {
            pIds[sId] = id
        }
        self.providerIdentifiers = pIds
        self.explicitStatus = explicitStatus
        self.dateAdded = dateAdded
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
            isLiked: isLiked,
            isrc: isrc,
            mediaUri: mediaUri,
            sourceId: sourceId,
            version: version,
            providerIdentifiers: providerIdentifiers,
            explicitStatus: explicitStatus,
            dateAdded: dateAdded
        )
    }

    /// Extracts version tags such as Live, Remix, Acoustic, Instrumental, Remaster.
    public static func extractVersion(from text: String) -> String? {
        let lower = text.lowercased()
        if lower.contains("live") { return "Live" }
        if lower.contains("remix") { return "Remix" }
        if lower.contains("acoustic") { return "Acoustic" }
        if lower.contains("instrumental") { return "Instrumental" }
        if lower.contains("remaster") { return "Remaster" }
        if lower.contains("radio edit") { return "Radio Edit" }
        return nil
    }

    /// Computes canonical deduplication key preserving recording versions.
    public var canonicalKey: String {
        if let isrc = isrc, !isrc.isEmpty {
            return "isrc:\(isrc.uppercased())"
        }
        let normTitle = title.lowercased()
            .replacingOccurrences(of: "(official video)", with: "")
            .replacingOccurrences(of: "[official video]", with: "")
            .replacingOccurrences(of: "(official audio)", with: "")
            .replacingOccurrences(of: "[official audio]", with: "")
            .replacingOccurrences(of: "(lyric video)", with: "")
            .replacingOccurrences(of: "[hd]", with: "")
            .replacingOccurrences(of: "[4k]", with: "")
            .trimmingCharacters(in: .punctuationCharacters)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let normArtist = artist.lowercased()
            .replacingOccurrences(of: "- topic", with: "")
            .trimmingCharacters(in: .punctuationCharacters)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let vTag = version ?? "standard"
        return "\(normTitle)|\(normArtist)|\(vTag)"
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

    public var formattedDuration: String {
        Song.formatDuration(duration)
    }
}

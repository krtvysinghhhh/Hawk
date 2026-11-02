import Foundation

/// Canonical track deduplication engine preserving distinct versions (Live, Remix, Acoustic)
/// while eliminating duplicate provider listings and choosing the highest-fidelity metadata.
public enum TrackDeduplicator {

    /// Deduplicates a collection of songs, merging duplicate provider records and prioritizing rich metadata.
    public static func deduplicate(_ songs: [Song]) -> [Song] {
        var canonicalMap: [String: Song] = [:]
        var orderedKeys: [String] = []

        for song in songs {
            let key = song.canonicalKey
            if let existing = canonicalMap[key] {
                // Merge into existing, choosing the superior metadata
                canonicalMap[key] = merge(primary: existing, candidate: song)
            } else {
                canonicalMap[key] = song
                orderedKeys.append(key)
            }
        }

        return orderedKeys.compactMap { canonicalMap[$0] }
    }

    /// Merges two representations of the same canonical track.
    public static func merge(primary: Song, candidate: Song) -> Song {
        // Prefer candidate artwork if primary has none
        let bestArtwork = primary.artworkURL ?? candidate.artworkURL

        // Prefer non-zero duration
        let bestDuration = primary.duration > 0 ? primary.duration : candidate.duration
        let bestDurationText = primary.duration > 0 ? primary.durationText : candidate.durationText

        // Combine provider identifiers
        var mergedProviders = primary.providerIdentifiers
        for (prov, pId) in candidate.providerIdentifiers {
            if mergedProviders[prov] == nil {
                mergedProviders[prov] = pId
            }
        }

        // Prefer candidate mediaUri if primary lacks it
        let bestMediaUri = (primary.mediaUri != nil && !primary.mediaUri!.isEmpty) ? primary.mediaUri : candidate.mediaUri
        let bestAlbum = primary.albumTitle ?? candidate.albumTitle
        let bestIsrc = primary.isrc ?? candidate.isrc

        return Song(
            id: primary.id,
            title: primary.title,
            artist: primary.artist,
            artists: primary.artists.isEmpty ? candidate.artists : primary.artists,
            albumTitle: bestAlbum,
            albumId: primary.albumId ?? candidate.albumId,
            duration: bestDuration,
            durationText: bestDurationText,
            artworkURL: bestArtwork,
            queueTier: primary.queueTier,
            queueEntryId: primary.queueEntryId,
            localFileURL: primary.localFileURL ?? candidate.localFileURL,
            sourceQuality: primary.sourceQuality ?? candidate.sourceQuality,
            isVideo: primary.isVideo,
            isLiked: primary.isLiked || candidate.isLiked,
            isrc: bestIsrc,
            mediaUri: bestMediaUri,
            sourceId: primary.sourceId ?? candidate.sourceId,
            version: primary.version ?? candidate.version,
            providerIdentifiers: mergedProviders,
            explicitStatus: primary.explicitStatus || candidate.explicitStatus
        )
    }
}

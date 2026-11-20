import Foundation
import HawkCore

/// Data structure representing a scored recommendation item with an explainable reason.
public struct RecommendedTrack: Identifiable, Sendable, Hashable {
    public var id: String { song.id }
    public let song: Song
    public let score: Double
    public let reason: String

    public init(song: Song, score: Double, reason: String) {
        self.song = song
        self.score = score
        self.reason = reason
    }
}

/// A structured shelf for home music discovery.
public struct RecommendationShelf: Identifiable, Sendable {
    public let id: String
    public let title: String
    public let subtitle: String
    public let tracks: [Song]

    public init(id: String, title: String, subtitle: String, tracks: [Song]) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.tracks = tracks
    }
}

/// Intelligent, on-device recommendation engine for personalized music discovery.
/// Calculates weighted listening affinity, recency decay, skip penalties, and explanation rationale.
public actor RecommendationEngine {
    public static let shared = RecommendationEngine()

    private let userDefaultsKey = "hawk_disliked_song_ids"
    private var dislikedSongIds: Set<String> = []
    private var skipPenalties: [String: Double] = [:]

    public init() {
        if let array = UserDefaults.standard.stringArray(forKey: userDefaultsKey) {
            self.dislikedSongIds = Set(array)
        }
    }

    /// Records explicit user negative feedback ("Dislike / Hide track").
    public func dislikeTrack(songId: String) {
        dislikedSongIds.insert(songId)
        UserDefaults.standard.set(Array(dislikedSongIds), forKey: userDefaultsKey)
    }

    /// Clears dislike feedback if user undoes action.
    public func undislikeTrack(songId: String) {
        dislikedSongIds.remove(songId)
        UserDefaults.standard.set(Array(dislikedSongIds), forKey: userDefaultsKey)
    }

    /// Penalizes songs that were skipped quickly (< 30s playback).
    public func recordSkip(songId: String, durationBeforeSkip: Double) {
        if durationBeforeSkip < 30.0 {
            skipPenalties[songId, default: 0.0] += 25.0
        }
    }

    /// Generates explainable, personalized discovery shelves based on listening history and library collections.
    ///
    /// - Parameters:
    ///   - history: Genuine recently played songs.
    ///   - favorites: User liked / favorited songs.
    ///   - librarySongs: All available songs in the user's library.
    ///   - monthlyBucket: Aggregated listening time and play count stats.
    /// - Returns: Ordered list of non-empty personalized shelves.
    public func generateShelves(
        history: [Song],
        favorites: [Song],
        librarySongs: [Song],
        monthlyBucket: MonthlyBucket?
    ) -> [RecommendationShelf] {
        var shelves: [RecommendationShelf] = []

        // Filter out disliked songs
        let activeHistory = history.filter { !dislikedSongIds.contains($0.id) }
        let activeFavorites = favorites.filter { !dislikedSongIds.contains($0.id) }
        let activeLibrary = librarySongs.filter { !dislikedSongIds.contains($0.id) }

        // Shelf 1: Jump Back In (Genuine wall-clock playback history)
        if !activeHistory.isEmpty {
            shelves.append(RecommendationShelf(
                id: "jump_back_in",
                title: "Jump Back In",
                subtitle: "Pick up right where you left off",
                tracks: Array(activeHistory.prefix(10))
            ))
        }

        // Shelf 2: Heavy Rotation (Most played tracks from monthly statistics)
        if let bucket = monthlyBucket {
            let topStatIds = bucket.topTracks.prefix(15).map(\.songId)
            let rotationTracks = activeLibrary.filter { topStatIds.contains($0.id) }
            if !rotationTracks.isEmpty {
                shelves.append(RecommendationShelf(
                    id: "heavy_rotation",
                    title: "Heavy Rotation",
                    subtitle: "Your most repeated tracks this month",
                    tracks: Array(rotationTracks.prefix(10))
                ))
            }
        }

        // Shelf 3: Made For You (Weighted hybrid mix)
        let scoredTracks = scoreCandidates(
            candidates: TrackDeduplicator.deduplicate(activeFavorites + activeHistory + activeLibrary),
            history: activeHistory,
            favorites: activeFavorites,
            monthlyBucket: monthlyBucket
        )

        let madeForYou = scoredTracks.map(\.song)
        if !madeForYou.isEmpty {
            shelves.append(RecommendationShelf(
                id: "made_for_you",
                title: "Made For You",
                subtitle: "Personalized mix based on your listening taste",
                tracks: Array(madeForYou.prefix(12))
            ))
        }

        // Shelf 4: Forgotten Favorites (Liked tracks not played recently)
        let recentIds = Set(activeHistory.prefix(15).map(\.id))
        let forgotten = activeFavorites.filter { !recentIds.contains($0.id) }
        if !forgotten.isEmpty {
            shelves.append(RecommendationShelf(
                id: "forgotten_favorites",
                title: "Rediscover Favorites",
                subtitle: "Loved tracks you haven't played in a while",
                tracks: Array(forgotten.shuffled().prefix(10))
            ))
        }

        // Shelf 5: Top Artist Spotlight (Focus on #1 most listened artist)
        if let topArtist = monthlyBucket?.topArtists.first?.name ?? activeHistory.first?.artist {
            let artistTracks = activeLibrary.filter {
                $0.artist.localizedCaseInsensitiveCompare(topArtist) == .orderedSame
            }
            if artistTracks.count >= 2 {
                shelves.append(RecommendationShelf(
                    id: "artist_spotlight_\(topArtist)",
                    title: "More from \(topArtist)",
                    subtitle: "Because you listen to this artist frequently",
                    tracks: Array(artistTracks.prefix(10))
                ))
            }
        }

        return shelves
    }

    /// Evaluates and ranks song candidates using multi-factor scoring.
    public func scoreCandidates(
        candidates: [Song],
        history: [Song],
        favorites: [Song],
        monthlyBucket: MonthlyBucket?
    ) -> [RecommendedTrack] {
        let favoriteIds = Set(favorites.map(\.id))
        let topArtistNames = Set(monthlyBucket?.topArtists.prefix(5).map { $0.name.lowercased() } ?? [])

        var scored: [RecommendedTrack] = []

        for song in candidates {
            if dislikedSongIds.contains(song.id) { continue }

            var score: Double = 0.0
            var reason = "Recommended for your taste"

            // 1. Favorites boost
            if favoriteIds.contains(song.id) {
                score += 50.0
                reason = "From your Liked Songs"
            }

            // 2. Play count & listen duration boost
            if let stat = monthlyBucket?.tracks[song.id] {
                score += Double(stat.playCount) * 10.0
                score += min(stat.totalSeconds / 60.0, 30.0) // up to 30 points for listening duration
                if stat.playCount >= 3 {
                    reason = "On heavy rotation"
                }
            }

            // 3. Artist affinity boost
            if topArtistNames.contains(song.artist.lowercased()) {
                score += 25.0
                reason = "Because you listen to \(song.artist)"
            }

            // 4. Recency boost from history
            if let historyIndex = history.firstIndex(where: { $0.id == song.id }) {
                let recencyPoints = max(20.0 - Double(historyIndex), 0.0)
                score += recencyPoints
            }

            // 5. Deduct skip penalties
            if let penalty = skipPenalties[song.id] {
                score -= penalty
            }

            scored.append(RecommendedTrack(song: song, score: score, reason: reason))
        }

        // Sort descending by score
        scored.sort { $0.score > $1.score }

        // Artist diversity filter: limit to at most 3 tracks per artist in candidate list
        var artistCounts: [String: Int] = [:]
        var diverseResults: [RecommendedTrack] = []

        for item in scored {
            let artistKey = item.song.artist.lowercased()
            let count = artistCounts[artistKey, default: 0]
            if count < 3 {
                artistCounts[artistKey] = count + 1
                diverseResults.append(item)
            }
        }

        return diverseResults
    }
}

import Foundation
import HawkCore
import HawkNetworking

public struct SpotifyTrackMeta: Sendable {
    public let title: String
    public let artist: String
    public let duration: TimeInterval

    public init(title: String, artist: String, duration: TimeInterval = 0) {
        self.title = title
        self.artist = artist
        self.duration = duration
    }
}

public struct SpotifyPlaylistMeta: Sendable {
    public let id: String
    public let title: String
    public let tracks: [SpotifyTrackMeta]

    public init(id: String, title: String, tracks: [SpotifyTrackMeta]) {
        self.id = id
        self.title = title
        self.tracks = tracks
    }
}

/// Utility for importing and matching Spotify playlists without DRM circumvention.
public enum SpotifyImporter {

    /// Extracts a 22-character Spotify playlist ID from URL or URI.
    public static func extractPlaylistId(from input: String) -> String? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmed.hasPrefix("spotify:playlist:") {
            let id = trimmed.replacingOccurrences(of: "spotify:playlist:", with: "")
            return id.isEmpty ? nil : id
        }

        guard let url = URL(string: trimmed),
              let host = url.host,
              host.contains("spotify.com") else { return nil }

        let components = url.pathComponents
        if let idx = components.firstIndex(of: "playlist"), idx + 1 < components.count {
            let id = components[idx + 1]
            return id.count == 22 ? id : nil
        }

        return nil
    }

    /// Fetches public Spotify playlist details and tracks from Spotify's open embed API.
    public static func fetchPlaylist(
        playlistId: String,
        client: HawkHttpClient = .shared
    ) async throws -> SpotifyPlaylistMeta {
        guard let url = URL(string: "https://open.spotify.com/embed/playlist/\(playlistId)") else {
            throw HawkError.networkError("Invalid Spotify playlist URL")
        }

        let (data, response) = try await client.request(url: url)
        guard (200...299).contains(response.statusCode),
              let html = String(data: data, encoding: .utf8) else {
            throw HawkError.invalidResponse(response.statusCode)
        }

        // Extract __NEXT_DATA__ JSON embedded in Spotify's public embed page
        guard let jsonRangeStart = html.range(of: "<script id=\"__NEXT_DATA__\" type=\"application/json\">"),
              let jsonRangeEnd = html[jsonRangeStart.upperBound...].range(of: "</script>") else {
            throw HawkError.decodeError("Spotify metadata script not found")
        }

        let jsonString = String(html[jsonRangeStart.upperBound..<jsonRangeEnd.lowerBound])
        guard let jsonData = jsonString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
              let props = json["props"] as? [String: Any],
              let pageProps = props["pageProps"] as? [String: Any],
              let state = pageProps["state"] as? [String: Any],
              let dataDict = state["data"] as? [String: Any],
              let entity = dataDict["entity"] as? [String: Any] else {
            throw HawkError.decodeError("Unable to navigate Spotify playlist JSON tree")
        }

        let title = entity["title"] as? String ?? "Imported Spotify Playlist"
        var tracks: [SpotifyTrackMeta] = []

        if let trackList = entity["trackList"] as? [[String: Any]] {
            for t in trackList {
                guard let tTitle = t["title"] as? String else { continue }
                let tArtist = t["subtitle"] as? String ?? "Unknown Artist"
                let durationMs = t["duration"] as? Double ?? 0
                tracks.append(SpotifyTrackMeta(title: tTitle, artist: tArtist, duration: durationMs / 1000.0))
            }
        }

        return SpotifyPlaylistMeta(id: playlistId, title: title, tracks: tracks)
    }

    /// Resolves Spotify tracks to HAWK Song objects using YouTube Music and TrackMatcher.
    public static func resolveToHawkSongs(
        spotifyTracks: [SpotifyTrackMeta],
        youtubeSource: YouTubeSource = YouTubeSource()
    ) async -> [Song] {
        var resolvedSongs: [Song] = []

        for meta in spotifyTracks {
            let query = "\(meta.title) \(meta.artist)"
            guard let candidates = try? await youtubeSource.search(query: query, filter: .songs),
                  !candidates.isEmpty else { continue }

            // Score each candidate with TrackMatcher
            var bestCandidate: Song?
            var highestScore: Double = 0.0

            for candidate in candidates {
                let score = TrackMatcher.matchScore(
                    titleA: meta.title,
                    artistA: meta.artist,
                    durationA: meta.duration,
                    titleB: candidate.title,
                    artistB: candidate.artist,
                    durationB: candidate.duration
                )
                if score > highestScore {
                    highestScore = score
                    bestCandidate = candidate
                }
            }

            if let best = bestCandidate, highestScore >= 0.5 {
                resolvedSongs.append(best)
            }
        }

        return resolvedSongs
    }
}

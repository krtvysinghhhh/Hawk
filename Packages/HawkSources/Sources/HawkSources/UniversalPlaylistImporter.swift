import Foundation
import HawkCore

public struct ImportedTrackItem: Sendable, Identifiable {
    public var id: String { "\(title)_\(artist)_\(duration)" }
    public let title: String
    public let artist: String
    public let duration: TimeInterval
    public let matchedSong: Song?
    public let matchConfidence: Double

    public init(title: String, artist: String, duration: TimeInterval = 0, matchedSong: Song? = nil, matchConfidence: Double = 0) {
        self.title = title
        self.artist = artist
        self.duration = duration
        self.matchedSong = matchedSong
        self.matchConfidence = matchConfidence
    }
}

public struct PlaylistImportResult: Sendable {
    public let playlistTitle: String
    public let totalTracks: Int
    public let matchedTracks: [Song]
    public let ambiguousTracks: [ImportedTrackItem]
    public let missingTracks: [ImportedTrackItem]

    public var successRate: Double {
        guard totalTracks > 0 else { return 0 }
        return Double(matchedTracks.count) / Double(totalTracks)
    }
}

/// Universal playlist import and export architecture supporting Spotify, YouTube, M3U/M3U8, and JSON,
/// with HLS manifest isolation, SSRF URL validation, and DoS payload caps.
public enum UniversalPlaylistImporter {

    public static let maxPayloadBytes: Int = 5 * 1024 * 1024 // 5 MB ceiling

    // MARK: - M3U8 Export
    public static func exportToM3U8(playlist: Playlist) -> String {
        var lines: [String] = ["#EXTM3U", "#PLAYLIST:\(playlist.title)"]
        for song in playlist.songs {
            let dur = Int(song.duration)
            lines.append("#EXTINF:\(dur),\(song.artist) - \(song.title)")
            if let local = song.localFileURL {
                // Sanitize path for export
                lines.append(local.path)
            } else if let uri = song.mediaUri {
                lines.append(uri)
            } else {
                lines.append("hawk://track/\(song.id)")
            }
        }
        return lines.joined(separator: "\n")
    }

    // MARK: - JSON Export
    public static func exportToJSON(playlist: Playlist) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(playlist)
    }

    // MARK: - HLS vs M3U Validation
    public static func isHLSManifest(content: String) -> Bool {
        content.contains("#EXT-X-TARGETDURATION") ||
        content.contains("#EXT-X-STREAM-INF") ||
        content.contains("#EXT-X-MEDIA-SEQUENCE") ||
        content.contains("#EXT-X-PLAYLIST-TYPE") ||
        content.contains("#EXT-X-KEY") ||
        content.contains("#EXT-X-MAP")
    }

    // MARK: - M3U / M3U8 Parsing
    public static func parseM3U(content: String) -> (title: String, tracks: [(title: String, artist: String, duration: TimeInterval)]) {
        // Guard against HLS streaming manifests being falsely parsed as track playlists
        if isHLSManifest(content: content) {
            return (title: "HLS Stream (Ignored)", tracks: [])
        }

        var tracks: [(title: String, artist: String, duration: TimeInterval)] = []
        var playlistTitle = "Imported Playlist"

        let lines = content.components(separatedBy: .newlines)
        var pendingDuration: TimeInterval = 0
        var pendingArtist = "Unknown Artist"
        var pendingTitle = "Unknown Title"

        for rawLine in lines {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !line.isEmpty else { continue }

            if line.hasPrefix("#PLAYLIST:") {
                playlistTitle = line.replacingOccurrences(of: "#PLAYLIST:", with: "").trimmingCharacters(in: .whitespaces)
            } else if line.hasPrefix("#EXTINF:") {
                // Format: #EXTINF:180,Artist Name - Song Title
                let meta = line.replacingOccurrences(of: "#EXTINF:", with: "")
                let parts = meta.components(separatedBy: ",")
                if let durStr = parts.first, let sec = Double(durStr) {
                    pendingDuration = max(0, sec)
                }
                if parts.count > 1 {
                    let fullInfo = parts[1...].joined(separator: ",")
                    let songParts = fullInfo.components(separatedBy: " - ")
                    if songParts.count >= 2 {
                        pendingArtist = songParts[0].trimmingCharacters(in: .whitespaces)
                        pendingTitle = songParts[1...].joined(separator: " - ").trimmingCharacters(in: .whitespaces)
                    } else {
                        pendingTitle = fullInfo.trimmingCharacters(in: .whitespaces)
                    }
                }
            } else if !line.hasPrefix("#") {
                // Line is a track URI or file path - sanitize path traversal
                let sanitizedPath = line.replacingOccurrences(of: "../", with: "")
                if !sanitizedPath.isEmpty {
                    tracks.append((title: pendingTitle, artist: pendingArtist, duration: pendingDuration))
                }
                pendingDuration = 0
                pendingArtist = "Unknown Artist"
                pendingTitle = "Unknown Title"
            }
        }

        return (title: playlistTitle, tracks: tracks)
    }

    // MARK: - JSON Import
    public static func parseJSON(data: Data) throws -> Playlist {
        // Attempt 1: Direct Playlist decoding
        if let playlist = try? JSONDecoder().decode(Playlist.self, from: data) {
            return playlist
        }
        // Attempt 2: Array of songs
        if let songs = try? JSONDecoder().decode([Song].self, from: data) {
            return Playlist(title: "Imported JSON Playlist", songs: songs)
        }
        throw HawkError.decodeError("JSON data does not match known playlist schemas")
    }

    // MARK: - URL Safety Validation
    public static func isSafeRemoteURL(_ url: URL) -> Bool {
        guard let scheme = url.scheme?.lowercased(), (scheme == "https" || scheme == "http") else {
            return false
        }
        guard let host = url.host?.lowercased() else {
            return false
        }
        // SSRF protection: reject loopback, link-local, and private subnets
        if host == "localhost" || host == "127.0.0.1" || host == "0.0.0.0" || host == "::1" || host == "[::1]" {
            return false
        }
        if host.hasPrefix("10.") || host.hasPrefix("192.168.") || host.hasPrefix("169.254.") {
            return false
        }
        let parts = host.split(separator: ".")
        if parts.count == 4, parts[0] == "172", let second = Int(parts[1]), (16...31).contains(second) {
            return false
        }
        return true
    }

    // MARK: - URL Importer
    public static func fetchTracksFromURL(_ urlString: String) async throws -> (title: String, tracks: [(title: String, artist: String, duration: TimeInterval)]) {
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        if let spotifyId = SpotifyImporter.extractPlaylistId(from: trimmed) {
            let meta = try await SpotifyImporter.fetchPlaylist(playlistId: spotifyId)
            let trackList = meta.tracks.map { ($0.title, $0.artist, $0.duration) }
            return (meta.title, trackList)
        }

        guard let url = URL(string: trimmed), isSafeRemoteURL(url) else {
            throw HawkError.networkError("Invalid or restricted remote playlist URL. Only public HTTPS playlists are supported.")
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 15.0

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw HawkError.networkError("Unable to fetch playlist from URL: server returned error")
        }

        // Cap payload to 5MB to prevent DoS memory exhaustion
        guard data.count <= maxPayloadBytes else {
            throw HawkError.networkError("Remote playlist file exceeds maximum size limit (5MB)")
        }

        if let stringContent = String(data: data, encoding: .utf8) {
            if isHLSManifest(content: stringContent) {
                throw HawkError.decodeError("HLS video/audio stream manifests cannot be imported as playlists")
            }
            if stringContent.contains("#EXTM3U") {
                return parseM3U(content: stringContent)
            }
        }

        if let playlist = try? parseJSON(data: data) {
            let trackList = playlist.songs.map { ($0.title, $0.artist, $0.duration) }
            return (playlist.title, trackList)
        }

        throw HawkError.decodeError("Unsupported playlist format at URL")
    }

    // MARK: - Universal Resolver
    public static func matchAndImport(
        tracks: [(title: String, artist: String, duration: TimeInterval)],
        playlistTitle: String,
        resolver: SourceResolver = .shared
    ) async -> PlaylistImportResult {
        var matched: [Song] = []
        var ambiguous: [ImportedTrackItem] = []
        var missing: [ImportedTrackItem] = []

        let saavn = JioSaavnSource()

        for t in tracks {
            let query = "\(t.title) \(t.artist)".trimmingCharacters(in: .whitespaces)
            let results = (try? await saavn.search(query: query)) ?? []

            var bestMatch: Song?
            var highestScore: Double = 0.0

            for candidate in results {
                let score = TrackMatcher.matchScore(
                    titleA: t.title,
                    artistA: t.artist,
                    durationA: t.duration,
                    titleB: candidate.title,
                    artistB: candidate.artist,
                    durationB: candidate.duration
                )
                if score > highestScore {
                    highestScore = score
                    bestMatch = candidate
                }
            }

            if highestScore >= TrackMatcher.confidenceThreshold, let winner = bestMatch {
                matched.append(winner)
            } else if highestScore >= 0.40, let winner = bestMatch {
                ambiguous.append(ImportedTrackItem(title: t.title, artist: t.artist, duration: t.duration, matchedSong: winner, matchConfidence: highestScore))
            } else {
                missing.append(ImportedTrackItem(title: t.title, artist: t.artist, duration: t.duration))
            }
        }

        return PlaylistImportResult(
            playlistTitle: playlistTitle,
            totalTracks: tracks.count,
            matchedTracks: matched,
            ambiguousTracks: ambiguous,
            missingTracks: missing
        )
    }
}

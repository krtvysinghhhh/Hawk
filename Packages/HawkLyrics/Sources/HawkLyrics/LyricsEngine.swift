import Foundation
import HawkCore
import HawkNetworking

/// Actor orchestrating lyrics resolution across open APIs (LRCLIB), TTML providers, and local caches.
public actor LyricsEngine {
    public static let shared = LyricsEngine()

    private let httpClient: HawkHttpClient
    private var cache: [String: [LyricLine]] = [:]
    private var customOffsets: [String: TimeInterval] = [:]

    public init(httpClient: HawkHttpClient = .shared) {
        self.httpClient = httpClient
    }

    /// Fetches synchronized or plain lyrics for a song, utilizing LRCLIB open-access API with fallback search.
    public func fetchLyrics(for song: Song) async throws -> [LyricLine] {
        let cacheKey = song.canonicalKey
        if let cached = cache[cacheKey] {
            return applyOffset(cached, offset: customOffsets[song.id] ?? 0)
        }

        // 1. Direct fetch with exact parameters
        let cleanedTitle = cleanTrackTitle(song.title)
        let cleanedArtist = cleanArtistName(song.artist)

        if let exactLyrics = await tryDirectFetch(title: cleanedTitle, artist: cleanedArtist, duration: song.duration) {
            cache[cacheKey] = exactLyrics
            return applyOffset(exactLyrics, offset: customOffsets[song.id] ?? 0)
        }

        // 2. Fallback search query
        let searchQuery = "\(cleanedTitle) \(cleanedArtist)".trimmingCharacters(in: .whitespaces)
        if let searchLyrics = await trySearchFetch(query: searchQuery, duration: song.duration) {
            cache[cacheKey] = searchLyrics
            return applyOffset(searchLyrics, offset: customOffsets[song.id] ?? 0)
        }

        throw HawkError.lyricsUnavailable(song.title)
    }

    private func tryDirectFetch(title: String, artist: String, duration: TimeInterval) async -> [LyricLine]? {
        guard let encodedTitle = title.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let encodedArtist = artist.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            return nil
        }

        var urlString = "https://lrclib.net/api/get?track_name=\(encodedTitle)&artist_name=\(encodedArtist)"
        if duration > 0 {
            urlString += "&duration=\(Int(duration))"
        }

        guard let url = URL(string: urlString) else { return nil }
        var headers = ["User-Agent": "HAWK-iOS/1.0 (https://github.com/krtvysinghhhh/HAWK)"]

        guard let (data, response) = try? await httpClient.request(url: url, headers: headers),
              (200...299).contains(response.statusCode),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }

        return parseLyricsJson(json)
    }

    private func trySearchFetch(query: String, duration: TimeInterval) async -> [LyricLine]? {
        guard let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://lrclib.net/api/search?q=\(encodedQuery)") else {
            return nil
        }

        let headers = ["User-Agent": "HAWK-iOS/1.0 (https://github.com/krtvysinghhhh/HAWK)"]
        guard let (data, response) = try? await httpClient.request(url: url, headers: headers),
              (200...299).contains(response.statusCode),
              let list = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            return nil
        }

        // Find best match with synced lyrics
        let syncedFirst = list.sorted { a, b in
            let aHas = (a["syncedLyrics"] as? String)?.isEmpty == false
            let bHas = (b["syncedLyrics"] as? String)?.isEmpty == false
            if aHas != bHas { return aHas }
            let aDur = abs((a["duration"] as? Double ?? 0) - duration)
            let bDur = abs((b["duration"] as? Double ?? 0) - duration)
            return aDur < bDur
        }

        if let best = syncedFirst.first {
            return parseLyricsJson(best)
        }

        return nil
    }

    private func parseLyricsJson(_ json: [String: Any]) -> [LyricLine]? {
        if let syncedLyrics = json["syncedLyrics"] as? String, !syncedLyrics.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let parsed = LrcParser.parse(syncedLyrics)
            if !parsed.isEmpty { return parsed }
        }

        if let plainLyrics = json["plainLyrics"] as? String, !plainLyrics.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let lines = plainLyrics.components(separatedBy: .newlines).compactMap { line -> LyricLine? in
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                guard !trimmed.isEmpty else { return nil }
                return LyricLine(timestamp: 0, text: trimmed)
            }
            if !lines.isEmpty { return lines }
        }

        return nil
    }

    private func cleanTrackTitle(_ title: String) -> String {
        title.replacingOccurrences(of: "(Official Video)", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "[Official Video]", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "(Official Audio)", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "[Official Audio]", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "(Lyric Video)", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "[HD]", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "[4K]", with: "", options: .caseInsensitive)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func cleanArtistName(_ artist: String) -> String {
        artist.replacingOccurrences(of: " - Topic", with: "", options: .caseInsensitive)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Sets user calibration offset in seconds for a specific track.
    public func setOffset(for songId: String, offset: TimeInterval) {
        customOffsets[songId] = offset
    }

    private func applyOffset(_ lines: [LyricLine], offset: TimeInterval) -> [LyricLine] {
        guard offset != 0 else { return lines }
        return lines.map {
            LyricLine(
                timestamp: max(0, $0.timestamp + offset),
                text: $0.text,
                words: $0.words.map { w in
                    LyricWord(
                        text: w.text,
                        startTime: max(0, w.startTime + offset),
                        endTime: max(0, w.endTime + offset)
                    )
                }
            )
        }
    }
}

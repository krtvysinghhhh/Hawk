import Foundation
import HawkCore
import HawkNetworking

/// Actor orchestrating lyrics resolution across open APIs (LRCLIB), local .lrc files, and persistent disk caches.
public actor LyricsEngine {
    public static let shared = LyricsEngine()

    private let httpClient: HawkHttpClient
    private var memoryCache: [String: [LyricLine]] = [:]
    private var negativeCache: [String: Date] = [:] // Negative cache with TTL
    private var customOffsets: [String: TimeInterval] = [:]
    private var defaultOffset: TimeInterval = 0
    private var rateLimitUntil: Date?

    private let userAgent = "HAWK/1.4.0 (https://github.com/krtvysinghhhh/Hawk)"
    private let negativeCacheTTL: TimeInterval = 600 // 10 minutes

    private var diskCacheDirectory: URL? {
        guard let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else {
            return nil
        }
        let dir = base.appendingPathComponent("Lyrics", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    public init(httpClient: HawkHttpClient = .shared) {
        self.httpClient = httpClient
    }

    /// Fetches synchronized or plain lyrics for a song, utilizing LRCLIB open-access API with fallback search.
    public func fetchLyrics(for song: Song) async throws -> [LyricLine] {
        let cacheKey = song.canonicalKey
        let effectiveOffset = (customOffsets[song.id] ?? 0) + defaultOffset

        // 1. In-memory cache hit
        if let cached = memoryCache[cacheKey] {
            return applyOffset(cached, offset: effectiveOffset)
        }

        // 2. Persistent disk cache hit
        if let diskCached = loadFromDisk(key: cacheKey) {
            memoryCache[cacheKey] = diskCached
            return applyOffset(diskCached, offset: effectiveOffset)
        }

        // 3. Local file check: If the track is a local audio file, check for adjacent .lrc
        if let localURL = song.localFileURL {
            let lrcURL = localURL.deletingPathExtension().appendingPathExtension("lrc")
            if FileManager.default.fileExists(atPath: lrcURL.path),
               let content = try? String(contentsOf: lrcURL, encoding: .utf8) {
                let parsed = LrcParser.parse(content)
                if !parsed.isEmpty {
                    saveToDisk(key: cacheKey, lines: parsed)
                    memoryCache[cacheKey] = parsed
                    return applyOffset(parsed, offset: effectiveOffset)
                }
            }
        }

        // 4. Check negative-result cache to prevent hammering for missing lyrics
        if let negativeTime = negativeCache[cacheKey], Date().timeIntervalSince(negativeTime) < negativeCacheTTL {
            throw HawkError.lyricsUnavailable(song.title)
        }

        // 5. Check active rate limit backoff (HTTP 429)
        if let backoff = rateLimitUntil, Date() < backoff {
            throw HawkError.lyricsUnavailable("\(song.title) (Rate limit backoff active)")
        }

        // 6. Direct fetch with exact parameters (title, artist, album, duration)
        let cleanedTitle = cleanTrackTitle(song.title)
        let cleanedArtist = cleanArtistName(song.artist)

        if let exactLyrics = await tryDirectFetch(title: cleanedTitle, artist: cleanedArtist, album: song.albumTitle, duration: song.duration) {
            saveToDisk(key: cacheKey, lines: exactLyrics)
            memoryCache[cacheKey] = exactLyrics
            negativeCache.removeValue(forKey: cacheKey)
            return applyOffset(exactLyrics, offset: effectiveOffset)
        }

        // 7. Fallback bounded search query
        let searchQuery = "\(cleanedTitle) \(cleanedArtist)".trimmingCharacters(in: .whitespaces)
        if let searchLyrics = await trySearchFetch(query: searchQuery, duration: song.duration) {
            saveToDisk(key: cacheKey, lines: searchLyrics)
            memoryCache[cacheKey] = searchLyrics
            negativeCache.removeValue(forKey: cacheKey)
            return applyOffset(searchLyrics, offset: effectiveOffset)
        }

        // Record negative cache hit so subsequent rapid accesses don't repeat network calls
        negativeCache[cacheKey] = Date()
        throw HawkError.lyricsUnavailable(song.title)
    }

    private func tryDirectFetch(title: String, artist: String, album: String?, duration: TimeInterval) async -> [LyricLine]? {
        guard let encodedTitle = title.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let encodedArtist = artist.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            return nil
        }

        var urlString = "https://lrclib.net/api/get?track_name=\(encodedTitle)&artist_name=\(encodedArtist)"
        if let alb = album, !alb.isEmpty, let encodedAlbum = alb.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
            urlString += "&album_name=\(encodedAlbum)"
        }
        if duration > 0 {
            urlString += "&duration=\(Int(duration))"
        }

        guard let url = URL(string: urlString) else { return nil }
        let headers = ["User-Agent": userAgent]

        guard let (data, response) = try? await httpClient.request(url: url, headers: headers) else {
            return nil
        }

        handleRateLimitHeaders(response)

        guard (200...299).contains(response.statusCode),
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

        let headers = ["User-Agent": userAgent]
        guard let (data, response) = try? await httpClient.request(url: url, headers: headers) else {
            return nil
        }

        handleRateLimitHeaders(response)

        guard (200...299).contains(response.statusCode),
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

    private func handleRateLimitHeaders(_ response: HTTPURLResponse) {
        if response.statusCode == 429 {
            if let retryHeader = response.allHeaderFields["Retry-After"] as? String,
               let seconds = Double(retryHeader) {
                rateLimitUntil = Date().addingTimeInterval(seconds)
            } else {
                rateLimitUntil = Date().addingTimeInterval(30) // Default 30s backoff
            }
        }
    }

    private func parseLyricsJson(_ json: [String: Any]) -> [LyricLine]? {
        // Instrumental detection
        if let isInstrumental = json["instrumental"] as? Bool, isInstrumental {
            return [LyricLine(timestamp: 0, text: "♪ Instrumental ♪")]
        }

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

    /// Sets the global default calibration offset in seconds from settings.
    public func setDefaultOffset(_ offset: TimeInterval) {
        self.defaultOffset = offset
    }

    private func applyOffset(_ lines: [LyricLine], offset: TimeInterval) -> [LyricLine] {
        guard offset != 0 else { return lines }
        return lines.map {
            LyricLine(
                id: $0.id,
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

    // MARK: - Disk Caching
    private func saveToDisk(key: String, lines: [LyricLine]) {
        guard let dir = diskCacheDirectory else { return }
        let safeName = key.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? key
        let fileURL = dir.appendingPathComponent("\(safeName).json")
        if let data = try? JSONEncoder().encode(lines) {
            try? data.write(to: fileURL, options: .atomic)
        }
    }

    private func loadFromDisk(key: String) -> [LyricLine]? {
        guard let dir = diskCacheDirectory else { return nil }
        let safeName = key.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? key
        let fileURL = dir.appendingPathComponent("\(safeName).json")
        guard let data = try? Data(contentsOf: fileURL),
              let lines = try? JSONDecoder().decode([LyricLine].self, from: data) else {
            return nil
        }
        return lines
    }

    public func clearDiskCache() {
        guard let dir = diskCacheDirectory else { return }
        try? FileManager.default.removeItem(at: dir)
        memoryCache.removeAll()
        negativeCache.removeAll()
    }
}

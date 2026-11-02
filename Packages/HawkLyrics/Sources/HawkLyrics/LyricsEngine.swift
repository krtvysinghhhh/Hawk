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

    /// Fetches synchronized lyrics for a song, utilizing LRCLIB open-access API.
    public func fetchLyrics(for song: Song) async throws -> [LyricLine] {
        if let cached = cache[song.id] {
            return applyOffset(cached, offset: customOffsets[song.id] ?? 0)
        }

        guard let trackName = song.title.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let artistName = song.artist.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            return []
        }

        var urlString = "https://lrclib.net/api/get?track_name=\(trackName)&artist_name=\(artistName)"
        if song.duration > 0 {
            urlString += "&duration=\(Int(song.duration))"
        }

        guard let url = URL(string: urlString) else { return [] }

        do {
            let (data, response) = try await httpClient.request(url: url)
            guard (200...299).contains(response.statusCode) else { return [] }

            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                if let syncedLyrics = json["syncedLyrics"] as? String, !syncedLyrics.isEmpty {
                    let parsed = LrcParser.parse(syncedLyrics)
                    cache[song.id] = parsed
                    return applyOffset(parsed, offset: customOffsets[song.id] ?? 0)
                } else if let plainLyrics = json["plainLyrics"] as? String {
                    // Fallback to unsynced lines
                    let plainLines = plainLyrics.components(separatedBy: .newlines).map {
                        LyricLine(timestamp: 0, text: $0)
                    }
                    cache[song.id] = plainLines
                    return plainLines
                }
            }
        } catch {
            print("LyricsEngine fetch error: \(error)")
        }

        return []
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

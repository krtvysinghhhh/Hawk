import Foundation
import HawkCore
import HawkSecurity
import HawkNetworking

/// Native YouTube Music provider querying YouTubei's public and authenticated endpoints.
public final class YouTubeSource: MusicSourceProvider, @unchecked Sendable {
    public let sourceId = "youtube"
    public let displayName = "YouTube Music"
    public let capabilities: Set<SourceCapability> = [
        .search, .streamResolution, .albumDetail, .artistDetail
    ]

    private let httpClient: HawkHttpClient
    private let keychain: KeychainStore

    public init(httpClient: HawkHttpClient = .shared, keychain: KeychainStore = .shared) {
        self.httpClient = httpClient
        self.keychain = keychain
    }

    // MARK: - Search
    public func search(query: String, filter: SearchFilter = .all) async throws -> [Song] {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else { return [] }

        guard let url = URL(string: "https://music.youtube.com/youtubei/v1/search") else {
            throw HawkError.networkError("Invalid YouTube Music URL")
        }

        let headers = standardHeaders()

        let body: [String: Any] = [
            "context": [
                "client": [
                    "clientName": "WEB_REMIX",
                    "clientVersion": "1.20250101.01.00",
                    "hl": "en",
                    "gl": "US"
                ]
            ],
            "query": query
        ]

        guard let bodyData = try? JSONSerialization.data(withJSONObject: body) else {
            throw HawkError.decodeError("Failed to serialize search payload")
        }

        let (data, response) = try await httpClient.request(
            url: url,
            method: "POST",
            headers: headers,
            body: bodyData
        )

        guard (200...299).contains(response.statusCode) else {
            throw HawkError.invalidResponse(response.statusCode)
        }

        return parseSearchResults(from: data)
    }

    // MARK: - Stream Resolution
    public func resolveStream(song: Song, qualityCeiling: AudioQuality = .high) async throws -> SourceStream {
        guard let url = URL(string: "https://www.youtube.com/youtubei/v1/player") else {
            throw HawkError.networkError("Invalid YouTube Player URL")
        }

        let body: [String: Any] = [
            "context": [
                "client": [
                    "clientName": "IOS",
                    "clientVersion": "19.29.1",
                    "deviceModel": "iPhone13,2",
                    "hl": "en",
                    "gl": "US"
                ]
            ],
            "videoId": song.id,
            "playbackContext": [
                "contentPlaybackContext": [
                    "html5Preference": "HTML5_PREF_WANTS"
                ]
            ]
        ]

        guard let bodyData = try? JSONSerialization.data(withJSONObject: body) else {
            throw HawkError.decodeError("Failed to encode player request")
        }

        let headers = [
            "Content-Type": "application/json",
            "User-Agent": "com.google.ios.youtube/19.29.1 (iPhone13,2; U; CPU iOS 17_0 like Mac OS X; en_US)",
            "x-youtube-client-name": "5",
            "x-youtube-client-version": "19.29.1"
        ]

        let (data, response) = try await httpClient.request(
            url: url,
            method: "POST",
            headers: headers,
            body: bodyData
        )

        guard (200...299).contains(response.statusCode) else {
            throw HawkError.invalidResponse(response.statusCode)
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let streamingData = json["streamingData"] as? [String: Any],
              let adaptiveFormats = streamingData["adaptiveFormats"] as? [[String: Any]] else {
            throw HawkError.streamNotFound(song.id)
        }

        // Filter and pick highest bitrate audio format conforming to quality ceiling
        let audioFormats = adaptiveFormats.filter { format in
            guard let mimeType = format["mimeType"] as? String else { return false }
            return mimeType.hasPrefix("audio/")
        }

        let sorted = audioFormats.sorted { f1, f2 in
            let b1 = f1["bitrate"] as? Int ?? 0
            let b2 = f2["bitrate"] as? Int ?? 0
            return b1 > b2
        }

        for format in sorted {
            guard let urlString = format["url"] as? String,
                  let streamURL = URL(string: urlString) else { continue }
            let bitrate = (format["bitrate"] as? Int ?? 128000) / 1000
            let mimeType = format["mimeType"] as? String ?? "audio/mp4"

            if bitrate <= qualityCeiling.maxKbps {
                return SourceStream(
                    url: streamURL,
                    quality: bitrate >= 256 ? .high : .standard,
                    mimeType: mimeType,
                    sourceId: sourceId
                )
            }
        }

        // Fallback to first available format
        if let first = sorted.first,
           let urlString = first["url"] as? String,
           let streamURL = URL(string: urlString) {
            return SourceStream(
                url: streamURL,
                quality: .standard,
                mimeType: first["mimeType"] as? String ?? "audio/mp4",
                sourceId: sourceId
            )
        }

        throw HawkError.streamNotFound(song.id)
    }

    // MARK: - Private Helpers
    private func standardHeaders() -> [String: String] {
        [
            "Content-Type": "application/json",
            "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36",
            "x-youtube-client-name": "67",
            "x-youtube-client-version": "1.20250101.01.00",
            "x-origin": "https://music.youtube.com"
        ]
    }

    private func parseSearchResults(from data: Data) -> [Song] {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return []
        }

        var results: [Song] = []

        // Navigate YouTube Music sectionListRenderer / musicShelfRenderer JSON tree
        func traverse(obj: Any) {
            if let dict = obj as? [String: Any] {
                if let renderer = dict["musicResponsiveListItemRenderer"] as? [String: Any] {
                    if let song = extractSong(from: renderer) {
                        results.append(song)
                    }
                } else {
                    for (_, val) in dict {
                        traverse(obj: val)
                    }
                }
            } else if let arr = obj as? [Any] {
                for item in arr {
                    traverse(obj: item)
                }
            }
        }

        traverse(obj: json)
        return results
    }

    private func extractSong(from renderer: [String: Any]) -> Song? {
        // Extract video ID from flexColumns
        guard let playlistItemData = renderer["playlistItemData"] as? [String: Any],
              let videoId = playlistItemData["videoId"] as? String else {
            return nil
        }

        guard let flexColumns = renderer["flexColumns"] as? [[String: Any]],
              !flexColumns.isEmpty else { return nil }

        // Column 0: Title
        var title = "Unknown Title"
        if let col0 = flexColumns.first,
           let textRenderer0 = col0["musicResponsiveListItemFlexColumnRenderer"] as? [String: Any],
           let text = textRenderer0["text"] as? [String: Any],
           let runs = text["runs"] as? [[String: Any]],
           let firstRun = runs.first,
           let titleText = firstRun["text"] as? String {
            title = titleText
        }

        // Column 1: Artist & Duration
        var artist = "Unknown Artist"
        var duration: TimeInterval = 0
        if flexColumns.count > 1 {
            let col1 = flexColumns[1]
            if let textRenderer1 = col1["musicResponsiveListItemFlexColumnRenderer"] as? [String: Any],
               let text = textRenderer1["text"] as? [String: Any],
               let runs = text["runs"] as? [[String: Any]] {
                if let artistRun = runs.first, let artistText = artistRun["text"] as? String {
                    artist = artistText
                }
                if let lastRun = runs.last, let durStr = lastRun["text"] as? String {
                    duration = parseDuration(durStr)
                }
            }
        }

        // Artwork
        var artworkURL: URL?
        if let thumbnail = renderer["thumbnail"] as? [String: Any],
           let musicThumbnailRenderer = thumbnail["musicThumbnailRenderer"] as? [String: Any],
           let thumb = musicThumbnailRenderer["thumbnail"] as? [String: Any],
           let thumbs = thumb["thumbnails"] as? [[String: Any]],
           let best = thumbs.last,
           let urlString = best["url"] as? String {
            artworkURL = URL(string: urlString)
        }

        return Song(
            id: videoId,
            title: title,
            artist: artist,
            duration: duration,
            artworkURL: artworkURL,
            sourceId: sourceId,
            providerIdentifiers: [sourceId: videoId]
        )
    }

    private func parseDuration(_ text: String) -> TimeInterval {
        let parts = text.components(separatedBy: ":").compactMap { Double($0) }
        if parts.count == 2 {
            return parts[0] * 60 + parts[1]
        } else if parts.count == 3 {
            return parts[0] * 3600 + parts[1] * 60 + parts[2]
        }
        return 0
    }
}

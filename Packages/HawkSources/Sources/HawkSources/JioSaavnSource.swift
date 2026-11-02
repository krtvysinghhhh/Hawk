import Foundation
import HawkCore
import HawkSecurity
import HawkNetworking

/// Native JioSaavn provider delivering high-bitrate (320 kbps) AAC streams.
public final class JioSaavnSource: MusicSourceProvider, @unchecked Sendable {
    public let sourceId = "jiosaavn"
    public let displayName = "JioSaavn Lossless/High"
    public let capabilities: Set<SourceCapability> = [
        .search, .streamResolution, .highResolutionAudio
    ]

    private let httpClient: HawkHttpClient

    public init(httpClient: HawkHttpClient = .shared) {
        self.httpClient = httpClient
    }

    // MARK: - Search
    public func search(query: String, filter: SearchFilter = .all) async throws -> [Song] {
        guard let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://www.jiosaavn.com/api.php?__call=search.getResults&_format=json&_marker=0&api_version=4&ctx=android&n=20&p=1&q=\(encodedQuery)") else {
            return []
        }

        let (data, response) = try await httpClient.request(url: url)
        guard (200...299).contains(response.statusCode) else {
            throw HawkError.invalidResponse(response.statusCode)
        }

        return parseSearchResults(from: data)
    }

    // MARK: - Stream Resolution
    public func resolveStream(song: Song, qualityCeiling: AudioQuality = .high) async throws -> SourceStream {
        // If the song already has an encrypted media url stored in localUri or needs direct query:
        guard let encodedId = song.id.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://www.jiosaavn.com/api.php?__call=song.getDetails&cc=in&_marker=0%3F_marker%3D0&_format=json&pids=\(encodedId)") else {
            throw HawkError.streamNotFound(song.id)
        }

        let (data, response) = try await httpClient.request(url: url)
        guard (200...299).contains(response.statusCode) else {
            throw HawkError.invalidResponse(response.statusCode)
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let songDict = json[song.id] as? [String: Any],
              let moreInfo = songDict["more_info"] as? [String: Any],
              let encryptedMediaUrl = moreInfo["encrypted_media_url"] as? String else {
            throw HawkError.streamNotFound(song.id)
        }

        // Decrypt the DES media URL
        let decryptedBase = try CryptoUtils.decryptJioSaavnUrl(encryptedUrl: encryptedMediaUrl)

        // Select the 320kbps rendition if supported
        let has320 = (moreInfo["320kbps"] as? String) == "true"
        let streamUrlString: String

        if has320 && qualityCeiling.maxKbps >= 320 {
            streamUrlString = decryptedBase.replacingOccurrences(of: "_96.mp4", with: "_320.mp4")
                .replacingOccurrences(of: "_160.mp4", with: "_320.mp4")
        } else {
            streamUrlString = decryptedBase
        }

        guard let finalURL = URL(string: streamUrlString) else {
            throw HawkError.streamNotFound(song.id)
        }

        return SourceStream(
            url: finalURL,
            quality: (has320 && qualityCeiling.maxKbps >= 320) ? .high : .standard,
            mimeType: "audio/mp4",
            sourceId: sourceId
        )
    }

    private func parseSearchResults(from data: Data) -> [Song] {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let results = json["results"] as? [[String: Any]] else {
            return []
        }

        return results.compactMap { dict -> Song? in
            guard let id = dict["id"] as? String,
                  let title = (dict["title"] as? String)?
                    .replacingOccurrences(of: "&quot;", with: "\"")
                    .replacingOccurrences(of: "&amp;", with: "&"),
                  let moreInfo = dict["more_info"] as? [String: Any] else {
                return nil
            }

            let artist = (dict["subtitle"] as? String) ?? (moreInfo["singers"] as? String) ?? "Unknown Artist"
            let durationStr = moreInfo["duration"] as? String ?? "0"
            let duration = Double(durationStr) ?? 0

            var artworkURL: URL?
            if let imageStr = dict["image"] as? String {
                let highRes = imageStr.replacingOccurrences(of: "150x150", with: "500x500")
                artworkURL = URL(string: highRes)
            }

            return Song(
                id: id,
                title: title,
                artist: artist,
                duration: duration,
                artworkURL: artworkURL,
                sourceQuality: .high
            )
        }
    }
}

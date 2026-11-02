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
        // Fast path: if song already has its encrypted media URL stored:
        if let encMediaUrl = song.mediaUri, !encMediaUrl.isEmpty {
            if let stream = tryDecryptMediaUrl(encMediaUrl, qualityCeiling: qualityCeiling) {
                return stream
            }
        }

        // Search lookup fallback by title + artist
        let query = "\(song.title) \(song.artist)".trimmingCharacters(in: .whitespaces)
        if let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
           let searchUrl = URL(string: "https://www.jiosaavn.com/api.php?__call=search.getResults&_format=json&_marker=0&api_version=4&ctx=android&n=5&p=1&q=\(encodedQuery)") {
            if let (data, response) = try? await httpClient.request(url: searchUrl),
               (200...299).contains(response.statusCode),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let results = json["results"] as? [[String: Any]],
               let first = results.first,
               let moreInfo = first["more_info"] as? [String: Any],
               let encUrl = moreInfo["encrypted_media_url"] as? String {
                let has320 = (moreInfo["320kbps"] as? String) == "true"
                if let stream = tryDecryptMediaUrl(encUrl, has320: has320, qualityCeiling: qualityCeiling) {
                    return stream
                }
            }
        }

        throw HawkError.streamNotFound(song.id)
    }

    private func tryDecryptMediaUrl(_ encMediaUrl: String, has320: Bool = true, qualityCeiling: AudioQuality = .high) -> SourceStream? {
        do {
            let decryptedBase = try CryptoUtils.decryptJioSaavnUrl(encryptedUrl: encMediaUrl, desKey: "38346591")
            let streamUrlString: String
            if has320 && qualityCeiling.maxKbps >= 320 {
                streamUrlString = decryptedBase
                    .replacingOccurrences(of: "_96.mp4", with: "_320.mp4")
                    .replacingOccurrences(of: "_160.mp4", with: "_320.mp4")
            } else {
                streamUrlString = decryptedBase
            }
            guard let finalURL = URL(string: streamUrlString) else { return nil }
            return SourceStream(
                url: finalURL,
                quality: (has320 && qualityCeiling.maxKbps >= 320) ? .high : .standard,
                mimeType: "audio/mp4",
                sourceId: sourceId
            )
        } catch {
            return nil
        }
    }

    private func parseSearchResults(from data: Data) -> [Song] {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let results = json["results"] as? [[String: Any]] else {
            return []
        }

        return results.compactMap { dict -> Song? in
            guard let id = dict["id"] as? String,
                  let titleRaw = (dict["title"] as? String)?
                    .replacingOccurrences(of: "&quot;", with: "\"")
                    .replacingOccurrences(of: "&amp;", with: "&")
                    .replacingOccurrences(of: "&#039;", with: "'"),
                  let moreInfo = dict["more_info"] as? [String: Any] else {
                return nil
            }

            let title = titleRaw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !title.isEmpty else { return nil }

            let artist = extractArtist(from: dict, moreInfo: moreInfo)
            let durationStr = moreInfo["duration"] as? String ?? "0"
            let duration = Double(durationStr) ?? 0

            var artworkURL: URL?
            if let imageStr = dict["image"] as? String {
                let highRes = imageStr.replacingOccurrences(of: "150x150", with: "500x500")
                artworkURL = URL(string: highRes)
            }

            let encMediaUrl = moreInfo["encrypted_media_url"] as? String
            let album = (moreInfo["album"] as? String)?
                .replacingOccurrences(of: "&quot;", with: "\"")
                .replacingOccurrences(of: "&amp;", with: "&")
                .replacingOccurrences(of: "&#039;", with: "'")
            let isExplicit = (dict["explicit_content"] as? String) == "1"

            return Song(
                id: id,
                title: title,
                artist: artist,
                albumTitle: album,
                duration: duration,
                artworkURL: artworkURL,
                sourceQuality: .high,
                mediaUri: encMediaUrl,
                sourceId: sourceId,
                providerIdentifiers: [sourceId: id],
                explicitStatus: isExplicit
            )
        }
    }

    private func extractArtist(from dict: [String: Any], moreInfo: [String: Any]) -> String {
        if let artistMap = moreInfo["artistMap"] as? [String: Any] {
            if let primaryList = artistMap["primary_artists"] as? [[String: Any]], !primaryList.isEmpty {
                let names = primaryList.compactMap { $0["name"] as? String }
                    .map { $0.replacingOccurrences(of: "&quot;", with: "\"").replacingOccurrences(of: "&amp;", with: "&") }
                    .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
                if !names.isEmpty {
                    return names.joined(separator: ", ")
                }
            }
            if let artistsList = artistMap["artists"] as? [[String: Any]] {
                let singers = artistsList.filter { ($0["role"] as? String) == "singer" || ($0["role"] as? String) == "music" }
                let names = singers.compactMap { $0["name"] as? String }
                    .map { $0.replacingOccurrences(of: "&quot;", with: "\"").replacingOccurrences(of: "&amp;", with: "&") }
                    .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
                if !names.isEmpty {
                    return names.joined(separator: ", ")
                }
            }
        }
        if let primary = (moreInfo["primary_artists"] as? String)?.trimmingCharacters(in: .whitespaces), !primary.isEmpty {
            return primary
        }
        if let singers = (moreInfo["singers"] as? String)?.trimmingCharacters(in: .whitespaces), !singers.isEmpty {
            return singers
        }
        if let music = (moreInfo["music"] as? String)?.trimmingCharacters(in: .whitespaces), !music.isEmpty {
            return music
        }
        if let subtitle = (dict["subtitle"] as? String)?.trimmingCharacters(in: .whitespaces), !subtitle.isEmpty {
            return subtitle
        }
        if let desc = (dict["header_desc"] as? String)?.trimmingCharacters(in: .whitespaces), !desc.isEmpty {
            return desc
        }
        return "Unknown Artist"
    }
}

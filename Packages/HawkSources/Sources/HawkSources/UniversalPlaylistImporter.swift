import Foundation
import HawkCore
import Darwin

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

/// URLSession delegate enforcing redirect destination validation, redirect loop detection,
/// and maximum redirect depth limits.
final class SafeRedirectSessionDelegate: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    private var redirectCount: Int = 0
    private var visitedURLs: Set<String> = []
    private let maxRedirects: Int = 5

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping (URLRequest?) -> Void
    ) {
        redirectCount += 1
        if redirectCount > maxRedirects {
            // Excessive redirects - abort
            completionHandler(nil)
            return
        }

        guard let newURL = request.url else {
            completionHandler(nil)
            return
        }

        let canonical = newURL.absoluteString
        if visitedURLs.contains(canonical) {
            // Cyclic redirect loop detected - abort
            completionHandler(nil)
            return
        }
        visitedURLs.insert(canonical)

        // Strict revalidation of redirect target URL and its resolved IP address
        if !UniversalPlaylistImporter.isSafeRemoteURL(newURL) {
            // Public-to-private redirect blocked!
            completionHandler(nil)
            return
        }

        completionHandler(request)
    }
}

/// Universal playlist import and export architecture supporting Spotify, YouTube, M3U/M3U8, and JSON,
/// with HLS manifest isolation, advanced SSRF/DNS-rebinding protection, and DoS payload caps.
public enum UniversalPlaylistImporter {

    public static let maxPayloadBytes: Int = 5 * 1024 * 1024 // 5 MB ceiling
    public static let maxTimeoutInterval: TimeInterval = 15.0 // 15 seconds

    // MARK: - M3U8 Export
    public static func exportToM3U8(playlist: Playlist) -> String {
        var lines: [String] = ["#EXTM3U", "#PLAYLIST:\(playlist.title)"]
        for song in playlist.songs {
            let dur = Int(song.duration)
            lines.append("#EXTINF:\(dur),\(song.artist) - \(song.title)")
            if let local = song.localFileURL {
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
        if let playlist = try? JSONDecoder().decode(Playlist.self, from: data) {
            return playlist
        }
        if let songs = try? JSONDecoder().decode([Song].self, from: data) {
            return Playlist(title: "Imported JSON Playlist", songs: songs)
        }
        throw HawkError.decodeError("JSON data does not match known playlist schemas")
    }

    // MARK: - Advanced SSRF & DNS Rebinding Protection
    public static func isPrivateOrReservedIPv4(_ addr: in_addr) -> Bool {
        let ip = CFSwapInt32BigToHost(addr.s_addr)
        // 0.0.0.0/8 (Current network)
        if (ip & 0xFF000000) == 0x00000000 { return true }
        // 10.0.0.0/8 (Private RFC 1918)
        if (ip & 0xFF000000) == 0x0A000000 { return true }
        // 100.64.0.0/10 (Carrier-grade NAT RFC 6598)
        if (ip & 0xFFC00000) == 0x64400000 { return true }
        // 127.0.0.0/8 (Loopback RFC 1122)
        if (ip & 0xFF000000) == 0x7F000000 { return true }
        // 169.254.0.0/16 (Link-local RFC 3927)
        if (ip & 0xFFFF0000) == 0xA9FE0000 { return true }
        // 172.16.0.0/12 (Private RFC 1918)
        if (ip & 0xFFF00000) == 0xAC100000 { return true }
        // 192.0.0.0/24 (IETF Protocol Assignments)
        if (ip & 0xFFFFFF00) == 0xC0000000 { return true }
        // 192.0.2.0/24 (TEST-NET-1)
        if (ip & 0xFFFFFF00) == 0xC0000200 { return true }
        // 192.88.99.0/24 (6to4 Relay)
        if (ip & 0xFFFFFF00) == 0xC0586300 { return true }
        // 192.168.0.0/16 (Private RFC 1918)
        if (ip & 0xFFFF0000) == 0xC0A80000 { return true }
        // 198.18.0.0/15 (Benchmarking)
        if (ip & 0xFFFE0000) == 0xC6120000 { return true }
        // 198.51.100.0/24 (TEST-NET-2)
        if (ip & 0xFFFFFF00) == 0xC6336400 { return true }
        // 203.0.113.0/24 (TEST-NET-3)
        if (ip & 0xFFFFFF00) == 0xCB007100 { return true }
        // 224.0.0.0/4 (Multicast RFC 5771)
        if (ip & 0xF0000000) == 0xE0000000 { return true }
        // 240.0.0.0/4 (Reserved RFC 1112)
        if (ip & 0xF0000000) == 0xF0000000 { return true }
        // 255.255.255.255/32 (Broadcast)
        if ip == 0xFFFFFFFF { return true }
        return false
    }

    public static func isPrivateOrReservedIPv6(_ addr: in6_addr) -> Bool {
        var bytes = [UInt8](repeating: 0, count: 16)
        var temp = addr
        memcpy(&bytes, &temp, 16)

        // Loopback ::1
        var isLoopback = true
        for i in 0..<15 { if bytes[i] != 0 { isLoopback = false; break } }
        if isLoopback && bytes[15] == 1 { return true }

        // Unspecified ::
        var isUnspecified = true
        for i in 0..<16 { if bytes[i] != 0 { isUnspecified = false; break } }
        if isUnspecified { return true }

        // IPv4-mapped IPv6 (::ffff:0:0/96)
        var isIPv4Mapped = true
        for i in 0..<10 { if bytes[i] != 0 { isIPv4Mapped = false; break } }
        if bytes[10] != 0xFF || bytes[11] != 0xFF { isIPv4Mapped = false }
        if isIPv4Mapped {
            var v4addr = in_addr()
            memcpy(&v4addr, &bytes[12], 4)
            return isPrivateOrReservedIPv4(v4addr)
        }

        // Unique Local Address (fc00::/7)
        if (bytes[0] & 0xFE) == 0xFC { return true }

        // Link-Local Unicast (fe80::/10)
        if bytes[0] == 0xFE && (bytes[1] & 0xC0) == 0x80 { return true }

        // Site-Local (fec0::/10)
        if bytes[0] == 0xFE && (bytes[1] & 0xC0) == 0xC0 { return true }

        // Multicast (ff00::/8)
        if bytes[0] == 0xFF { return true }

        // Documentation (2001:db8::/32)
        if bytes[0] == 0x20 && bytes[1] == 0x01 && bytes[2] == 0x0D && bytes[3] == 0xB8 { return true }

        return false
    }

    /// Resolves hostname via DNS and verifies that NO resolved address belongs to private or reserved IP ranges.
    public static func validateHostNotPrivate(_ host: String) -> Bool {
        let cleanHost = host.trimmingCharacters(in: CharacterSet(charactersIn: "[]"))
        var hints = addrinfo(
            ai_flags: AI_DEFAULT,
            ai_family: AF_UNSPEC,
            ai_socktype: SOCK_STREAM,
            ai_protocol: IPPROTO_TCP,
            ai_addrlen: 0,
            ai_canonname: nil,
            ai_addr: nil,
            ai_next: nil
        )

        var res: UnsafeMutablePointer<addrinfo>?
        let status = getaddrinfo(cleanHost, nil, &hints, &res)
        guard status == 0, let resHead = res else {
            return false // Invalid or unresolvable hostname
        }
        defer { freeaddrinfo(resHead) }

        var ptr: UnsafeMutablePointer<addrinfo>? = resHead
        while let current = ptr {
            let family = current.pointee.ai_family
            if family == AF_INET {
                let sockAddrIn = current.pointee.ai_addr.withMemoryRebound(to: sockaddr_in.self, capacity: 1) { $0.pointee }
                if isPrivateOrReservedIPv4(sockAddrIn.sin_addr) {
                    return false
                }
            } else if family == AF_INET6 {
                let sockAddrIn6 = current.pointee.ai_addr.withMemoryRebound(to: sockaddr_in6.self, capacity: 1) { $0.pointee }
                if isPrivateOrReservedIPv6(sockAddrIn6.sin6_addr) {
                    return false
                }
            }
            ptr = current.pointee.ai_next
        }

        return true
    }

    /// Validates URL against SSRF, credential stuffing, invalid encodings, and private destination networks.
    public static func isSafeRemoteURL(_ url: URL) -> Bool {
        guard let scheme = url.scheme?.lowercased(), (scheme == "https" || scheme == "http") else {
            return false
        }
        // Reject user-info embedded credentials (e.g. http://user:pass@host/)
        guard url.user == nil && url.password == nil else {
            return false
        }
        guard let host = url.host?.lowercased(), !host.isEmpty else {
            return false
        }

        // Reject percent-encoded host representations (e.g. %31%32%37.0.0.1)
        if host.contains("%") {
            return false
        }

        // Reject octal notation (e.g. 0177.0.0.1) or hex IP notation (0x7f000001)
        let parts = host.split(separator: ".")
        if parts.count == 4 {
            for p in parts {
                if p.hasPrefix("0x") || (p.count > 1 && p.hasPrefix("0")) {
                    return false
                }
            }
        }

        // Common literal shortcuts: localhost, local domains, link-local metadata
        if host == "localhost" || host.hasSuffix(".localhost") || host.hasSuffix(".local") {
            return false
        }

        // DNS resolution check: validates all returned IPv4 and IPv6 addresses against private/reserved ranges
        return validateHostNotPrivate(host)
    }

    // MARK: - Safe URL Importer
    public static func fetchTracksFromURL(_ urlString: String) async throws -> (title: String, tracks: [(title: String, artist: String, duration: TimeInterval)]) {
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        if let spotifyId = SpotifyImporter.extractPlaylistId(from: trimmed) {
            let meta = try await SpotifyImporter.fetchPlaylist(playlistId: spotifyId)
            let trackList = meta.tracks.map { ($0.title, $0.artist, $0.duration) }
            return (meta.title, trackList)
        }

        guard let url = URL(string: trimmed), isSafeRemoteURL(url) else {
            throw HawkError.networkError("Invalid or restricted remote playlist URL. Only public HTTP/HTTPS playlists are supported.")
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = maxTimeoutInterval

        // Use custom URLSession with SafeRedirectSessionDelegate to validate redirects and prevent loops
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = maxTimeoutInterval
        config.timeoutIntervalForResource = maxTimeoutInterval
        let delegate = SafeRedirectSessionDelegate()
        let session = URLSession(configuration: config, delegate: delegate, delegateQueue: nil)

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw HawkError.networkError("Unable to fetch playlist from URL: server returned HTTP \((response as? HTTPURLResponse)?.statusCode ?? 0)")
        }

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

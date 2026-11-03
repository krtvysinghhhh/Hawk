import Foundation
import HawkCore

/// Intelligent track matching engine with confidence scoring.
public enum TrackMatcher {

    /// Minimum confidence threshold required to consider two tracks a verified match.
    public static let confidenceThreshold: Double = 0.70

    /// Computes match confidence between 0.0 and 1.0 taking into account ISRC, title, artist, duration, and version.
    public static func matchScore(
        titleA: String,
        artistA: String,
        durationA: TimeInterval?,
        isrcA: String? = nil,
        versionA: String? = nil,
        titleB: String,
        artistB: String,
        durationB: TimeInterval?,
        isrcB: String? = nil,
        versionB: String? = nil
    ) -> Double {
        // 1. Direct ISRC Match
        if let iA = isrcA, let iB = isrcB, !iA.isEmpty && !iB.isEmpty {
            if iA.uppercased() == iB.uppercased() {
                return 1.0
            }
        }

        // 2. Version Discrepancy Check (e.g. Live vs Remix vs Original)
        let vA = versionA ?? Song.extractVersion(from: titleA)
        let vB = versionB ?? Song.extractVersion(from: titleB)
        if vA != vB {
            // Different recordings must not be cross-matched as the same track
            return 0.20
        }

        let normTitleA = normalize(titleA)
        let normTitleB = normalize(titleB)
        let normArtistA = normalize(artistA)
        let normArtistB = normalize(artistB)

        var score: Double = 0.0

        // Title match (0.5 max)
        if normTitleA == normTitleB {
            score += 0.50
        } else if normTitleA.contains(normTitleB) || normTitleB.contains(normTitleA) {
            score += 0.35
        } else {
            let sim = stringSimilarity(normTitleA, normTitleB)
            score += sim * 0.40
        }

        // Artist match (0.3 max)
        if normArtistA == normArtistB {
            score += 0.30
        } else if normArtistA.contains(normArtistB) || normArtistB.contains(normArtistA) {
            score += 0.20
        } else {
            let sim = stringSimilarity(normArtistA, normArtistB)
            score += sim * 0.25
        }

        // Duration tolerance match (0.2 max)
        if let dA = durationA, let dB = durationB, dA > 0 && dB > 0 {
            let diff = abs(dA - dB)
            if diff <= 3.0 {
                score += 0.20
            } else if diff <= 8.0 {
                score += 0.10
            } else if diff > 30.0 {
                score -= 0.35 // Large discrepancy penalizes heavily
            }
        } else {
            score += 0.10
        }

        return max(0.0, min(1.0, score))
    }

    /// Convenience overload matching by title, artist, and duration.
    public static func matchScore(
        titleA: String,
        artistA: String,
        durationA: TimeInterval?,
        titleB: String,
        artistB: String,
        durationB: TimeInterval?
    ) -> Double {
        matchScore(
            titleA: titleA,
            artistA: artistA,
            durationA: durationA,
            isrcA: nil,
            versionA: nil,
            titleB: titleB,
            artistB: artistB,
            durationB: durationB,
            isrcB: nil,
            versionB: nil
        )
    }

    private static func normalize(_ str: String) -> String {
        str.lowercased()
            .replacingOccurrences(of: "(feat.", with: "")
            .replacingOccurrences(of: "(with", with: "")
            .replacingOccurrences(of: "[official video]", with: "")
            .replacingOccurrences(of: "[official audio]", with: "")
            .trimmingCharacters(in: .punctuationCharacters)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func stringSimilarity(_ s1: String, _ s2: String) -> Double {
        guard !s1.isEmpty && !s2.isEmpty else { return 0 }
        let set1 = Set(s1)
        let set2 = Set(s2)
        let intersection = set1.intersection(set2).count
        let union = set1.union(set2).count
        return Double(intersection) / Double(union)
    }
}

/// Dynamic source resolver prioritizing providers according to connection quality, stream expiration, and availability.
public actor SourceResolver {
    public static let shared = SourceResolver()

    private var providers: [MusicSourceProvider] = []
    private var streamCache: [String: (stream: SourceStream, expiresAt: Date)] = [:]
    private var inFlightTasks: [String: Task<SourceStream, Error>] = [:]
    private let defaultTTL: TimeInterval = 3600 // 1 hour

    public init(providers: [MusicSourceProvider] = [JioSaavnSource(), YouTubeSource(), LocalLibrarySource()]) {
        self.providers = providers
    }

    public func setProviders(_ providers: [MusicSourceProvider]) {
        self.providers = providers
    }

    public func invalidate(song: Song) {
        let prefix = song.canonicalKey
        streamCache = streamCache.filter { key, _ in !key.hasPrefix(prefix) }
    }

    public func clearCache() {
        streamCache.removeAll()
    }

    /// Resolves an openable audio stream, attempting fallback across providers if needed.
    public func resolve(song: Song, qualityCeiling: AudioQuality = .high) async throws -> SourceStream {
        let cacheKey = "\(song.canonicalKey)_\(qualityCeiling.rawValue)"

        // 1. Memory cache hit with expiration verification
        if let cached = streamCache[cacheKey], cached.expiresAt > Date() {
            return cached.stream
        }

        // 2. In-flight request deduplication
        if let existingTask = inFlightTasks[cacheKey] {
            return try await existingTask.value
        }

        let task = Task<SourceStream, Error> { [weak self] in
            guard let self = self else { throw HawkError.streamNotFound(song.title) }
            return try await self.executeResolve(song: song, qualityCeiling: qualityCeiling)
        }

        inFlightTasks[cacheKey] = task

        do {
            let stream = try await task.value
            inFlightTasks.removeValue(forKey: cacheKey)

            // Calculate expiration
            let expiration = Self.extractExpiration(from: stream.url) ?? Date().addingTimeInterval(defaultTTL)
            streamCache[cacheKey] = (stream, expiration)

            return stream
        } catch {
            inFlightTasks.removeValue(forKey: cacheKey)
            throw error
        }
    }

    private func executeResolve(song: Song, qualityCeiling: AudioQuality) async throws -> SourceStream {
        // A. Local file path
        if song.localFileURL != nil || song.id.hasPrefix("file://") {
            if let localProvider = providers.first(where: { $0.sourceId == "local" }) {
                return try await localProvider.resolveStream(song: song, qualityCeiling: qualityCeiling)
            }
        }

        // B. Fast-path: Designated provider if specified
        if let targetId = song.sourceId, let targetProv = providers.first(where: { $0.sourceId == targetId }) {
            if let stream = try? await targetProv.resolveStream(song: song, qualityCeiling: qualityCeiling) {
                return stream
            }
        }

        // C. Fast-path: Direct encrypted media URI (JioSaavn)
        if song.providerIdentifiers["encrypted_media_url"] != nil || song.sourceId == "jiosaavn" {
            if let jio = providers.first(where: { $0.sourceId == "jiosaavn" }) {
                if let stream = try? await jio.resolveStream(song: song, qualityCeiling: qualityCeiling) {
                    return stream
                }
            }
        }

        // D. Try all registered providers in sequence
        for provider in providers {
            do {
                return try await provider.resolveStream(song: song, qualityCeiling: qualityCeiling)
            } catch {
                continue
            }
        }

        throw HawkError.streamNotFound(song.title)
    }

    private static func extractExpiration(from url: URL) -> Date? {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return nil }
        if let expireItem = components.queryItems?.first(where: { $0.name == "expire" || $0.name == "expires" }),
           let val = expireItem.value,
           let sec = TimeInterval(val) {
            return Date(timeIntervalSince1970: sec)
        }
        return nil
    }
}

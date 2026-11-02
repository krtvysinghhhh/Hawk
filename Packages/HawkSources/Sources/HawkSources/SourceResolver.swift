import Foundation
import HawkCore

/// Intelligent track matching engine with confidence scoring.
public enum TrackMatcher {

    /// Computes match confidence between 0.0 and 1.0.
    public static func matchScore(
        titleA: String,
        artistA: String,
        durationA: TimeInterval?,
        titleB: String,
        artistB: String,
        durationB: TimeInterval?
    ) -> Double {
        let normTitleA = normalize(titleA)
        let normTitleB = normalize(titleB)
        let normArtistA = normalize(artistA)
        let normArtistB = normalize(artistB)

        var score: Double = 0.0

        // Title match (0.5 max)
        if normTitleA == normTitleB {
            score += 0.5
        } else if normTitleA.contains(normTitleB) || normTitleB.contains(normTitleA) {
            score += 0.35
        } else {
            let sim = stringSimilarity(normTitleA, normTitleB)
            score += sim * 0.4
        }

        // Artist match (0.3 max)
        if normArtistA == normArtistB {
            score += 0.3
        } else if normArtistA.contains(normArtistB) || normArtistB.contains(normArtistA) {
            score += 0.2
        } else {
            let sim = stringSimilarity(normArtistA, normArtistB)
            score += sim * 0.25
        }

        // Duration tolerance match (0.2 max)
        if let dA = durationA, let dB = durationB, dA > 0 && dB > 0 {
            let diff = abs(dA - dB)
            if diff <= 3.0 {
                score += 0.2
            } else if diff <= 8.0 {
                score += 0.1
            } else if diff > 30.0 {
                // Large duration discrepancies penalize score heavily (e.g. live version vs single)
                score -= 0.3
            }
        } else {
            score += 0.1 // neutral default when duration is unknown
        }

        return max(0.0, min(1.0, score))
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

/// Dynamic source resolver prioritizing providers according to connection quality and availability.
public actor SourceResolver {
    public static let shared = SourceResolver()

    private var providers: [MusicSourceProvider] = []

    public init(providers: [MusicSourceProvider] = [YouTubeSource(), JioSaavnSource(), LocalLibrarySource()]) {
        self.providers = providers
    }

    public func setProviders(_ providers: [MusicSourceProvider]) {
        self.providers = providers
    }

    /// Resolves an openable audio stream, attempting fallback across providers if needed.
    public func resolve(song: Song, qualityCeiling: AudioQuality = .high) async throws -> SourceStream {
        // If song is local, resolve directly
        if song.localFileURL != nil || song.id.hasPrefix("file://") {
            if let localProvider = providers.first(where: { $0.sourceId == "local" }) {
                return try await localProvider.resolveStream(song: song, qualityCeiling: qualityCeiling)
            }
        }

        // Try primary YouTube source
        for provider in providers {
            do {
                let stream = try await provider.resolveStream(song: song, qualityCeiling: qualityCeiling)
                return stream
            } catch {
                continue
            }
        }

        throw HawkError.streamNotFound(song.id)
    }
}

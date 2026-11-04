import Foundation
import HawkCore

/// Content classification differentiating music tracks from podcasts, non-music, and uncertain video content.
public enum MusicClassification: String, Sendable, Codable {
    case officialMusic = "OFFICIAL_MUSIC"
    case musicVideo = "MUSIC_VIDEO"
    case livePerformance = "LIVE_PERFORMANCE"
    case podcast = "PODCAST"
    case nonMusic = "NON_MUSIC"
    case uncertain = "UNCERTAIN"

    public var isPlayableSong: Bool {
        switch self {
        case .officialMusic, .musicVideo, .livePerformance:
            return true
        case .podcast, .nonMusic, .uncertain:
            return false
        }
    }
}

public struct MusicClassificationResult: Sendable {
    public let classification: MusicClassification
    public let confidence: Double
    public let reasons: [String]

    public init(classification: MusicClassification, confidence: Double, reasons: [String] = []) {
        self.classification = classification
        self.confidence = confidence
        self.reasons = reasons
    }
}

/// Confidence-based multi-factor music classification engine.
public enum MusicClassificationService {

    private static let podcastKeywords = [
        "podcast", "full episode", "ep.", "episode", "talk show", "audiobook", "interview", "commentary"
    ]

    private static let nonMusicKeywords = [
        "gameplay", "walkthrough", "unboxing", "reaction", "review", "teaser", "trailer",
        "tutorial", "livestream", "vlog", "news broadcast", "highlights", "documentary"
    ]

    private static let musicVideoKeywords = [
        "official music video", "official video", "music video", " mv", "(mv)", "[mv]"
    ]

    private static let liveKeywords = [
        "live at", "live in", "live from", "acoustic live", "live concert", "live session"
    ]

    private static let officialAudioKeywords = [
        "official audio", "lyric video", "official lyric video", "visualizer", "official visualizer", "audio"
    ]

    /// Evaluates track metadata and returns a confidence-scored classification.
    public static func classify(
        title: String,
        channelOrArtist: String,
        duration: TimeInterval = 0,
        categoryId: String? = nil
    ) -> MusicClassificationResult {
        let lowerTitle = title.lowercased()
        let lowerArtist = channelOrArtist.lowercased()
        var reasons: [String] = []

        // 1. Strict Category ID validation (YouTube Category 10 is Music)
        if let cat = categoryId, cat != "10" {
            // Category is explicitly Non-Music (e.g. 20 = Gaming, 22 = People, 24 = Entertainment, 25 = News)
            reasons.append("Non-music video category: \(cat)")
            return MusicClassificationResult(classification: .nonMusic, confidence: 0.92, reasons: reasons)
        }

        // 2. Podcast detection
        for kw in podcastKeywords {
            if lowerTitle.contains(kw) || lowerArtist.contains(kw) {
                reasons.append("Matched podcast keyword: \(kw)")
                return MusicClassificationResult(classification: .podcast, confidence: 0.88, reasons: reasons)
            }
        }

        // 3. Non-music video detection
        for kw in nonMusicKeywords {
            if lowerTitle.contains(kw) || lowerArtist.contains(kw) {
                reasons.append("Matched non-music keyword: \(kw)")
                return MusicClassificationResult(classification: .nonMusic, confidence: 0.85, reasons: reasons)
            }
        }

        // 4. Overlong Duration check (> 15 minutes / 900s)
        if duration > 900 {
            let isAlbumOrMix = lowerTitle.contains("album") || lowerTitle.contains("full album") ||
                               lowerTitle.contains("greatest hits") || lowerTitle.contains("mix") ||
                               lowerTitle.contains("compilation")
            if !isAlbumOrMix {
                reasons.append("Duration exceeds 15 minutes (\(Int(duration))s) without album/mix tags")
                return MusicClassificationResult(classification: .nonMusic, confidence: 0.82, reasons: reasons)
            }
        }

        // 5. Short Snippet check (< 30 seconds)
        if duration > 0 && duration < 30 {
            reasons.append("Duration under 30 seconds: potential snippet or ringtone")
            return MusicClassificationResult(classification: .uncertain, confidence: 0.65, reasons: reasons)
        }

        // 6. Live Performance check
        for kw in liveKeywords {
            if lowerTitle.contains(kw) {
                reasons.append("Matched live performance keyword: \(kw)")
                return MusicClassificationResult(classification: .livePerformance, confidence: 0.85, reasons: reasons)
            }
        }

        // 7. Official Music Video check
        for kw in musicVideoKeywords {
            if lowerTitle.contains(kw) {
                reasons.append("Matched music video keyword: \(kw)")
                return MusicClassificationResult(classification: .musicVideo, confidence: 0.90, reasons: reasons)
            }
        }

        // 8. Official Distributor Topic Channel / VEVO check
        if lowerArtist.contains("- topic") {
            reasons.append("YouTube Music official artist topic channel")
            return MusicClassificationResult(classification: .officialMusic, confidence: 0.96, reasons: reasons)
        }
        if lowerArtist.contains("vevo") {
            reasons.append("Official VEVO music channel")
            return MusicClassificationResult(classification: .officialMusic, confidence: 0.92, reasons: reasons)
        }

        // 9. Official Audio / Lyric Video check
        for kw in officialAudioKeywords {
            if lowerTitle.contains(kw) {
                reasons.append("Matched official audio/visualizer tag: \(kw)")
                return MusicClassificationResult(classification: .officialMusic, confidence: 0.90, reasons: reasons)
            }
        }

        // 10. Plausible nominal music track
        reasons.append("Standard title/artist format with valid duration")
        return MusicClassificationResult(classification: .officialMusic, confidence: 0.78, reasons: reasons)
    }
}

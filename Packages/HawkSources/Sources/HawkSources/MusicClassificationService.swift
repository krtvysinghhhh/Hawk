import Foundation
import HawkCore

/// Content classification differentiating music recordings, live performances, DJ sets,
/// classical compositions, podcasts, non-music videos, and uncertain items.
public enum MusicClassification: String, Sendable, Codable {
    case officialRecording = "OFFICIAL_RECORDING"
    case officialMusic = "OFFICIAL_MUSIC" // Maintained for full backward compatibility
    case livePerformance = "LIVE_PERFORMANCE"
    case djSet = "DJ_SET"
    case classical = "CLASSICAL"
    case musicVideo = "MUSIC_VIDEO"
    case podcast = "PODCAST"
    case nonMusic = "NON_MUSIC"
    case uncertain = "UNCERTAIN"

    /// Whether this item represents genuine musical content (song, track, symphony, DJ set).
    public var isPlayableSong: Bool {
        switch self {
        case .officialRecording, .officialMusic, .livePerformance, .djSet, .classical, .musicVideo:
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

    /// Indicates whether the content is semantically music.
    public var isPlayableSong: Bool {
        classification.isPlayableSong
    }

    /// Explicitly indicates whether this track has direct authorized playback stream permission.
    /// A YouTube video identifier provides METADATA ONLY and NEVER implies permission to stream audio.
    public var isStreamable: Bool {
        false
    }

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

    private static let soundEffectKeywords = [
        "sound effect", "sound fx", "sfx", "meme sound", "ringtone", "alarm sound", "notification sound"
    ]

    private static let musicVideoKeywords = [
        "official music video", "official video", "music video", " mv", "(mv)", "[mv]"
    ]

    private static let liveKeywords = [
        "live at", "live in", "live from", "acoustic live", "live concert", "live session"
    ]

    private static let djSetKeywords = [
        "dj set", "boiler room", "live dj set", "club mix", "essential mix", "continuous mix",
        "extended mix", "festival mix", "minimix", "megamix", "trance mix", "dance mix",
        "techno mix", "house mix", "guest mix"
    ]

    private static let classicalKeywords = [
        "symphony", "concerto", "sonata", "opus", "op.", "allegro", "adagio", "andante",
        "presto", "philharmonic", "orchestra", "quartet", "choir", "chopin", "beethoven",
        "mozart", "bach", "vivaldi", "tchaikovsky", "rachmaninoff", "debussy", "brahms", "mahler"
    ]

    private static let shortMusicKeywords = [
        "interlude", "intro", "outro", "skit", "prelude", "overture", "reprise"
    ]

    private static let officialAudioKeywords = [
        "official audio", "(audio)", "[audio]", "lyric video", "official lyric video", "visualizer", "official visualizer"
    ]

    /// Evaluates track metadata and returns a confidence-scored classification with explicit reasons.
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
            reasons.append("Non-music video category: \(cat)")
            return MusicClassificationResult(classification: .nonMusic, confidence: 0.92, reasons: reasons)
        }

        // 2. DJ Set check (supports extended duration mixes)
        for kw in djSetKeywords {
            if lowerTitle.contains(kw) || lowerArtist.contains(kw) {
                reasons.append("Identified DJ set or continuous mix keyword: \(kw)")
                return MusicClassificationResult(classification: .djSet, confidence: 0.92, reasons: reasons)
            }
        }

        // 3. Classical music check (supports symphonies, concertos, and short preludes)
        for kw in classicalKeywords {
            if lowerTitle.contains(kw) || lowerArtist.contains(kw) {
                reasons.append("Identified classical/orchestral keyword: \(kw)")
                return MusicClassificationResult(classification: .classical, confidence: 0.90, reasons: reasons)
            }
        }

        // 4. Podcast detection
        for kw in podcastKeywords {
            if lowerTitle.contains(kw) || lowerArtist.contains(kw) {
                reasons.append("Matched podcast keyword: \(kw)")
                return MusicClassificationResult(classification: .podcast, confidence: 0.88, reasons: reasons)
            }
        }

        // 5. Sound effect / ringtone detection
        for kw in soundEffectKeywords {
            if lowerTitle.contains(kw) {
                reasons.append("Matched non-music sound effect keyword: \(kw)")
                return MusicClassificationResult(classification: .nonMusic, confidence: 0.88, reasons: reasons)
            }
        }

        // 6. Non-music video detection (gameplay, vlogs, reviews)
        for kw in nonMusicKeywords {
            if lowerTitle.contains(kw) || lowerArtist.contains(kw) {
                reasons.append("Matched non-music keyword: \(kw)")
                return MusicClassificationResult(classification: .nonMusic, confidence: 0.85, reasons: reasons)
            }
        }

        // 7. Live Performance check
        for kw in liveKeywords {
            if lowerTitle.contains(kw) {
                reasons.append("Matched live performance keyword: \(kw)")
                return MusicClassificationResult(classification: .livePerformance, confidence: 0.88, reasons: reasons)
            }
        }

        // 8. Official Music Video check
        for kw in musicVideoKeywords {
            if lowerTitle.contains(kw) {
                reasons.append("Matched music video keyword: \(kw)")
                return MusicClassificationResult(classification: .musicVideo, confidence: 0.90, reasons: reasons)
            }
        }

        // 9. Official Distributor Topic Channel / VEVO check
        if lowerArtist.contains("- topic") {
            reasons.append("YouTube Music official artist topic channel")
            return MusicClassificationResult(classification: .officialMusic, confidence: 0.96, reasons: reasons)
        }
        if lowerArtist.contains("vevo") {
            reasons.append("Official VEVO music channel")
            return MusicClassificationResult(classification: .officialMusic, confidence: 0.92, reasons: reasons)
        }

        // 10. Official Audio / Lyric Video check
        for kw in officialAudioKeywords {
            if lowerTitle.contains(kw) {
                reasons.append("Matched official audio/visualizer tag: \(kw)")
                return MusicClassificationResult(classification: .officialMusic, confidence: 0.90, reasons: reasons)
            }
        }

        // 11. Short Track handling (< 30s) - Do NOT automatically reject legitimate short music
        if duration > 0 && duration < 30 {
            for kw in shortMusicKeywords {
                if lowerTitle.contains(kw) {
                    reasons.append("Legitimate short album interlude/intro: \(kw)")
                    return MusicClassificationResult(classification: .officialMusic, confidence: 0.85, reasons: reasons)
                }
            }
            if !lowerArtist.isEmpty && lowerArtist != "unknown artist" {
                reasons.append("Short musical track from identified artist (\(Int(duration))s)")
                return MusicClassificationResult(classification: .officialMusic, confidence: 0.75, reasons: reasons)
            }
            reasons.append("Short duration under 30s with unverified musical metadata; preserved as metadata")
            return MusicClassificationResult(classification: .uncertain, confidence: 0.60, reasons: reasons)
        }

        // 12. Overlong Duration check (> 15 minutes / 900s)
        if duration > 900 {
            let isAlbumOrMix = lowerTitle.contains("album") || lowerTitle.contains("full album") ||
                               lowerTitle.contains("greatest hits") || lowerTitle.contains("discography") ||
                               lowerTitle.contains("compilation")
            if isAlbumOrMix {
                reasons.append("Long-duration album compilation (\(Int(duration))s)")
                return MusicClassificationResult(classification: .officialMusic, confidence: 0.88, reasons: reasons)
            }
            reasons.append("Duration exceeds 15 minutes (\(Int(duration))s) without music or DJ set markers; preserved as metadata")
            return MusicClassificationResult(classification: .uncertain, confidence: 0.60, reasons: reasons)
        }

        // 13. Plausible nominal music track
        reasons.append("Standard title/artist format with valid duration")
        return MusicClassificationResult(classification: .officialMusic, confidence: 0.78, reasons: reasons)
    }
}

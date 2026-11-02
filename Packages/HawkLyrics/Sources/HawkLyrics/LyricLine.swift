import Foundation

/// One word or syllable within a synchronized line of lyrics.
public struct LyricWord: Identifiable, Sendable, Hashable {
    public var id: String { "\(startTime)_\(text)" }
    public let text: String
    public let startTime: TimeInterval
    public let endTime: TimeInterval

    public init(text: String, startTime: TimeInterval, endTime: TimeInterval) {
        self.text = text
        self.startTime = startTime
        self.endTime = endTime
    }
}

/// One line of synchronized lyrics.
public struct LyricLine: Identifiable, Sendable, Hashable {
    public var id: String { "\(timestamp)_\(text)" }
    public let timestamp: TimeInterval
    public let text: String
    public let words: [LyricWord]

    public var isWordSynced: Bool {
        !words.isEmpty
    }

    public init(timestamp: TimeInterval, text: String, words: [LyricWord] = []) {
        self.timestamp = timestamp
        self.text = text
        self.words = words
    }
}

/// High-performance parser for standard `.lrc` lyrics strings.
public enum LrcParser {

    /// Parses `.lrc` text containing `[mm:ss.xx]` timestamped lines.
    public static func parse(_ lrcContent: String) -> [LyricLine] {
        var lines: [LyricLine] = []
        let rawLines = lrcContent.components(separatedBy: .newlines)

        // Matches [01:23.45] or [01:23.456]
        let regex = try? NSRegularExpression(pattern: "\\[(\\d{2}):(\\d{2})(?:\\.(\\d{2,3}))?\\](.*)")

        for raw in rawLines {
            let trimmed = raw.trimmingCharacters(in: .whitespaces)
            guard let match = regex?.firstMatch(in: trimmed, range: NSRange(trimmed.startIndex..., in: trimmed)) else {
                continue
            }

            guard let minRange = Range(match.range(at: 1), in: trimmed),
                  let secRange = Range(match.range(at: 2), in: trimmed),
                  let textRange = Range(match.range(at: 4), in: trimmed) else { continue }

            let min = Double(trimmed[minRange]) ?? 0
            let sec = Double(trimmed[secRange]) ?? 0
            var fraction: Double = 0

            if match.numberOfRanges > 3, match.range(at: 3).location != NSNotFound,
               let fracRange = Range(match.range(at: 3), in: trimmed) {
                let fracStr = String(trimmed[fracRange])
                let divisor = pow(10.0, Double(fracStr.count))
                fraction = (Double(fracStr) ?? 0) / divisor
            }

            let timestamp = min * 60.0 + sec + fraction
            let text = String(trimmed[textRange]).trimmingCharacters(in: .whitespaces)

            lines.append(LyricLine(timestamp: timestamp, text: text))
        }

        return lines.sorted { $0.timestamp < $1.timestamp }
    }
}

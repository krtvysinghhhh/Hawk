import Foundation

/// One word or syllable within a synchronized line of lyrics.
public struct LyricWord: Identifiable, Sendable, Hashable, Codable {
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
public struct LyricLine: Identifiable, Sendable, Hashable, Codable {
    public let id: String
    public let timestamp: TimeInterval
    public let text: String
    public let words: [LyricWord]

    public var isWordSynced: Bool {
        !words.isEmpty
    }

    public init(id: String? = nil, timestamp: TimeInterval, text: String, words: [LyricWord] = []) {
        self.id = id ?? "\(timestamp)_\(text)"
        self.timestamp = timestamp
        self.text = text
        self.words = words
    }
}

/// High-performance, robust parser for standard and enhanced `.lrc` lyrics strings.
public enum LrcParser {

    /// Parses `.lrc` text containing `[mm:ss.xx]` timestamped lines, supporting multiple timestamps per line,
    /// variable decimal precision, word-level timestamps, and Unicode/UTF-8 lyrics.
    public static func parse(_ lrcContent: String) -> [LyricLine] {
        var rawParsed: [(timestamp: TimeInterval, text: String, words: [LyricWord])] = []
        let rawLines = lrcContent.components(separatedBy: .newlines)

        // Matches one timestamp tag: [01:23.45], [1:23], [01:23.456]
        let tagPattern = "\\[(\\d{1,2}):(\\d{2})(?:\\.(\\d{1,3}))?\\]"
        guard let tagRegex = try? NSRegularExpression(pattern: tagPattern) else {
            return []
        }

        for raw in rawLines {
            let trimmed = raw.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }

            // Find all leading timestamp tags
            let nsString = trimmed as NSString
            let fullRange = NSRange(location: 0, length: nsString.length)
            let matches = tagRegex.matches(in: trimmed, range: fullRange)
            guard !matches.isEmpty else { continue }

            // Determine where the lyric text starts (after the last consecutive timestamp tag)
            var lastTagEnd = 0
            var timestamps: [TimeInterval] = []

            for match in matches {
                // Ensure tags are at the start of the line or immediately adjacent
                if match.range.location > lastTagEnd + 2 {
                    // Tag is not at header, could be inline or malformed
                    break
                }
                lastTagEnd = match.range.location + match.range.length

                let minStr = nsString.substring(with: match.range(at: 1))
                let secStr = nsString.substring(with: match.range(at: 2))
                let min = Double(minStr) ?? 0
                let sec = Double(secStr) ?? 0
                var fraction: Double = 0

                if match.numberOfRanges > 3 && match.range(at: 3).location != NSNotFound {
                    let fracStr = nsString.substring(with: match.range(at: 3))
                    let divisor = pow(10.0, Double(fracStr.count))
                    fraction = (Double(fracStr) ?? 0) / divisor
                }

                let timestamp = min * 60.0 + sec + fraction
                timestamps.append(timestamp)
            }

            guard !timestamps.isEmpty else { continue }

            let textRange = NSRange(location: lastTagEnd, length: nsString.length - lastTagEnd)
            let rawText = nsString.substring(with: textRange).trimmingCharacters(in: .whitespaces)

            // Parse word-level enhanced LRC timestamps if present
            for ts in timestamps {
                let (cleanText, words) = parseWords(rawText: rawText, lineTimestamp: ts)
                rawParsed.append((timestamp: ts, text: cleanText, words: words))
            }
        }

        // Sort monotonically by timestamp
        let sorted = rawParsed.sorted { $0.timestamp < $1.timestamp }

        // Construct LyricLine objects with guaranteed stable unique IDs
        var result: [LyricLine] = []
        result.reserveCapacity(sorted.count)
        for (index, item) in sorted.enumerated() {
            let stableId = "\(index)_\(item.timestamp)_\(item.text.prefix(16))"
            result.append(LyricLine(id: stableId, timestamp: item.timestamp, text: item.text, words: item.words))
        }

        return result
    }

    private static func parseWords(rawText: String, lineTimestamp: TimeInterval) -> (cleanText: String, words: [LyricWord]) {
        guard rawText.contains("<") else { return (rawText, []) }
        guard let wordRegex = try? NSRegularExpression(pattern: "<(\\d{1,2}):(\\d{2})(?:\\.(\\d{1,3}))?>([^<]+)") else {
            return (rawText, [])
        }

        let nsString = rawText as NSString
        let matches = wordRegex.matches(in: rawText, range: NSRange(location: 0, length: nsString.length))
        guard !matches.isEmpty else { return (rawText, []) }

        var words: [LyricWord] = []
        for i in 0..<matches.count {
            let match = matches[i]
            let mStr = nsString.substring(with: match.range(at: 1))
            let sStr = nsString.substring(with: match.range(at: 2))
            let wStr = nsString.substring(with: match.range(at: 4)).trimmingCharacters(in: .whitespaces)

            let min = Double(mStr) ?? 0
            let sec = Double(sStr) ?? 0
            var frac: Double = 0
            if match.numberOfRanges > 3 && match.range(at: 3).location != NSNotFound {
                let fracStr = nsString.substring(with: match.range(at: 3))
                let divisor = pow(10.0, Double(fracStr.count))
                frac = (Double(fracStr) ?? 0) / divisor
            }
            let startTime = min * 60.0 + sec + frac

            var endTime = startTime + 0.4
            if i + 1 < matches.count {
                let nextMatch = matches[i + 1]
                let nmStr = nsString.substring(with: nextMatch.range(at: 1))
                let nsStr = nsString.substring(with: nextMatch.range(at: 2))
                let nMin = Double(nmStr) ?? 0
                let nSec = Double(nsStr) ?? 0
                var nFrac: Double = 0
                if nextMatch.numberOfRanges > 3 && nextMatch.range(at: 3).location != NSNotFound {
                    let nfStr = nsString.substring(with: nextMatch.range(at: 3))
                    let nDivisor = pow(10.0, Double(nfStr.count))
                    nFrac = (Double(nfStr) ?? 0) / nDivisor
                }
                endTime = nMin * 60.0 + nSec + nFrac
            }
            words.append(LyricWord(text: wStr, startTime: startTime, endTime: endTime))
        }

        let clean = words.map { $0.text }.joined(separator: " ")
        return (clean.isEmpty ? rawText : clean, words)
    }
}

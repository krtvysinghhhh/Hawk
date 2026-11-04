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
            let rawText = String(trimmed[textRange]).trimmingCharacters(in: .whitespaces)
            let (cleanText, words) = parseWords(rawText: rawText, lineTimestamp: timestamp)

            lines.append(LyricLine(timestamp: timestamp, text: cleanText, words: words))
        }

        return lines.sorted { $0.timestamp < $1.timestamp }
    }

    private static func parseWords(rawText: String, lineTimestamp: TimeInterval) -> (cleanText: String, words: [LyricWord]) {
        guard rawText.contains("<") else { return (rawText, []) }
        guard let wordRegex = try? NSRegularExpression(pattern: "<(\\d{2}):(\\d{2})(?:\\.(\\d{2,3}))?>([^<]+)") else {
            return (rawText, [])
        }

        let matches = wordRegex.matches(in: rawText, range: NSRange(rawText.startIndex..., in: rawText))
        guard !matches.isEmpty else { return (rawText, []) }

        var words: [LyricWord] = []
        for i in 0..<matches.count {
            let match = matches[i]
            guard let mR = Range(match.range(at: 1), in: rawText),
                  let sR = Range(match.range(at: 2), in: rawText),
                  let wR = Range(match.range(at: 4), in: rawText) else { continue }

            let min = Double(rawText[mR]) ?? 0
            let sec = Double(rawText[sR]) ?? 0
            var frac: Double = 0
            if match.numberOfRanges > 3, match.range(at: 3).location != NSNotFound,
               let fR = Range(match.range(at: 3), in: rawText) {
                let fracStr = String(rawText[fR])
                let divisor = pow(10.0, Double(fracStr.count))
                frac = (Double(fracStr) ?? 0) / divisor
            }
            let startTime = min * 60.0 + sec + frac
            let wordStr = String(rawText[wR]).trimmingCharacters(in: .whitespaces)

            var endTime = startTime + 0.4
            if i + 1 < matches.count {
                let nextMatch = matches[i + 1]
                if let nmR = Range(nextMatch.range(at: 1), in: rawText),
                   let nsR = Range(nextMatch.range(at: 2), in: rawText) {
                    let nMin = Double(rawText[nmR]) ?? 0
                    let nSec = Double(rawText[nsR]) ?? 0
                    var nFrac: Double = 0
                    if nextMatch.numberOfRanges > 3, nextMatch.range(at: 3).location != NSNotFound,
                       let nfR = Range(nextMatch.range(at: 3), in: rawText) {
                        let nfStr = String(rawText[nfR])
                        let nDivisor = pow(10.0, Double(nfStr.count))
                        nFrac = (Double(nfStr) ?? 0) / nDivisor
                    }
                    endTime = nMin * 60.0 + nSec + nFrac
                }
            }
            words.append(LyricWord(text: wordStr, startTime: startTime, endTime: endTime))
        }

        let clean = words.map { $0.text }.joined(separator: " ")
        return (clean.isEmpty ? rawText : clean, words)
    }
}

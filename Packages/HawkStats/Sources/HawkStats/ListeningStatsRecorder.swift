import Foundation
import HawkCore

/// Actor recording authentic wall-clock listening statistics, persistent history, and generating monthly Replay recaps.
public actor ListeningStatsRecorder {
    public static let shared = ListeningStatsRecorder()

    private let storageDirectory: URL
    private let recentlyPlayedURL: URL
    private var currentSongId: String?
    private var currentSong: Song?
    private var lastSampleTimestamp: Date?
    private var currentTrackListenedSeconds: Double = 0
    private var playCountRegistered: Bool = false

    private var activeBucket: MonthlyBucket?
    private var recentlyPlayed: [Song] = []

    public init(storageDirectory: URL? = nil) {
        let dir: URL
        if let customDir = storageDirectory {
            dir = customDir
        } else {
            let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            dir = docs.appendingPathComponent("HawkStats", isDirectory: true)
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        self.storageDirectory = dir
        self.recentlyPlayedURL = dir.appendingPathComponent("recently_played.json")

        // Load persisted recent tracks
        if let data = try? Data(contentsOf: self.recentlyPlayedURL),
           let list = try? JSONDecoder().decode([Song].self, from: data) {
            self.recentlyPlayed = list
        }
    }

    /// Returns persistent history of genuinely listened tracks.
    public func getRecentlyPlayed() -> [Song] {
        return recentlyPlayed
    }

    public func clearRecentlyPlayed() {
        recentlyPlayed.removeAll()
        saveRecentlyPlayed()
    }

    /// Ticks progress from the playback engine sampler.
    ///
    /// - Parameters:
    ///   - song: The currently playing song.
    ///   - isPlaying: Whether audio is genuinely rendering.
    public func onSample(song: Song, isPlaying: Bool) {
        let now = Date()

        if currentSongId != song.id {
            // New track started: record into listening history
            currentSongId = song.id
            currentSong = song
            currentTrackListenedSeconds = 0
            playCountRegistered = false
            lastSampleTimestamp = isPlaying ? now : nil

            recordRecentlyPlayed(song: song)
            return
        }

        guard isPlaying else {
            lastSampleTimestamp = nil
            return
        }

        guard let last = lastSampleTimestamp else {
            lastSampleTimestamp = now
            return
        }

        let delta = now.timeIntervalSince(last)
        lastSampleTimestamp = now

        // Cap delta at 5 seconds to prevent lock screen pauses or skips inflating statistics
        guard delta > 0 && delta <= 5.0 else { return }

        currentTrackListenedSeconds += delta

        // Play count qualifies at 50% of track length or 4 minutes (240s floor)
        let threshold = song.duration > 0 ? min(song.duration * 0.5, 240.0) : 30.0
        let qualifiesPlayCount = !playCountRegistered && currentTrackListenedSeconds >= threshold

        if qualifiesPlayCount {
            playCountRegistered = true
        }

        recordListening(song: song, seconds: delta, countPlay: qualifiesPlayCount)
    }

    private func recordRecentlyPlayed(song: Song) {
        recentlyPlayed.removeAll(where: { $0.id == song.id })
        recentlyPlayed.insert(song, at: 0)
        if recentlyPlayed.count > 50 {
            recentlyPlayed = Array(recentlyPlayed.prefix(50))
        }
        saveRecentlyPlayed()
    }

    private func saveRecentlyPlayed() {
        guard let data = try? JSONEncoder().encode(recentlyPlayed) else { return }
        try? data.write(to: recentlyPlayedURL, options: .atomic)
    }

    private func recordListening(song: Song, seconds: Double, countPlay: Bool) {
        let monthKey = currentMonthKey()
        var bucket = activeBucket ?? loadBucket(monthKey: monthKey) ?? MonthlyBucket(monthKey: monthKey)

        bucket.totalListeningSeconds += seconds

        let day = Calendar.current.component(.day, from: Date())
        bucket.dailyListeningSeconds[day, default: 0] += seconds

        // Update track stat
        var trackStat = bucket.tracks[song.id] ?? TrackPlayStat(
            songId: song.id,
            title: song.title,
            artist: song.artist,
            playCount: 0,
            totalSeconds: 0
        )
        trackStat.totalSeconds += seconds
        if countPlay { trackStat.playCount += 1 }
        bucket.tracks[song.id] = trackStat

        // Update artist stat
        var artistStat = bucket.artists[song.artist] ?? ArtistPlayStat(
            name: song.artist,
            playCount: 0,
            totalSeconds: 0
        )
        artistStat.totalSeconds += seconds
        if countPlay { artistStat.playCount += 1 }
        bucket.artists[song.artist] = artistStat

        activeBucket = bucket

        // Flush bucket asynchronously
        saveBucket(bucket)
    }

    public func getMonthlyReplay(monthKey: String) -> MonthlyBucket? {
        if let active = activeBucket, active.monthKey == monthKey {
            return active
        }
        return loadBucket(monthKey: monthKey)
    }

    private func currentMonthKey() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        return formatter.string(from: Date())
    }

    private func bucketFileURL(monthKey: String) -> URL {
        storageDirectory.appendingPathComponent("\(monthKey).json")
    }

    private func saveBucket(_ bucket: MonthlyBucket) {
        let file = bucketFileURL(monthKey: bucket.monthKey)
        guard let data = try? JSONEncoder().encode(bucket) else { return }
        try? data.write(to: file, options: .atomic)
    }

    private func loadBucket(monthKey: String) -> MonthlyBucket? {
        let file = bucketFileURL(monthKey: monthKey)
        guard let data = try? Data(contentsOf: file) else { return nil }
        return try? JSONDecoder().decode(MonthlyBucket.self, from: data)
    }
}

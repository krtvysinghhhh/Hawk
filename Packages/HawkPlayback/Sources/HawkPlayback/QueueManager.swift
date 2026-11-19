import Foundation
import HawkCore

public enum RepeatMode: String, Codable, Sendable {
    case off = "OFF"
    case all = "ALL"
    case one = "ONE"
}

/// Actor managing the multi-tier queue state machine with tier isolation, stable identification, and history.
public actor QueueManager {
    public static let shared = QueueManager()

    public private(set) var userQueue: [Song] = []
    public private(set) var contextQueue: [Song] = []
    public private(set) var autoplayQueue: [Song] = []
    public private(set) var playHistory: [Song] = []

    public private(set) var currentIndex: Int = 0
    public private(set) var repeatMode: RepeatMode = .off
    public private(set) var isShuffleActive: Bool = false

    private var originalContextQueue: [Song] = []
    private let queueStateURL: URL

    public init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first ?? FileManager.default.temporaryDirectory
        let url = docs.appendingPathComponent("hawk_queue_snapshot.json")
        self.queueStateURL = url

        if let loaded = Self.loadSnapshot(from: url) {
            self.userQueue = loaded.userQueue
            self.contextQueue = loaded.contextQueue
            self.autoplayQueue = loaded.autoplayQueue
            self.originalContextQueue = loaded.contextQueue
            self.currentIndex = loaded.currentIndex
        }
    }

    /// Complete unified timeline in playback order: USER_QUEUE -> CONTEXT -> AUTOPLAY.
    public var fullTimeline: [Song] {
        userQueue + contextQueue + autoplayQueue
    }

    public var currentSong: Song? {
        let timeline = fullTimeline
        guard currentIndex >= 0 && currentIndex < timeline.count else { return nil }
        return timeline[currentIndex]
    }

    // MARK: - Queue Population
    public func setContext(songs: [Song], startAt index: Int = 0) {
        self.contextQueue = songs.map { $0.withQueueMetadata(tier: .context) }
        self.originalContextQueue = self.contextQueue
        self.userQueue = []
        self.autoplayQueue = []
        self.currentIndex = min(max(0, index), max(0, songs.count - 1))
        self.isShuffleActive = false
    }

    public func playNext(song: Song) {
        let queued = song.withQueueMetadata(tier: .userQueue)
        if currentIndex < userQueue.count {
            userQueue.insert(queued, at: currentIndex + 1)
        } else {
            // If currently in context or at start, insert at head of userQueue
            userQueue.insert(queued, at: 0)
        }
    }

    public func addToQueue(song: Song) {
        let queued = song.withQueueMetadata(tier: .userQueue)
        userQueue.append(queued)
    }

    public func appendAutoplay(songs: [Song]) {
        let mapped = songs.map { $0.withQueueMetadata(tier: .autoplay) }
        self.autoplayQueue.append(contentsOf: mapped)
    }

    // MARK: - Navigation
    public func next(isAutoAdvance: Bool = false) -> Song? {
        let timeline = fullTimeline
        guard !timeline.isEmpty else { return nil }

        if isAutoAdvance && repeatMode == .one {
            return currentSong
        }

        if let current = currentSong {
            playHistory.append(current)
            if playHistory.count > 100 {
                playHistory.removeFirst()
            }
        }

        if currentIndex + 1 < timeline.count {
            currentIndex += 1
            return timeline[currentIndex]
        } else if repeatMode == .all {
            currentIndex = 0
            return timeline.first
        }

        return nil
    }

    /// Returns the upcoming track without advancing the queue position, enabling predictive preloading.
    public func peekNext() -> Song? {
        let timeline = fullTimeline
        guard !timeline.isEmpty else { return nil }

        if repeatMode == .one {
            return currentSong
        }

        if currentIndex + 1 < timeline.count {
            return timeline[currentIndex + 1]
        } else if repeatMode == .all {
            return timeline.first
        }

        return nil
    }

    public func previous() -> Song? {
        let timeline = fullTimeline
        guard !timeline.isEmpty else { return nil }

        if currentIndex > 0 {
            currentIndex -= 1
            return timeline[currentIndex]
        } else if repeatMode == .all {
            currentIndex = timeline.count - 1
            return timeline.last
        }

        return currentSong
    }

    public func jumpTo(index: Int) -> Song? {
        let timeline = fullTimeline
        guard index >= 0 && index < timeline.count else { return nil }
        currentIndex = index
        return timeline[index]
    }

    public func jumpTo(songId: String) -> Song? {
        let timeline = fullTimeline
        guard let idx = timeline.firstIndex(where: { $0.id == songId }) else { return nil }
        currentIndex = idx
        return timeline[idx]
    }

    public func jumpTo(entryId: UUID) -> Song? {
        let timeline = fullTimeline
        guard let idx = timeline.firstIndex(where: { $0.queueEntryId == entryId }) else { return nil }
        currentIndex = idx
        return timeline[idx]
    }

    // MARK: - Smart Shuffle & Repeat
    public func toggleShuffle() {
        isShuffleActive.toggle()
        if isShuffleActive {
            let current = currentSong
            contextQueue = Self.smartShuffle(songs: contextQueue, keepCurrentAtStart: current)
        } else {
            contextQueue = originalContextQueue
        }
        saveQueueState()
    }

    /// Smart shuffle distributes tracks by spacing identical artists apart and avoiding immediate repeats.
    nonisolated public static func smartShuffle(songs: [Song], keepCurrentAtStart: Song? = nil) -> [Song] {
        guard songs.count > 2 else { return songs }
        var pool = songs
        if let current = keepCurrentAtStart {
            pool.removeAll { $0.id == current.id }
        }
        pool.shuffle()

        var result: [Song] = []
        if let current = keepCurrentAtStart {
            result.append(current)
        }

        while !pool.isEmpty {
            let lastArtist = result.last?.artist.lowercased()

            // Group eligible songs by artist (not matching last played artist)
            let eligible = pool.filter { $0.artist.lowercased() != lastArtist }
            if !eligible.isEmpty {
                // Pick from the artist with the highest remaining frequency in the entire pool
                var counts: [String: Int] = [:]
                for s in pool {
                    counts[s.artist.lowercased(), default: 0] += 1
                }
                let chosenArtist = eligible.max { (counts[$0.artist.lowercased()] ?? 0) < (counts[$1.artist.lowercased()] ?? 0) }!.artist.lowercased()
                if let index = pool.firstIndex(where: { $0.artist.lowercased() == chosenArtist }) {
                    result.append(pool.remove(at: index))
                }
            } else {
                // If only same artist remains, back-insert into result at a non-conflicting position
                let candidate = pool.removeFirst()
                let candidateArtist = candidate.artist.lowercased()
                var inserted = false

                let startIdx = keepCurrentAtStart != nil ? 1 : 0
                if result.count > startIdx {
                    for i in startIdx...result.count {
                        let prevMatches = (i > 0 && result[i - 1].artist.lowercased() == candidateArtist)
                        let nextMatches = (i < result.count && result[i].artist.lowercased() == candidateArtist)
                        if !prevMatches && !nextMatches {
                            result.insert(candidate, at: i)
                            inserted = true
                            break
                        }
                    }
                }

                if !inserted {
                    result.append(candidate)
                }
            }
        }
        return result
    }

    public func toggleRepeat() {
        switch repeatMode {
        case .off: repeatMode = .all
        case .all: repeatMode = .one
        case .one: repeatMode = .off
        }
        saveQueueState()
    }

    public func setRepeatMode(_ mode: RepeatMode) {
        self.repeatMode = mode
        saveQueueState()
    }

    // MARK: - Track Removal & Reordering
    public func removeTrack(entryId: UUID) {
        if let idx = userQueue.firstIndex(where: { $0.queueEntryId == entryId }) {
            userQueue.remove(at: idx)
            if idx < currentIndex { currentIndex -= 1 }
        } else if let idx = contextQueue.firstIndex(where: { $0.queueEntryId == entryId }) {
            contextQueue.remove(at: idx)
            let actualIdx = userQueue.count + idx
            if actualIdx < currentIndex { currentIndex -= 1 }
        } else if let idx = autoplayQueue.firstIndex(where: { $0.queueEntryId == entryId }) {
            autoplayQueue.remove(at: idx)
            let actualIdx = userQueue.count + contextQueue.count + idx
            if actualIdx < currentIndex { currentIndex -= 1 }
        }
        let count = fullTimeline.count
        if count > 0 {
            currentIndex = max(0, min(currentIndex, count - 1))
        } else {
            currentIndex = 0
        }
        saveQueueState()
    }

    public func moveUserQueueItem(fromOffsets source: IndexSet, toOffset destination: Int) {
        var itemsToMove: [Song] = []
        for index in source.sorted(by: >) {
            if index < userQueue.count {
                itemsToMove.append(userQueue.remove(at: index))
            }
        }
        itemsToMove.reverse()
        let dest = min(destination, userQueue.count)
        userQueue.insert(contentsOf: itemsToMove, at: dest)
        saveQueueState()
    }

    public func clearQueue() {
        userQueue = []
        contextQueue = []
        autoplayQueue = []
        originalContextQueue = []
        playHistory = []
        currentIndex = 0
        saveQueueState()
    }

    // MARK: - Smart Continuation & Autoplay
    /// Appends similar tracks to autoplay queue when nearing the end of current playlist.
    public func triggerSmartContinuation(similarSongs: [Song]) {
        let existingIds = Set(fullTimeline.map(\.id))
        let fresh = similarSongs.filter { !existingIds.contains($0.id) }
        guard !fresh.isEmpty else { return }
        appendAutoplay(songs: fresh)
        saveQueueState()
    }

    // MARK: - Queue State Snapshot Persistence
    private struct QueueSnapshot: Codable {
        let userQueue: [Song]
        let contextQueue: [Song]
        let autoplayQueue: [Song]
        let currentIndex: Int
    }

    public func saveQueueState() {
        let snapshot = QueueSnapshot(
            userQueue: userQueue,
            contextQueue: contextQueue,
            autoplayQueue: autoplayQueue,
            currentIndex: currentIndex
        )
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        try? data.write(to: queueStateURL, options: .atomic)
    }

    private static func loadSnapshot(from url: URL) -> (userQueue: [Song], contextQueue: [Song], autoplayQueue: [Song], currentIndex: Int)? {
        guard let data = try? Data(contentsOf: url),
              let snapshot = try? JSONDecoder().decode(QueueSnapshot.self, from: data) else {
            return nil
        }
        let totalCount = snapshot.userQueue.count + snapshot.contextQueue.count + snapshot.autoplayQueue.count
        let validIdx = totalCount > 0 ? min(max(0, snapshot.currentIndex), totalCount - 1) : 0
        return (snapshot.userQueue, snapshot.contextQueue, snapshot.autoplayQueue, validIdx)
    }
}

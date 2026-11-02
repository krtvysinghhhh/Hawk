import Foundation
import HawkCore

public enum RepeatMode: String, Codable, Sendable {
    case off = "OFF"
    case all = "ALL"
    case one = "ONE"
}

/// Actor managing the multi-tier queue state machine with tier isolation and persistence.
public actor QueueManager {
    public static let shared = QueueManager()

    public private(set) var userQueue: [Song] = []
    public private(set) var contextQueue: [Song] = []
    public private(set) var autoplayQueue: [Song] = []

    public private(set) var currentIndex: Int = 0
    public private(set) var repeatMode: RepeatMode = .off
    public private(set) var isShuffleActive: Bool = false

    private var originalContextQueue: [Song] = []

    public init() {}

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
        // Insert directly after the currently playing track
        let insertIndex = min(currentIndex + 1, fullTimeline.count)
        if insertIndex <= userQueue.count {
            userQueue.insert(queued, at: insertIndex)
        } else {
            userQueue.append(queued)
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
    public func next() -> Song? {
        let timeline = fullTimeline
        guard !timeline.isEmpty else { return nil }

        if repeatMode == .one {
            return currentSong
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

    // MARK: - Shuffle & Repeat
    public func toggleShuffle() {
        isShuffleActive.toggle()
        if isShuffleActive {
            // Preserve user-inserted queue, shuffle only the contextual queue
            var shuffledContext = contextQueue
            shuffledContext.shuffle()
            contextQueue = shuffledContext
        } else {
            // Restore original album/playlist context order
            contextQueue = originalContextQueue
        }
    }

    public func toggleRepeat() {
        switch repeatMode {
        case .off: repeatMode = .all
        case .all: repeatMode = .one
        case .one: repeatMode = .off
        }
    }

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
    }

    public func clearQueue() {
        userQueue = []
        contextQueue = []
        autoplayQueue = []
        originalContextQueue = []
        currentIndex = 0
    }
}

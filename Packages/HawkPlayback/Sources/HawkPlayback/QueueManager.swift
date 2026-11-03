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
    public func next() -> Song? {
        let timeline = fullTimeline
        guard !timeline.isEmpty else { return nil }

        if repeatMode == .one {
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

    public func jumpTo(entryId: UUID) -> Song? {
        let timeline = fullTimeline
        guard let idx = timeline.firstIndex(where: { $0.queueEntryId == entryId }) else { return nil }
        currentIndex = idx
        return timeline[idx]
    }

    // MARK: - Shuffle & Repeat
    public func toggleShuffle() {
        isShuffleActive.toggle()
        if isShuffleActive {
            var shuffledContext = contextQueue
            shuffledContext.shuffle()
            contextQueue = shuffledContext
        } else {
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

    public func setRepeatMode(_ mode: RepeatMode) {
        self.repeatMode = mode
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
    }

    public func clearQueue() {
        userQueue = []
        contextQueue = []
        autoplayQueue = []
        originalContextQueue = []
        playHistory = []
        currentIndex = 0
    }
}

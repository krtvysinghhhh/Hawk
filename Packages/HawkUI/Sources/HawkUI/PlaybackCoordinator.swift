import Foundation
import SwiftUI
import HawkCore
import HawkPlayback
import HawkSources
import HawkStats

/// Primary reactive playback coordinator bridging UI controls to HawkAudioEngine, QueueManager, and PlaylistStore.
@MainActor
@Observable
public final class PlaybackCoordinator {
    public static let shared = PlaybackCoordinator()

    public var currentSong: Song?
    public var playbackState: PlaybackState = .idle
    public var currentTime: TimeInterval = 0.0
    public var duration: TimeInterval = 0.0
    public var errorMessage: String?
    public var showNowPlaying: Bool = false
    public var isFavorite: Bool = false
    public var repeatMode: RepeatMode = .off
    public var isShuffleActive: Bool = false
    public var queue: [Song] = []

    public var isPlaying: Bool {
        playbackState.isPlaying
    }

    public var isBuffering: Bool {
        playbackState.isBuffering
    }

    public var formattedCurrentTime: String {
        Song.formatDuration(currentTime)
    }

    public var formattedRemainingTime: String {
        guard duration > 0 && duration >= currentTime else { return "--:--" }
        return "-" + Song.formatDuration(duration - currentTime)
    }

    private var pollTask: Task<Void, Never>?
    private var playbackTask: Task<Void, Never>?
    private var navigationRequestId: UInt64 = 0

    public init() {
        startPolling()
        setupTrackFinishedCallback()
        setupRemoteHandlers()
    }

    private func setupRemoteHandlers() {
        Task { [weak self] in
            await HawkAudioEngine.shared.setRemoteCommandHandlers(
                onNext: { [weak self] in
                    Task { @MainActor [weak self] in
                        self?.next()
                    }
                },
                onPrevious: { [weak self] in
                    Task { @MainActor [weak self] in
                        self?.previous()
                    }
                }
            )
        }
    }

    private func setupTrackFinishedCallback() {
        Task { [weak self] in
            await HawkAudioEngine.shared.setOnTrackFinished { [weak self] in
                Task { @MainActor [weak self] in
                    self?.next(isAutoAdvance: true)
                }
            }
        }
    }

    private func startPolling() {
        pollTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                // High-fidelity 20Hz polling (50ms) for ultra-responsive scrubber and live lyrics tracking
                try? await Task.sleep(nanoseconds: 50_000_000)
                guard let self = self else { continue }
                let state = await HawkAudioEngine.shared.playbackState

                // Consistent atomic state: only sync playbackState if state song matches currentSong or coordinator is idle
                if let stateSong = state.currentSong {
                    if stateSong.id == self.currentSong?.id {
                        self.playbackState = state
                    }
                } else if self.currentSong == nil {
                    self.playbackState = state
                }

                if let err = state.errorMessage {
                    self.errorMessage = err
                }

                let time = await HawkAudioEngine.shared.currentTime()
                if !time.isNaN && time >= 0 {
                    self.currentTime = time
                }

                let dur = await HawkAudioEngine.shared.currentDuration()
                if !dur.isNaN && dur > 0 {
                    self.duration = dur
                }

                // Feed wall-clock listening sampler
                if let song = self.currentSong {
                    await ListeningStatsRecorder.shared.onSample(song: song, isPlaying: self.isPlaying)
                }
            }
        }
    }

    public func play(song: Song, context: [Song]? = nil, isAutoAdvance: Bool = false) {
        // Cancel any pending playback or source-resolution task (latest-request-wins)
        playbackTask?.cancel()
        navigationRequestId &+= 1
        let thisReqId = navigationRequestId

        self.currentSong = song
        self.playbackState = .loading(song)
        self.currentTime = 0.0
        self.duration = song.duration
        self.errorMessage = nil

        playbackTask = Task { [weak self] in
            guard let self = self else { return }

            if let context = context, !context.isEmpty {
                let startIndex = context.firstIndex(where: { $0.id == song.id }) ?? 0
                await QueueManager.shared.setContext(songs: context, startAt: startIndex)
            } else {
                let currentQueue = await QueueManager.shared.fullTimeline
                if let idx = currentQueue.firstIndex(where: { $0.id == song.id }) {
                    _ = await QueueManager.shared.jumpTo(index: idx)
                } else {
                    await QueueManager.shared.setContext(songs: [song], startAt: 0)
                }
            }

            guard !Task.isCancelled, thisReqId == self.navigationRequestId else { return }

            self.queue = await QueueManager.shared.fullTimeline
            self.repeatMode = await QueueManager.shared.repeatMode
            self.isShuffleActive = await QueueManager.shared.isShuffleActive

            // Check favorite status
            self.isFavorite = await PlaylistStore.shared.isFavorite(songId: song.id)

            do {
                try await HawkAudioEngine.shared.play(song: song, isAutoAdvance: isAutoAdvance)
            } catch {
                if !Task.isCancelled && thisReqId == self.navigationRequestId {
                    self.errorMessage = error.localizedDescription
                    self.playbackState = .failed(song, .playbackFailed(error.localizedDescription))
                }
            }
        }
    }

    public func togglePlayPause() {
        if isPlaying {
            Task {
                await HawkAudioEngine.shared.pause()
                self.playbackState = .paused(currentSong ?? Song(id: "", title: "", artist: ""))
            }
        } else {
            Task {
                await HawkAudioEngine.shared.resume()
                self.playbackState = .playing(currentSong ?? Song(id: "", title: "", artist: ""))
            }
        }
    }

    public func seek(to time: TimeInterval) {
        self.currentTime = time
        Task {
            await HawkAudioEngine.shared.seek(to: time)
        }
    }

    public func next(isAutoAdvance: Bool = false) {
        navigationRequestId &+= 1
        let thisReqId = navigationRequestId
        Task { @MainActor [weak self] in
            guard let self = self else { return }
            if let nextSong = await QueueManager.shared.next(isAutoAdvance: isAutoAdvance) {
                guard thisReqId == self.navigationRequestId else { return }
                self.play(song: nextSong, context: nil, isAutoAdvance: isAutoAdvance)
            } else {
                guard thisReqId == self.navigationRequestId else { return }
                self.playbackState = .idle
            }
        }
    }

    public func previous() {
        navigationRequestId &+= 1
        let thisReqId = navigationRequestId
        Task { @MainActor [weak self] in
            guard let self = self else { return }
            // If more than 3 seconds into song, standard behavior is to restart current track
            if self.currentTime > 3.0 {
                self.seek(to: 0.0)
                return
            }

            if let prevSong = await QueueManager.shared.previous() {
                guard thisReqId == self.navigationRequestId else { return }
                self.play(song: prevSong, context: nil)
            } else {
                guard thisReqId == self.navigationRequestId else { return }
                self.seek(to: 0.0)
            }
        }
    }

    public func toggleRepeat() {
        Task {
            await QueueManager.shared.toggleRepeat()
            self.repeatMode = await QueueManager.shared.repeatMode
        }
    }

    public func toggleShuffle() {
        Task {
            await QueueManager.shared.toggleShuffle()
            self.isShuffleActive = await QueueManager.shared.isShuffleActive
            self.queue = await QueueManager.shared.fullTimeline
        }
    }

    public func toggleFavorite() {
        guard let song = currentSong else { return }
        Task {
            let fav = await PlaylistStore.shared.toggleFavorite(song: song)
            self.isFavorite = fav
        }
    }

    public func playNext(song: Song) {
        Task {
            await QueueManager.shared.playNext(song: song)
            self.queue = await QueueManager.shared.fullTimeline
        }
    }

    public func addToQueue(song: Song) {
        Task {
            await QueueManager.shared.addToQueue(song: song)
            self.queue = await QueueManager.shared.fullTimeline
        }
    }

    public func removeFromQueue(entryId: UUID) {
        Task {
            await QueueManager.shared.removeTrack(entryId: entryId)
            self.queue = await QueueManager.shared.fullTimeline
        }
    }
}

import Foundation
import SwiftUI
import HawkCore
import HawkPlayback
import HawkSources

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

    public init() {
        startPolling()
        setupTrackFinishedCallback()
    }

    private func setupTrackFinishedCallback() {
        Task { [weak self] in
            await HawkAudioEngine.shared.setOnTrackFinished { [weak self] in
                Task { @MainActor [weak self] in
                    self?.next()
                }
            }
        }
    }

    private func startPolling() {
        pollTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 250_000_000)
                guard let self = self else { continue }
                let state = await HawkAudioEngine.shared.playbackState
                self.playbackState = state

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
            }
        }
    }

    public func play(song: Song, context: [Song]? = nil) {
        self.currentSong = song
        self.playbackState = .loading(song)
        self.currentTime = 0.0
        self.duration = song.duration
        self.errorMessage = nil

        Task {
            if let context = context, !context.isEmpty {
                let startIndex = context.firstIndex(where: { $0.id == song.id }) ?? 0
                await QueueManager.shared.setContext(songs: context, startAt: startIndex)
            } else {
                await QueueManager.shared.setContext(songs: [song], startAt: 0)
            }
            self.queue = await QueueManager.shared.fullTimeline

            // Check favorite status
            self.isFavorite = await PlaylistStore.shared.isFavorite(songId: song.id)

            do {
                try await HawkAudioEngine.shared.play(song: song)
            } catch {
                self.errorMessage = error.localizedDescription
                self.playbackState = .failed(song, .playbackFailed(error.localizedDescription))
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

    public func next() {
        Task {
            if let nextSong = await QueueManager.shared.next() {
                play(song: nextSong)
            } else {
                self.playbackState = .idle
            }
        }
    }

    public func previous() {
        Task {
            if let prevSong = await QueueManager.shared.previous() {
                play(song: prevSong)
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

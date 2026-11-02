import Foundation
import AVFoundation
import MediaPlayer
import HawkCore
import HawkSources

/// Primary native audio engine managing playback, dual-player crossfade, audio sessions, and lock screen controls.
public actor HawkAudioEngine {
    public static let shared = HawkAudioEngine()

    private var playerA: AVPlayer
    private var playerB: AVPlayer
    private var isUsingPlayerA = true

    public private(set) var playbackState: PlaybackState = .idle
    public private(set) var crossfadeDuration: TimeInterval = 4.0 // 0 to 12s
    public private(set) var playbackSpeed: Float = 1.0

    private var timeObserverToken: Any?
    private var endObserverToken: Any?
    private var stallObserverToken: Any?
    private var itemStatusObserver: NSKeyValueObservation?
    private var crossfadeTask: Task<Void, Never>?

    public var onTrackFinished: (@Sendable () async -> Void)?

    public func setOnTrackFinished(_ handler: @escaping @Sendable () async -> Void) {
        self.onTrackFinished = handler
    }

    public init() {
        self.playerA = AVPlayer()
        self.playerB = AVPlayer()
        self.playerA.automaticallyWaitsToMinimizeStalling = true
        self.playerB.automaticallyWaitsToMinimizeStalling = true
        setupAudioSession()
        setupRemoteCommands()
    }

    private var activePlayer: AVPlayer {
        isUsingPlayerA ? playerA : playerB
    }

    private var standbyPlayer: AVPlayer {
        isUsingPlayerA ? playerB : playerA
    }

    // MARK: - Playback Control
    public func play(song: Song) async throws {
        playbackState = .loading(song)

        do {
            let stream = try await SourceResolver.shared.resolve(song: song)
            let playerItem = AVPlayerItem(url: stream.url)

            setupItemObservers(for: playerItem, song: song)

            if crossfadeDuration > 0 && activePlayer.currentItem != nil && activePlayer.rate > 0 {
                // Initiate true dual-player crossfade
                await executeCrossfade(to: playerItem, song: song)
            } else {
                // Direct playback
                activePlayer.replaceCurrentItem(with: playerItem)
                activePlayer.volume = 1.0
                activePlayer.rate = playbackSpeed
                activePlayer.play()
                playbackState = .buffering(song)
            }
            observeItemEnd(item: playerItem)
        } catch let err as HawkError {
            playbackState = .failed(song, err)
            throw err
        } catch {
            let hawkErr = HawkError.playbackFailed(error.localizedDescription)
            playbackState = .failed(song, hawkErr)
            throw hawkErr
        }
    }

    private func setupItemObservers(for item: AVPlayerItem, song: Song) {
        itemStatusObserver?.invalidate()
        itemStatusObserver = item.observe(\.status, options: [.new, .initial]) { [weak self] observedItem, _ in
            Task { [weak self] in
                guard let self else { return }
                switch observedItem.status {
                case .readyToPlay:
                    await self.handleItemReady(song: song, item: observedItem)
                case .failed:
                    let errMsg = observedItem.error?.localizedDescription ?? "Audio playback stream failed"
                    await self.handleItemFailed(song: song, errorDescription: errMsg)
                case .unknown:
                    break
                @unknown default:
                    break
                }
            }
        }

        if let token = stallObserverToken {
            NotificationCenter.default.removeObserver(token)
        }
        stallObserverToken = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemPlaybackStalled,
            object: item,
            queue: .main
        ) { [weak self] _ in
            Task { [weak self] in
                await self?.handlePlaybackStalled(song: song)
            }
        }
    }

    private func handleItemReady(song: Song, item: AVPlayerItem) {
        if activePlayer.rate > 0 {
            playbackState = .playing(song)
        } else {
            playbackState = .ready(song)
        }
        updateNowPlaying(song: song)
    }

    private func handleItemFailed(song: Song, errorDescription: String) {
        playbackState = .failed(song, .playbackFailed(errorDescription))
    }

    private func handlePlaybackStalled(song: Song) {
        if case .playing = playbackState {
            playbackState = .buffering(song)
        }
    }

    private func observeItemEnd(item: AVPlayerItem) {
        if let token = endObserverToken {
            NotificationCenter.default.removeObserver(token)
        }
        endObserverToken = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] _ in
            Task { [weak self] in
                await self?.handleTrackEnded()
            }
        }
    }

    public func handleTrackEnded() async {
        if let song = playbackState.currentSong {
            playbackState = .ended(song)
        }
        if let onTrackFinished {
            await onTrackFinished()
        }
    }

    public func pause() {
        activePlayer.pause()
        if let song = playbackState.currentSong {
            playbackState = .paused(song)
            updateNowPlayingPlaybackRate(0.0)
        }
    }

    public func resume() {
        activePlayer.play()
        activePlayer.rate = playbackSpeed
        if let song = playbackState.currentSong {
            playbackState = .playing(song)
            updateNowPlayingPlaybackRate(Double(playbackSpeed))
        }
    }

    public func seek(to seconds: TimeInterval) {
        if let song = playbackState.currentSong {
            playbackState = .seeking(song, seconds)
        }
        let time = CMTime(seconds: seconds, preferredTimescale: 1000)
        activePlayer.seek(to: time) { [weak self] _ in
            Task { [weak self] in
                await self?.handleSeekFinished()
            }
        }
    }

    private func handleSeekFinished() {
        guard let song = playbackState.currentSong else { return }
        if activePlayer.rate > 0 {
            playbackState = .playing(song)
        } else {
            playbackState = .paused(song)
        }
        updateNowPlayingPlaybackRate(Double(activePlayer.rate))
    }

    public func setCrossfadeDuration(_ duration: TimeInterval) {
        self.crossfadeDuration = max(0, min(12.0, duration))
    }

    public func setPlaybackSpeed(_ speed: Float) {
        self.playbackSpeed = speed
        if activePlayer.rate > 0 {
            activePlayer.rate = speed
        }
    }

    public func currentTime() -> TimeInterval {
        let secs = activePlayer.currentTime().seconds
        return (secs.isNaN || secs < 0) ? 0 : secs
    }

    public func currentDuration() -> TimeInterval {
        if let item = activePlayer.currentItem,
           item.duration.isValid && !item.duration.isIndefinite {
            let secs = item.duration.seconds
            if !secs.isNaN && secs > 0 {
                return secs
            }
        }
        return playbackState.currentSong?.duration ?? 0
    }

    // MARK: - Dual Player Crossfade
    private func executeCrossfade(to nextItem: AVPlayerItem, song: Song) async {
        crossfadeTask?.cancel()

        let outgoing = activePlayer
        let incoming = standbyPlayer

        incoming.replaceCurrentItem(with: nextItem)
        incoming.volume = 0.0
        incoming.rate = playbackSpeed
        incoming.play()

        let steps = 20
        let stepInterval = crossfadeDuration / Double(steps)

        isUsingPlayerA.toggle()
        playbackState = .playing(song)
        updateNowPlaying(song: song)

        crossfadeTask = Task {
            for step in 0...steps {
                if Task.isCancelled { break }
                let progress = Double(step) / Double(steps)
                let gainOut = Float(cos(progress * .pi / 2.0))
                let gainIn = Float(sin(progress * .pi / 2.0))

                outgoing.volume = max(0.0, gainOut)
                incoming.volume = min(1.0, gainIn)

                try? await Task.sleep(nanoseconds: UInt64(stepInterval * 1_000_000_000))
            }
            outgoing.pause()
            outgoing.replaceCurrentItem(with: nil)
            incoming.volume = 1.0
        }
    }

    // MARK: - Audio Session & Interruptions
    nonisolated private func setupAudioSession() {
        #if os(iOS)
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.allowAirPlay, .allowBluetooth, .allowBluetoothA2DP])
            try session.setActive(true)

            NotificationCenter.default.addObserver(
                forName: AVAudioSession.interruptionNotification,
                object: nil,
                queue: .main
            ) { notification in
                let userInfo = notification.userInfo
                let typeValue = userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt
                let optionsValue = userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt
                Task {
                    if let typeValue {
                        await HawkAudioEngine.shared.handleInterruption(typeValue: typeValue, optionsValue: optionsValue)
                    }
                }
            }

            NotificationCenter.default.addObserver(
                forName: AVAudioSession.routeChangeNotification,
                object: nil,
                queue: .main
            ) { notification in
                let reasonValue = notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt
                Task {
                    if let reasonValue {
                        await HawkAudioEngine.shared.handleRouteChange(reasonValue: reasonValue)
                    }
                }
            }
        } catch {
            print("Failed to configure AVAudioSession: \(error)")
        }
        #endif
    }

    #if os(iOS)
    public func handleInterruption(typeValue: UInt, optionsValue: UInt?) {
        guard let type = AVAudioSession.InterruptionType(rawValue: typeValue) else { return }

        switch type {
        case .began:
            pause()
        case .ended:
            if let optionsValue {
                let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
                if options.contains(.shouldResume) {
                    resume()
                }
            }
        @unknown default:
            break
        }
    }

    public func handleRouteChange(reasonValue: UInt) {
        guard let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else { return }

        if reason == .oldDeviceUnavailable {
            pause()
        }
    }
    #endif

    // MARK: - Lock Screen & Control Center
    nonisolated private func setupRemoteCommands() {
        let center = MPRemoteCommandCenter.shared()

        center.playCommand.addTarget { _ in
            Task { await HawkAudioEngine.shared.resume() }
            return .success
        }

        center.pauseCommand.addTarget { _ in
            Task { await HawkAudioEngine.shared.pause() }
            return .success
        }

        center.togglePlayPauseCommand.addTarget { _ in
            Task {
                let state = await HawkAudioEngine.shared.playbackState
                if state.isPlaying {
                    await HawkAudioEngine.shared.pause()
                } else {
                    await HawkAudioEngine.shared.resume()
                }
            }
            return .success
        }

        center.nextTrackCommand.addTarget { _ in
            Task {
                if let nextSong = await QueueManager.shared.next() {
                    try? await HawkAudioEngine.shared.play(song: nextSong)
                }
            }
            return .success
        }

        center.previousTrackCommand.addTarget { _ in
            Task {
                if let prevSong = await QueueManager.shared.previous() {
                    try? await HawkAudioEngine.shared.play(song: prevSong)
                }
            }
            return .success
        }

        center.changePlaybackPositionCommand.addTarget { event in
            guard let posEvent = event as? MPChangePlaybackPositionCommandEvent else {
                return .commandFailed
            }
            let targetPosition = posEvent.positionTime
            Task { await HawkAudioEngine.shared.seek(to: targetPosition) }
            return .success
        }
    }

    private func updateNowPlaying(song: Song) {
        var info = [String: Any]()
        info[MPMediaItemPropertyTitle] = song.title
        info[MPMediaItemPropertyArtist] = song.artist
        if let album = song.albumTitle {
            info[MPMediaItemPropertyAlbumTitle] = album
        }
        info[MPMediaItemPropertyPlaybackDuration] = song.duration
        info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentTime()
        info[MPNowPlayingInfoPropertyPlaybackRate] = Double(playbackSpeed)

        MPNowPlayingInfoCenter.default().nowPlayingInfo = info

        #if canImport(UIKit)
        if let artworkURL = song.artworkURL {
            Task {
                if let (data, _) = try? await URLSession.shared.data(from: artworkURL),
                   let image = UIImage(data: data) {
                    var currentInfo = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [:]
                    let artwork = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
                    currentInfo[MPMediaItemPropertyArtwork] = artwork
                    MPNowPlayingInfoCenter.default().nowPlayingInfo = currentInfo
                }
            }
        }
        #endif
    }

    private func updateNowPlayingPlaybackRate(_ rate: Double) {
        var info = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [:]
        info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentTime()
        info[MPNowPlayingInfoPropertyPlaybackRate] = rate
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }
}

import SwiftUI
import AVFoundation
import AVKit
import MediaPlayer
import HawkCore
import HawkPlayback
import HawkLyrics

/// Full-screen modal player sheet with artwork, scrubber, transport controls, and lyrics toggle.
public struct NowPlayingView: View {
    public let song: Song
    public let isPlaying: Bool
    public let currentTime: TimeInterval
    public let duration: TimeInterval
    public let onPlayPause: () -> Void
    public let onNext: () -> Void
    public let onPrevious: () -> Void
    public let onSeek: (TimeInterval) -> Void
    public let onDismiss: () -> Void

    @State private var coordinator = PlaybackCoordinator.shared
    @State private var showLyrics = false
    @State private var showQueue = false
    @State private var isScrubbing = false
    @State private var scrubTime: TimeInterval = 0

    public init(
        song: Song,
        isPlaying: Bool,
        currentTime: TimeInterval,
        duration: TimeInterval,
        onPlayPause: @escaping () -> Void,
        onNext: @escaping () -> Void,
        onPrevious: @escaping () -> Void,
        onSeek: @escaping (TimeInterval) -> Void,
        onDismiss: @escaping () -> Void
    ) {
        self.song = song
        self.isPlaying = isPlaying
        self.currentTime = currentTime
        self.duration = duration > 0 ? duration : song.duration
        self.onPlayPause = onPlayPause
        self.onNext = onNext
        self.onPrevious = onPrevious
        self.onSeek = onSeek
        self.onDismiss = onDismiss
    }

    public var body: some View {
        ZStack {
            ArtworkMeshGradient()

            VStack(spacing: 20) {
                // Dismiss Grabber & Header
                HStack {
                    Button(action: onDismiss) {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(HawkTheme.textSecondary)
                            .padding(8)
                    }
                    .accessibilityLabel("Dismiss Now Playing")

                    Spacer()

                    VStack(spacing: 2) {
                        Text("PLAYING FROM HAWK")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(HawkTheme.textTertiary)
                            .tracking(1.2)
                        Text(song.albumTitle ?? song.artist)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(HawkTheme.textSecondary)
                            .lineLimit(1)
                    }

                    Spacer()

                    Menu {
                        Button {
                            coordinator.toggleFavorite()
                        } label: {
                            Label(coordinator.isFavorite ? "Remove from Favorites" : "Favorite Song",
                                  systemImage: coordinator.isFavorite ? "heart.slash" : "heart")
                        }

                        Button {
                            showQueue = true
                        } label: {
                            Label("View Queue", systemImage: "list.bullet")
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(HawkTheme.textSecondary)
                            .padding(8)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 14)

                Spacer()

                if showLyrics {
                    LyricsContainerView(song: song, currentTime: currentTime)
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                } else {
                    // Artwork Presentation
                    AsyncImage(url: song.artworkURL) { phase in
                        if let image = phase.image {
                            image.resizable().scaledToFill()
                        } else {
                            Rectangle().fill(HawkTheme.cardBackground)
                                .overlay(
                                    Image(systemName: "music.note")
                                        .font(.system(size: 80))
                                        .foregroundColor(.white.opacity(0.3))
                                )
                        }
                    }
                    .frame(width: 320, height: 320)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .shadow(color: .black.opacity(0.4), radius: 24, x: 0, y: 12)
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
                }

                Spacer()

                // Title & Artist & Like Button
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(song.title)
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(HawkTheme.textPrimary)
                            .lineLimit(1)

                        Text(song.artist)
                            .font(.system(size: 17, weight: .medium))
                            .foregroundColor(HawkTheme.textSecondary)
                            .lineLimit(1)
                    }

                    Spacer()

                    Button {
                        coordinator.toggleFavorite()
                    } label: {
                        Image(systemName: coordinator.isFavorite ? "heart.fill" : "heart")
                            .font(.system(size: 24))
                            .foregroundColor(coordinator.isFavorite ? HawkTheme.primaryAccent : HawkTheme.textSecondary)
                    }
                    .accessibilityLabel("Favorite")
                }
                .padding(.horizontal, 28)

                // Progress Bar & Scrubbing
                VStack(spacing: 8) {
                    Slider(
                        value: Binding(
                            get: { isScrubbing ? scrubTime : currentTime },
                            set: { newValue in
                                isScrubbing = true
                                scrubTime = newValue
                            }
                        ),
                        in: 0...max(duration, 1.0),
                        onEditingChanged: { editing in
                            if !editing {
                                onSeek(scrubTime)
                                isScrubbing = false
                            }
                        }
                    )
                    .accentColor(HawkTheme.primaryAccent)

                    HStack {
                        Text(Song.formatDuration(isScrubbing ? scrubTime : currentTime))
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                            .foregroundColor(HawkTheme.textTertiary)

                        Spacer()

                        Text("-\(Song.formatDuration(max(0, duration - (isScrubbing ? scrubTime : currentTime))))")
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                            .foregroundColor(HawkTheme.textTertiary)
                    }
                }
                .padding(.horizontal, 28)

                // Playback Transport Controls (Shuffle, Prev, Play/Pause, Next, Repeat)
                HStack(spacing: 28) {
                    Button {
                        coordinator.toggleShuffle()
                    } label: {
                        Image(systemName: "shuffle")
                            .font(.system(size: 20))
                            .foregroundColor(coordinator.isShuffleActive ? HawkTheme.primaryAccent : HawkTheme.textTertiary)
                    }
                    .accessibilityLabel("Shuffle")

                    Button(action: onPrevious) {
                        Image(systemName: "backward.fill")
                            .font(.system(size: 28))
                            .foregroundColor(HawkTheme.textPrimary)
                    }
                    .accessibilityLabel("Previous Track")

                    Button(action: onPlayPause) {
                        ZStack {
                            Circle()
                                .fill(HawkTheme.primaryAccent)
                                .frame(width: 72, height: 72)
                                .shadow(color: HawkTheme.primaryAccent.opacity(0.4), radius: 12, x: 0, y: 6)

                            Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                                .font(.system(size: 30))
                                .foregroundColor(.white)
                                .offset(x: isPlaying ? 0 : 2)
                        }
                    }
                    .accessibilityLabel(isPlaying ? "Pause" : "Play")

                    Button(action: onNext) {
                        Image(systemName: "forward.fill")
                            .font(.system(size: 28))
                            .foregroundColor(HawkTheme.textPrimary)
                    }
                    .accessibilityLabel("Next Track")

                    Button {
                        coordinator.toggleRepeat()
                    } label: {
                        Image(systemName: repeatIconName)
                            .font(.system(size: 20))
                            .foregroundColor(coordinator.repeatMode != .off ? HawkTheme.primaryAccent : HawkTheme.textTertiary)
                    }
                    .accessibilityLabel("Repeat")
                }
                .padding(.vertical, 6)

                // Bottom Quick Action Bar (Lyrics, AirPlay, Queue)
                HStack(spacing: 40) {
                    Button(action: { withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { showLyrics.toggle() } }) {
                        Image(systemName: showLyrics ? "quote.bubble.fill" : "quote.bubble")
                            .font(.system(size: 22))
                            .foregroundColor(showLyrics ? HawkTheme.primaryAccent : HawkTheme.textTertiary)
                    }
                    .accessibilityLabel("Toggle Lyrics")

                    AirPlayButton()
                        .frame(width: 24, height: 24)

                    Button(action: { showQueue.toggle() }) {
                        Image(systemName: "list.bullet")
                            .font(.system(size: 22))
                            .foregroundColor(HawkTheme.textTertiary)
                    }
                    .accessibilityLabel("Playback Queue")
                }
                .padding(.bottom, 24)
            }
        }
        .sheet(isPresented: $showQueue) {
            QueueSheetView()
        }
    }

    private var repeatIconName: String {
        switch coordinator.repeatMode {
        case .one: return "repeat.1"
        default: return "repeat"
        }
    }
}

#if os(iOS)
import UIKit

/// AirPlay route picker button.
struct AirPlayButton: UIViewRepresentable {
    func makeUIView(context: Context) -> AVRoutePickerView {
        let picker = AVRoutePickerView()
        picker.tintColor = UIColor(HawkTheme.textTertiary)
        picker.activeTintColor = UIColor(HawkTheme.primaryAccent)
        picker.prioritizesVideoDevices = false
        return picker
    }
    func updateUIView(_ uiView: AVRoutePickerView, context: Context) {}
}
#else
struct AirPlayButton: View {
    var body: some View {
        Image(systemName: "airplayaudio")
            .foregroundColor(HawkTheme.textTertiary)
    }
}
#endif

/// Embedded synchronized lyrics panel with auto-scroll and line highlighting.
struct LyricsContainerView: View {
    let song: Song
    let currentTime: TimeInterval
    @State private var lyrics: [LyricLine] = []
    @State private var isLoading = true

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    if isLoading {
                        VStack(spacing: 12) {
                            ProgressView()
                                .tint(HawkTheme.primaryAccent)
                            Text("Fetching synchronized lyrics...")
                                .font(.system(size: 15))
                                .foregroundColor(HawkTheme.textTertiary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 60)
                    } else if lyrics.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "quote.bubble")
                                .font(.system(size: 44))
                                .foregroundColor(HawkTheme.textTertiary)
                            Text("No synchronized lyrics found")
                                .font(.headline)
                                .foregroundColor(HawkTheme.textSecondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 60)
                    } else {
                        ForEach(lyrics) { line in
                            let isActive = currentActiveLineId == line.id
                            Text(line.text)
                                .font(.system(size: 24, weight: isActive ? .bold : .medium))
                                .foregroundColor(isActive ? HawkTheme.textPrimary : HawkTheme.textTertiary.opacity(0.4))
                                .scaleEffect(isActive ? 1.03 : 1.0, anchor: .leading)
                                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isActive)
                                .id(line.id)
                        }
                    }
                }
                .padding(.horizontal, 32)
                .padding(.vertical, 20)
            }
            .task {
                lyrics = (try? await LyricsEngine.shared.fetchLyrics(for: song)) ?? []
                isLoading = false
            }
            .onChange(of: currentActiveLineId) { _, newId in
                if let newId {
                    withAnimation {
                        proxy.scrollTo(newId, anchor: .center)
                    }
                }
            }
        }
    }

    private var currentActiveLineId: String? {
        lyrics.last(where: { currentTime >= $0.timestamp })?.id
    }
}

/// Queue sheet displaying real tracks from PlaybackCoordinator.
struct QueueSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var coordinator = PlaybackCoordinator.shared

    var body: some View {
        NavigationStack {
            ZStack {
                HawkTheme.darkBackground.ignoresSafeArea()

                if coordinator.queue.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "music.note.list")
                            .font(.system(size: 48))
                            .foregroundColor(HawkTheme.textTertiary)
                        Text("Queue is Empty")
                            .font(.headline)
                            .foregroundColor(HawkTheme.textSecondary)
                    }
                } else {
                    List {
                        ForEach(coordinator.queue) { song in
                            HStack(spacing: 12) {
                                if song.id == coordinator.currentSong?.id {
                                    Image(systemName: "speaker.wave.2.fill")
                                        .foregroundColor(HawkTheme.primaryAccent)
                                        .font(.caption)
                                }
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(song.title)
                                        .font(.system(size: 15, weight: .medium))
                                        .foregroundColor(HawkTheme.textPrimary)
                                        .lineLimit(1)
                                    Text(song.artist)
                                        .font(.system(size: 13))
                                        .foregroundColor(HawkTheme.textSecondary)
                                        .lineLimit(1)
                                }
                                Spacer()
                                Text(song.formattedDuration)
                                    .font(.system(size: 12, design: .monospaced))
                                    .foregroundColor(HawkTheme.textTertiary)
                            }
                            .padding(.vertical, 2)
                        }
                        .onDelete { indexSet in
                            for index in indexSet {
                                let song = coordinator.queue[index]
                                coordinator.removeFromQueue(entryId: song.queueEntryId)
                            }
                        }
                    }
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle("Playback Queue")
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

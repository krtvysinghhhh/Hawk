import SwiftUI
import AVFoundation
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

            VStack(spacing: 24) {
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
                        Button("View Artist", action: {})
                        Button("Equalizer", action: {})
                        Button("Share Track", action: {})
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(HawkTheme.textSecondary)
                            .padding(8)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)

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
                                .overlay(Image(systemName: "music.note").font(.system(size: 80)).foregroundColor(.white.opacity(0.3)))
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

                    Button(action: {}) {
                        Image(systemName: song.isLiked ? "heart.fill" : "heart")
                            .font(.system(size: 24))
                            .foregroundColor(song.isLiked ? HawkTheme.primaryAccent : HawkTheme.textSecondary)
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

                // Playback Transport Controls
                HStack(spacing: 40) {
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
                }
                .padding(.vertical, 8)

                // Bottom Quick Action Bar (Lyrics, AirPlay, Queue)
                HStack(spacing: 36) {
                    Button(action: { withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { showLyrics.toggle() } }) {
                        Image(systemName: showLyrics ? "quote.bubble.fill" : "quote.bubble")
                            .font(.system(size: 20))
                            .foregroundColor(showLyrics ? HawkTheme.primaryAccent : HawkTheme.textTertiary)
                    }
                    .accessibilityLabel("Toggle Lyrics")

                    AirPlayButton()
                        .frame(width: 24, height: 24)

                    Button(action: { showQueue.toggle() }) {
                        Image(systemName: "list.bullet")
                            .font(.system(size: 20))
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
}

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

/// Embedded synchronized lyrics panel.
struct LyricsContainerView: View {
    let song: Song
    let currentTime: TimeInterval
    @State private var lyrics: [LyricLine] = []

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    if lyrics.isEmpty {
                        Text("Searching for synchronized lyrics...")
                            .font(.system(size: 16))
                            .foregroundColor(HawkTheme.textTertiary)
                            .padding(.top, 40)
                    } else {
                        ForEach(lyrics) { line in
                            let isActive = currentTime >= line.timestamp
                            Text(line.text)
                                .font(.system(size: 24, weight: isActive ? .bold : .medium))
                                .foregroundColor(isActive ? HawkTheme.textPrimary : HawkTheme.textTertiary.opacity(0.4))
                                .blur(radius: isActive ? 0 : 0.4)
                                .scaleEffect(isActive ? 1.02 : 1.0, anchor: .leading)
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
            }
        }
    }
}

/// Queue sheet displaying 3-tier queue.
struct QueueSheetView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                HawkTheme.darkBackground.ignoresSafeArea()

                VStack {
                    List {
                        Section("Up Next") {
                            Text("User Queued Songs")
                                .foregroundColor(HawkTheme.textSecondary)
                        }
                        Section("Context (Album/Playlist)") {
                            Text("Contextual Songs")
                                .foregroundColor(HawkTheme.textSecondary)
                        }
                        Section("Autoplay") {
                            Text("Similar Tracks")
                                .foregroundColor(HawkTheme.textSecondary)
                        }
                    }
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle("Playback Queue")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

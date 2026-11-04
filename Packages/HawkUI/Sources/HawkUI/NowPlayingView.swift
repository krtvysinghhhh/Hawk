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
    @State private var dragOffset: CGFloat = 0

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
                    LyricsContainerView(
                        song: song,
                        currentTime: currentTime,
                        isPlaying: isPlaying,
                        onSeek: onSeek
                    )
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
                } else {
                    // Artwork Presentation with smooth spring crossfade
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
                    .id(song.id)
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
                    .animation(.spring(response: 0.45, dampingFraction: 0.8), value: song.id)
                    .frame(width: 320, height: 320)
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.12), lineWidth: 0.8)
                    )
                    .shadow(color: .black.opacity(0.45), radius: 28, x: 0, y: 14)
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

                        let rem = duration > 0 ? max(0, duration - (isScrubbing ? scrubTime : currentTime)) : 0
                        Text(duration > 0 ? "-\(Song.formatDuration(rem))" : "--:--")
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
                    .hawkPressEffect()
                    .accessibilityLabel("Shuffle")

                    Button(action: onPrevious) {
                        Image(systemName: "backward.fill")
                            .font(.system(size: 28))
                            .foregroundColor(HawkTheme.textPrimary)
                    }
                    .hawkPressEffect()
                    .accessibilityLabel("Previous Track")

                    Button(action: onPlayPause) {
                        ZStack {
                            Circle()
                                .fill(HawkTheme.primaryAccent)
                                .frame(width: 72, height: 72)
                                .shadow(color: HawkTheme.primaryAccent.opacity(0.4), radius: 12, x: 0, y: 6)

                            if coordinator.isBuffering {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(1.2)
                            } else {
                                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                                    .font(.system(size: 30))
                                    .foregroundColor(.white)
                                    .offset(x: isPlaying ? 0 : 2)
                                    .contentTransition(.symbolEffect(.replace))
                            }
                        }
                    }
                    .hawkPressEffect()
                    .accessibilityLabel(isPlaying ? "Pause" : "Play")

                    Button(action: onNext) {
                        Image(systemName: "forward.fill")
                            .font(.system(size: 28))
                            .foregroundColor(HawkTheme.textPrimary)
                    }
                    .hawkPressEffect()
                    .accessibilityLabel("Next Track")

                    Button {
                        coordinator.toggleRepeat()
                    } label: {
                        Image(systemName: repeatIconName)
                            .font(.system(size: 20))
                            .foregroundColor(coordinator.repeatMode != .off ? HawkTheme.primaryAccent : HawkTheme.textTertiary)
                    }
                    .hawkPressEffect()
                    .accessibilityLabel("Repeat")
                }
                .padding(.vertical, 6)

                // Bottom Quick Action Bar (Lyrics, AirPlay, Queue)
                HStack(spacing: 36) {
                    Button(action: { withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { showLyrics.toggle() } }) {
                        Image(systemName: showLyrics ? "quote.bubble.fill" : "quote.bubble")
                            .font(.system(size: 20))
                            .foregroundColor(showLyrics ? HawkTheme.primaryAccent : HawkTheme.textSecondary)
                    }
                    .hawkPressEffect()
                    .accessibilityLabel("Toggle Lyrics")

                    AirPlayButton()
                        .frame(width: 22, height: 22)

                    Button(action: { showQueue.toggle() }) {
                        Image(systemName: "list.bullet")
                            .font(.system(size: 20))
                            .foregroundColor(HawkTheme.textSecondary)
                    }
                    .hawkPressEffect()
                    .accessibilityLabel("Playback Queue")
                }
                .padding(.horizontal, 28)
                .padding(.vertical, 12)
                .hawkLiquidGlass(cornerRadius: 24, strokeOpacity: 0.16)
                .padding(.bottom, 20)
            }
        }
        .offset(y: max(0, dragOffset))
        .simultaneousGesture(
            DragGesture()
                .onChanged { value in
                    if value.translation.height > 0 {
                        dragOffset = value.translation.height
                    }
                }
                .onEnded { value in
                    if value.translation.height > 120 {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                            onDismiss()
                        }
                    } else {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                            dragOffset = 0
                        }
                    }
                }
        )
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

/// Embedded synchronized lyrics panel with tap-to-seek, auto-scroll, word-level highlight, and re-center controls.
struct LyricsContainerView: View {
    let song: Song
    let currentTime: TimeInterval
    let isPlaying: Bool
    let onSeek: (TimeInterval) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var lyrics: [LyricLine] = []
    @State private var isLoading = true
    @State private var isUserScrolling = false
    @State private var userScrollResetTask: Task<Void, Never>?

    private var isSynchronized: Bool {
        lyrics.contains(where: { $0.timestamp > 0.05 })
    }

    private var currentActiveLine: LyricLine? {
        guard isSynchronized else { return nil }
        // 120ms perceptual lead time for natural vocal synchronisation
        return lyrics.last(where: { (currentTime + 0.12) >= $0.timestamp })
    }

    private var currentActiveLineId: String? {
        currentActiveLine?.id
    }

    private var animation: Animation {
        reduceMotion ? .easeInOut(duration: 0.15) : .spring(response: 0.42, dampingFraction: 0.80)
    }

    var body: some View {
        ScrollViewReader { proxy in
            ZStack(alignment: .bottom) {
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 24) {
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
                                Text("Lyrics aren't available for this track.")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(HawkTheme.textSecondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.top, 60)
                        } else {
                            ForEach(lyrics) { line in
                                let isActive = isSynchronized && currentActiveLineId == line.id
                                let isPast = isSynchronized && (line.timestamp < (currentActiveLine?.timestamp ?? 0))
                                Button {
                                    if isSynchronized {
                                        onSeek(line.timestamp)
                                        withAnimation(animation) {
                                            isUserScrolling = false
                                            proxy.scrollTo(line.id, anchor: .center)
                                        }
                                    }
                                } label: {
                                    if line.isWordSynced && isActive {
                                        // Word-level highlight
                                        renderWordSyncedLine(line: line)
                                    } else {
                                        Text(line.text)
                                            .font(.system(size: isSynchronized ? 26 : 19, weight: isActive ? .bold : .medium, design: .rounded))
                                            .foregroundColor(
                                                isSynchronized
                                                    ? (isActive ? HawkTheme.textPrimary : (isPast ? HawkTheme.textSecondary : HawkTheme.textTertiary))
                                                    : HawkTheme.textSecondary
                                            )
                                            .multilineTextAlignment(.leading)
                                            .scaleEffect(isActive ? 1.04 : 1.0, anchor: .leading)
                                            .blur(radius: isSynchronized && !isActive ? 0.35 : 0)
                                            .animation(animation, value: isActive)
                                    }
                                }
                                .buttonStyle(.plain)
                                .id(line.id)
                            }
                        }
                    }
                    .padding(.horizontal, 32)
                    .padding(.vertical, 36)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .simultaneousGesture(
                    DragGesture().onChanged { _ in
                        handleUserScroll()
                    }
                )

                // "Sync to Audio" Re-center floating pill when user has manually scrolled away
                if isUserScrolling && isSynchronized && currentActiveLineId != nil {
                    Button {
                        withAnimation(animation) {
                            isUserScrolling = false
                            userScrollResetTask?.cancel()
                            if let activeId = currentActiveLineId {
                                proxy.scrollTo(activeId, anchor: .center)
                            }
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .font(.system(size: 13, weight: .bold))
                            Text("Sync to Audio")
                                .font(.system(size: 13, weight: .semibold))
                        }
                        .foregroundColor(HawkTheme.textPrimary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .hawkLiquidGlass(cornerRadius: 20, strokeOpacity: 0.25)
                        .shadow(color: .black.opacity(0.35), radius: 10, y: 4)
                    }
                    .hawkPressEffect()
                    .padding(.bottom, 12)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .task(id: song.id) {
                // Immediately flush previous track lyrics to prevent stale visual flashes
                lyrics = []
                isLoading = true
                isUserScrolling = false
                userScrollResetTask?.cancel()
                let fetched = (try? await LyricsEngine.shared.fetchLyrics(for: song)) ?? []
                if !Task.isCancelled {
                    lyrics = fetched
                    isLoading = false
                    if let initialActive = currentActiveLineId {
                        withAnimation(animation) {
                            proxy.scrollTo(initialActive, anchor: .center)
                        }
                    }
                }
            }
            .onChange(of: currentActiveLineId) { _, newId in
                if !isUserScrolling, let newId {
                    withAnimation(animation) {
                        proxy.scrollTo(newId, anchor: .center)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func renderWordSyncedLine(line: LyricLine) -> some View {
        HStack(spacing: 4) {
            ForEach(line.words) { word in
                let wordActive = (currentTime + 0.12) >= word.startTime && (currentTime + 0.12) <= word.endTime
                let wordPassed = (currentTime + 0.12) > word.endTime
                Text(word.text)
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundColor(
                        wordActive ? HawkTheme.textPrimary : (wordPassed ? HawkTheme.textSecondary : HawkTheme.textTertiary)
                    )
            }
        }
        .scaleEffect(1.04, anchor: .leading)
    }

    private func handleUserScroll() {
        if !isUserScrolling {
            withAnimation(.easeInOut(duration: 0.2)) {
                isUserScrolling = true
            }
        }
        userScrollResetTask?.cancel()
        userScrollResetTask = Task {
            // Auto-resume follower 4.5s after user ceases interaction
            try? await Task.sleep(nanoseconds: 4_500_000_000)
            guard !Task.isCancelled else { return }
            withAnimation(animation) {
                isUserScrolling = false
            }
        }
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

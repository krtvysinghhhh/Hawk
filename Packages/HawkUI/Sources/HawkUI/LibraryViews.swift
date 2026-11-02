import SwiftUI
import HawkCore
import HawkPlayback
import HawkSources
import HawkStats

// MARK: - Favorites View
public struct FavoritesView: View {
    @State private var favorites: Playlist = Playlist.favoritesPlaylist()
    @State private var isLoading = true

    public init() {}

    public var body: some View {
        ZStack {
            HawkTheme.darkBackground.ignoresSafeArea()
            if favorites.songs.isEmpty && !isLoading {
                VStack(spacing: 12) {
                    Image(systemName: "heart.slash")
                        .font(.system(size: 48))
                        .foregroundColor(HawkTheme.textTertiary)
                    Text("No Favorite Songs Yet")
                        .font(.headline)
                        .foregroundColor(HawkTheme.textSecondary)
                    Text("Tap the heart icon on any playing song to add it to your favorites.")
                        .font(.caption)
                        .foregroundColor(HawkTheme.textTertiary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
            } else {
                List {
                    ForEach(favorites.songs) { song in
                        SongRowView(song: song)
                    }
                    .onDelete { indexSet in
                        Task {
                            for index in indexSet {
                                let song = favorites.songs[index]
                                await PlaylistStore.shared.removeSong(from: Playlist.favoritesId, songId: song.id)
                            }
                            favorites = await PlaylistStore.shared.getFavorites()
                        }
                    }
                }
                .scrollContentBackground(.hidden)
            }
        }
        .navigationTitle("Favorites")
        .task {
            favorites = await PlaylistStore.shared.getFavorites()
            isLoading = false
        }
    }
}

// MARK: - Playlists View
public struct PlaylistsView: View {
    @State private var playlists: [Playlist] = []
    @State private var showCreateSheet = false
    @State private var newPlaylistTitle = ""

    public init() {}

    public var body: some View {
        ZStack {
            HawkTheme.darkBackground.ignoresSafeArea()
            List {
                ForEach(playlists) { playlist in
                    NavigationLink(destination: PlaylistDetailView(playlist: playlist)) {
                        HStack(spacing: 14) {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(HawkTheme.cardBackground)
                                .frame(width: 50, height: 50)
                                .overlay(
                                    Image(systemName: playlist.isFavorites ? "heart.fill" : "music.note.list")
                                        .foregroundColor(playlist.isFavorites ? .red : HawkTheme.primaryAccent)
                                )
                            VStack(alignment: .leading, spacing: 4) {
                                Text(playlist.title)
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(HawkTheme.textPrimary)
                                Text("\(playlist.songs.count) songs")
                                    .font(.system(size: 13))
                                    .foregroundColor(HawkTheme.textSecondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                .onDelete { indexSet in
                    Task {
                        for index in indexSet {
                            let p = playlists[index]
                            if !p.isFavorites {
                                await PlaylistStore.shared.deletePlaylist(id: p.id)
                            }
                        }
                        playlists = await PlaylistStore.shared.getAllPlaylists()
                    }
                }
            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("Playlists")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showCreateSheet = true
                } label: {
                    Image(systemName: "plus")
                        .foregroundColor(HawkTheme.primaryAccent)
                }
            }
        }
        .sheet(isPresented: $showCreateSheet) {
            NavigationStack {
                ZStack {
                    HawkTheme.darkBackground.ignoresSafeArea()
                    VStack(spacing: 24) {
                        TextField("Playlist Name", text: $newPlaylistTitle)
                            .padding()
                            .background(HawkTheme.cardBackground)
                            .cornerRadius(10)
                            .foregroundColor(HawkTheme.textPrimary)
                            .padding(.horizontal)
                        
                        Button {
                            guard !newPlaylistTitle.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                            Task {
                                _ = await PlaylistStore.shared.createPlaylist(title: newPlaylistTitle)
                                playlists = await PlaylistStore.shared.getAllPlaylists()
                                newPlaylistTitle = ""
                                showCreateSheet = false
                            }
                        } label: {
                            Text("Create Playlist")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .background(HawkTheme.primaryAccent)
                                .cornerRadius(12)
                        }
                        .padding(.horizontal)
                        
                        Spacer()
                    }
                    .padding(.top, 30)
                }
                .navigationTitle("New Playlist")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { showCreateSheet = false }
                            .foregroundColor(HawkTheme.textSecondary)
                    }
                }
            }
            .presentationDetents([.medium])
        }
        .task {
            playlists = await PlaylistStore.shared.getAllPlaylists()
        }
    }
}

// MARK: - Playlist Detail View
public struct PlaylistDetailView: View {
    public let playlist: Playlist

    public init(playlist: Playlist) {
        self.playlist = playlist
    }

    public var body: some View {
        ZStack {
            HawkTheme.darkBackground.ignoresSafeArea()
            if playlist.songs.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "music.note")
                        .font(.system(size: 44))
                        .foregroundColor(HawkTheme.textTertiary)
                    Text("Playlist is Empty")
                        .font(.headline)
                        .foregroundColor(HawkTheme.textSecondary)
                }
            } else {
                List(playlist.songs) { song in
                    SongRowView(song: song)
                }
                .scrollContentBackground(.hidden)
            }
        }
        .navigationTitle(playlist.title)
    }
}

// MARK: - Downloads View
public struct DownloadsView: View {
    @State private var downloadedSongs: [Song] = []
    @State private var totalSizeMB: Double = 0.0

    public init() {}

    public var body: some View {
        ZStack {
            HawkTheme.darkBackground.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(downloadedSongs.count) Offline Tracks")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(HawkTheme.textPrimary)
                        Text(String(format: "Storage Used: %.1f MB", totalSizeMB))
                            .font(.caption)
                            .foregroundColor(HawkTheme.textSecondary)
                    }
                    Spacer()
                    Image(systemName: "arrow.down.circle.fill")
                        .foregroundColor(HawkTheme.primaryAccent)
                        .font(.title2)
                }
                .padding()
                .background(HawkTheme.cardBackground)
                .cornerRadius(12)
                .padding(.horizontal)
                .padding(.vertical, 8)

                if downloadedSongs.isEmpty {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "arrow.down.circle")
                            .font(.system(size: 48))
                            .foregroundColor(HawkTheme.textTertiary)
                        Text("No Downloaded Music")
                            .font(.headline)
                            .foregroundColor(HawkTheme.textSecondary)
                        Text("Songs downloaded for offline listening will appear here.")
                            .font(.caption)
                            .foregroundColor(HawkTheme.textTertiary)
                    }
                    .frame(maxWidth: .infinity)
                    Spacer()
                } else {
                    List(downloadedSongs) { song in
                        SongRowView(song: song, showOfflineBadge: true)
                    }
                    .scrollContentBackground(.hidden)
                }
            }
        }
        .navigationTitle("Downloaded")
        .task {
            downloadedSongs = await DownloadManager.shared.getDownloadedSongs()
            let bytes = await DownloadManager.shared.totalDownloadedBytes()
            totalSizeMB = Double(bytes) / (1024 * 1024)
        }
    }
}

// MARK: - Settings View
public struct SettingsView: View {
    @State private var selectedQuality: AudioQuality = .high
    @State private var selectedPreset: EqualizerPreset = .flat

    public init() {}

    public var body: some View {
        ZStack {
            HawkTheme.darkBackground.ignoresSafeArea()
            Form {
                Section(header: Text("Streaming & Audio Quality").foregroundColor(HawkTheme.textSecondary)) {
                    Picker("Streaming Quality", selection: $selectedQuality) {
                        Text("Data Saver (96 kbps)").tag(AudioQuality.low)
                        Text("Standard (160 kbps)").tag(AudioQuality.standard)
                        Text("High (320 kbps AAC)").tag(AudioQuality.high)
                        Text("Lossless (FLAC)").tag(AudioQuality.lossless)
                    }
                    .pickerStyle(.menu)
                    .tint(HawkTheme.primaryAccent)
                }

                Section(header: Text("Equalizer").foregroundColor(HawkTheme.textSecondary)) {
                    Picker("Audio Preset", selection: $selectedPreset) {
                        Text("Flat").tag(EqualizerPreset.flat)
                        Text("Bass Booster").tag(EqualizerPreset.bassBooster)
                        Text("Vocal Booster").tag(EqualizerPreset.vocalBooster)
                        Text("Acoustic").tag(EqualizerPreset.acoustic)
                        Text("Electronic").tag(EqualizerPreset.electronic)
                        Text("Rock").tag(EqualizerPreset.rock)
                    }
                    .onChange(of: selectedPreset) { _, newPreset in
                        EqualizerManager.shared.applyPreset(newPreset)
                    }
                }

                Section(header: Text("About HAWK").foregroundColor(HawkTheme.textSecondary)) {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0 (Build 1)")
                            .foregroundColor(HawkTheme.textSecondary)
                    }
                    HStack {
                        Text("Engine")
                        Spacer()
                        Text("Native AVFoundation")
                            .foregroundColor(HawkTheme.textSecondary)
                    }
                    HStack {
                        Text("Architecture")
                        Spacer()
                        Text("Swift 6 Strict Concurrency")
                            .foregroundColor(HawkTheme.textSecondary)
                    }
                }
            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("Settings")
    }
}

// MARK: - Song Row Component
public struct SongRowView: View {
    public let song: Song
    public var showOfflineBadge: Bool = false

    public init(song: Song, showOfflineBadge: Bool = false) {
        self.song = song
        self.showOfflineBadge = showOfflineBadge
    }

    public var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 6)
                .fill(HawkTheme.cardBackground)
                .frame(width: 44, height: 44)
                .overlay(Image(systemName: "music.note").foregroundColor(.white.opacity(0.3)))

            VStack(alignment: .leading, spacing: 3) {
                Text(song.title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(HawkTheme.textPrimary)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    if showOfflineBadge {
                        Image(systemName: "arrow.down.circle.fill")
                            .font(.caption2)
                            .foregroundColor(HawkTheme.primaryAccent)
                    }
                    Text(song.artist)
                        .font(.system(size: 13))
                        .foregroundColor(HawkTheme.textSecondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            Text(song.formattedDuration)
                .font(.system(size: 13, design: .monospaced))
                .foregroundColor(HawkTheme.textTertiary)
        }
        .padding(.vertical, 2)
    }
}

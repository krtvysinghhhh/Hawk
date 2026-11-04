import SwiftUI
import UniformTypeIdentifiers
import HawkCore
import HawkPlayback
import HawkSources
import HawkStats

// MARK: - Favorites View
public struct FavoritesView: View {
    @State private var favorites: Playlist = Playlist.favoritesPlaylist()
    @State private var isLoading = true
    private var coordinator = PlaybackCoordinator.shared

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
                        Button {
                            coordinator.play(song: song, context: favorites.songs)
                        } label: {
                            SongRowView(song: song)
                        }
                        .buttonStyle(.plain)
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
        .navigationTitle("Liked Songs")
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
    @State private var showImportSheet = false
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
                                        .foregroundColor(playlist.isFavorites ? HawkTheme.primaryAccent : HawkTheme.textSecondary)
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
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button {
                        showCreateSheet = true
                    } label: {
                        Label("New Playlist", systemImage: "plus")
                    }

                    Button {
                        showImportSheet = true
                    } label: {
                        Label("Import Playlist (URL / File)", systemImage: "square.and.arrow.down")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundColor(HawkTheme.primaryAccent)
                }
            }
        }
        .sheet(isPresented: $showImportSheet, onDismiss: {
            Task { playlists = await PlaylistStore.shared.getAllPlaylists() }
        }) {
            PlaylistImportView()
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
#if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
#endif
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
    private var coordinator = PlaybackCoordinator.shared

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
                    Button {
                        coordinator.play(song: song, context: playlist.songs)
                    } label: {
                        SongRowView(song: song)
                    }
                    .buttonStyle(.plain)
                }
                .scrollContentBackground(.hidden)
            }
        }
        .navigationTitle(playlist.title)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                ShareLink(
                    item: UniversalPlaylistImporter.exportToM3U8(playlist: playlist),
                    preview: SharePreview(playlist.title, image: Image(systemName: "music.note.list"))
                ) {
                    Label("Export Playlist", systemImage: "square.and.arrow.up")
                        .foregroundColor(HawkTheme.primaryAccent)
                }
            }
        }
    }
}

// MARK: - Downloads View
public struct DownloadsView: View {
    @State private var downloadedSongs: [Song] = []
    @State private var totalSizeMB: Double = 0.0
    private var coordinator = PlaybackCoordinator.shared

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
                        Button {
                            coordinator.play(song: song, context: downloadedSongs)
                        } label: {
                            SongRowView(song: song, showOfflineBadge: true)
                        }
                        .buttonStyle(.plain)
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

// MARK: - Local Files View
public struct LocalFilesView: View {
    @State private var localTracks: [Song] = []
    @State private var showFilePicker = false
    @State private var isLoading = true
    private let localSource = LocalLibrarySource()
    private var coordinator = PlaybackCoordinator.shared

    public init() {}

    public var body: some View {
        ZStack {
            HawkTheme.darkBackground.ignoresSafeArea()
            if localTracks.isEmpty && !isLoading {
                VStack(spacing: 16) {
                    Image(systemName: "folder.badge.plus")
                        .font(.system(size: 48))
                        .foregroundColor(HawkTheme.textTertiary)
                    Text("No Local Audio Files")
                        .font(.headline)
                        .foregroundColor(HawkTheme.textSecondary)
                    Text("Import MP3, FLAC, or M4A audio files from your Files app or iCloud Drive.")
                        .font(.caption)
                        .foregroundColor(HawkTheme.textTertiary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)

                    Button {
                        showFilePicker = true
                    } label: {
                        Label("Import Audio Files", systemImage: "square.and.arrow.down")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                            .background(HawkTheme.primaryAccent)
                            .cornerRadius(10)
                    }
                }
            } else {
                List {
                    ForEach(localTracks) { song in
                        Button {
                            coordinator.play(song: song, context: localTracks)
                        } label: {
                            SongRowView(song: song)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .scrollContentBackground(.hidden)
            }
        }
        .navigationTitle("Local Files")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showFilePicker = true
                } label: {
                    Image(systemName: "plus")
                        .foregroundColor(HawkTheme.primaryAccent)
                }
            }
        }
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: [.audio],
            allowsMultipleSelection: true
        ) { result in
            switch result {
            case .success(let urls):
                let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
                let localDir = docs.appendingPathComponent("LocalMusic", isDirectory: true)
                try? FileManager.default.createDirectory(at: localDir, withIntermediateDirectories: true)

                for url in urls {
                    guard url.startAccessingSecurityScopedResource() else { continue }
                    defer { url.stopAccessingSecurityScopedResource() }
                    let dest = localDir.appendingPathComponent(url.lastPathComponent)
                    try? FileManager.default.removeItem(at: dest)
                    try? FileManager.default.copyItem(at: url, to: dest)
                }
                Task {
                    localTracks = await localSource.scanLocalTracks()
                }
            case .failure(let error):
                print("Failed to import files: \(error)")
            }
        }
        .task {
            localTracks = await localSource.scanLocalTracks()
            isLoading = false
        }
    }
}

// MARK: - Settings View
public struct SettingsView: View {
    @AppStorage("hawk_appearance_mode") private var appearanceModeRaw: String = AppearanceMode.system.rawValue
    @State private var selectedQuality: AudioQuality = .high
    @State private var eqEnabled: Bool = EqualizerManager.shared.isEnabled
    @State private var selectedPreset: EqualizerPreset = EqualizerManager.shared.currentPreset
    @State private var customGains: [Float] = EqualizerManager.shared.customGains
    @State private var crossfadeDuration: Double = 4.0
    @State private var gaplessEnabled: Bool = true
    @State private var lyricsOffset: Double = 0.0
    @State private var cacheSizeMB: Double = 0.0
    @State private var downloadSizeMB: Double = 0.0
    @State private var showCacheClearedAlert = false
    @State private var showResetEQAlert = false
    @State private var showExportAlert = false
    @State private var exportMessage = ""

    public init() {}

    public var body: some View {
        ZStack {
            HawkTheme.darkBackground.ignoresSafeArea()
            Form {
                // MARK: 1. Appearance & Theme
                Section(header: Text("Appearance").foregroundColor(HawkTheme.textSecondary)) {
                    Picker(selection: $appearanceModeRaw) {
                        ForEach(AppearanceMode.allCases) { mode in
                            Text(mode.rawValue).tag(mode.rawValue)
                        }
                    } label: {
                        Label("Appearance", systemImage: "circle.righthalf.filled")
                    }
                    .pickerStyle(.menu)
                    .tint(HawkTheme.primaryAccent)

                    HStack {
                        Label("Accent Color", systemImage: "circle.fill")
                            .foregroundColor(HawkTheme.primaryAccent)
                        Spacer()
                        Text("Muted Violet (#7867A8)")
                            .foregroundColor(HawkTheme.textSecondary)
                    }
                }

                // MARK: 2. Integrations
                Section(header: Text("Integrations").foregroundColor(HawkTheme.textSecondary)) {
                    NavigationLink(destination: GoogleYouTubeMusicSettingsView()) {
                        HStack {
                            Label("Google / YouTube Music", systemImage: "g.circle.fill")
                                .foregroundColor(HawkTheme.textPrimary)
                            Spacer()
                            if GoogleMusicSyncManager.shared.isConnected {
                                Text("Connected")
                                    .font(.caption)
                                    .foregroundColor(.green)
                            } else {
                                Text("Not Connected")
                                    .font(.caption)
                                    .foregroundColor(HawkTheme.textSecondary)
                            }
                        }
                    }
                }

                // MARK: 3. Playback
                Section(header: Text("Playback").foregroundColor(HawkTheme.textSecondary)) {
                    Picker(selection: $selectedQuality) {
                        Text("Data Saver (96 kbps)").tag(AudioQuality.low)
                        Text("Standard (160 kbps)").tag(AudioQuality.standard)
                        Text("High (320 kbps AAC)").tag(AudioQuality.high)
                        Text("Lossless (FLAC/ALAC)").tag(AudioQuality.lossless)
                    } label: {
                        Label("Streaming Quality", systemImage: "waveform.badge.magnifyingglass")
                    }
                    .pickerStyle(.menu)
                    .tint(HawkTheme.primaryAccent)

                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Label("Crossfade", systemImage: "arrow.triangle.swap")
                            Spacer()
                            Text(String(format: "%.1f s", crossfadeDuration))
                                .foregroundColor(HawkTheme.textSecondary)
                        }
                        Slider(value: $crossfadeDuration, in: 0...12, step: 0.5) {
                            Text("Crossfade Duration")
                        }
                        .tint(HawkTheme.primaryAccent)
                        .onChange(of: crossfadeDuration) { _, val in
                            Task {
                                await HawkAudioEngine.shared.setCrossfadeDuration(val)
                            }
                        }
                    }

                    Toggle(isOn: $gaplessEnabled) {
                        Label("Gapless Transitions", systemImage: "arrow.right.to.line")
                    }
                    .tint(HawkTheme.primaryAccent)
                }

                // MARK: 3. Audio Equalizer
                Section(header: Text("Audio Equalizer").foregroundColor(HawkTheme.textSecondary)) {
                    Toggle(isOn: $eqEnabled) {
                        Label("Enable Equalizer", systemImage: "slider.horizontal.3")
                    }
                    .tint(HawkTheme.primaryAccent)
                    .onChange(of: eqEnabled) { _, enabled in
                        EqualizerManager.shared.isEnabled = enabled
                    }

                    if eqEnabled {
                        Picker("Audio Preset", selection: $selectedPreset) {
                            ForEach(EqualizerPreset.allPresets) { preset in
                                Text(preset.name).tag(preset)
                            }
                        }
                        .onChange(of: selectedPreset) { _, newPreset in
                            EqualizerManager.shared.applyPreset(newPreset)
                            customGains = EqualizerManager.shared.customGains
                        }

                        // 10 Frequency Band Gain Sliders
                        ForEach(0..<10, id: \.self) { idx in
                            VStack(alignment: .leading, spacing: 2) {
                                HStack {
                                    Text(frequencyLabel(for: idx))
                                        .font(.caption.monospaced())
                                        .foregroundColor(HawkTheme.textSecondary)
                                    Spacer()
                                    Text(String(format: "%+.1f dB", customGains[idx]))
                                        .font(.caption.monospaced())
                                        .foregroundColor(customGains[idx] != 0 ? HawkTheme.primaryAccent : HawkTheme.textTertiary)
                                }
                                Slider(
                                    value: Binding(
                                        get: { customGains[idx] },
                                        set: { val in
                                            customGains[idx] = val
                                            EqualizerManager.shared.setBandGain(index: idx, gain: val)
                                        }
                                    ),
                                    in: -12...12,
                                    step: 0.5
                                )
                                .tint(HawkTheme.primaryAccent)
                            }
                        }

                        Button("Reset to Flat") {
                            EqualizerManager.shared.reset()
                            selectedPreset = .flat
                            customGains = EqualizerManager.shared.customGains
                        }
                        .foregroundColor(HawkTheme.primaryAccent)
                    }
                }

                // MARK: 4. Lyrics
                Section(header: Text("Lyrics").foregroundColor(HawkTheme.textSecondary)) {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Label("Sync Offset", systemImage: "clock.badge.checkmark")
                            Spacer()
                            Text(String(format: "%+.0f ms", lyricsOffset))
                                .foregroundColor(HawkTheme.textSecondary)
                        }
                        Slider(value: $lyricsOffset, in: -500...500, step: 25)
                            .tint(HawkTheme.primaryAccent)
                    }
                }

                // MARK: 5. Downloads
                Section(header: Text("Downloads").foregroundColor(HawkTheme.textSecondary)) {
                    HStack {
                        Label("Storage Used", systemImage: "internaldrive.fill")
                        Spacer()
                        Text(String(format: "%.1f MB", downloadSizeMB))
                            .foregroundColor(HawkTheme.textSecondary)
                    }
                    Button("Clear All Downloads", role: .destructive) {
                        Task {
                            await DownloadManager.shared.clearAllDownloads()
                            updateSizes()
                        }
                    }
                }

                // MARK: 6. Library & Playlists
                Section(header: Text("Library & Playlists").foregroundColor(HawkTheme.textSecondary)) {
                    Button {
                        Task {
                            let playlists = await PlaylistStore.shared.getAllPlaylists()
                            if let first = playlists.first {
                                let m3u = UniversalPlaylistImporter.exportToM3U8(playlist: first)
                                exportMessage = "Exported '\(first.title)' with \(first.songs.count) tracks in M3U8 format (\(m3u.count) bytes)."
                                showExportAlert = true
                            } else {
                                exportMessage = "No custom playlists found to export."
                                showExportAlert = true
                            }
                        }
                    } label: {
                        Label("Export Playlists (M3U8)", systemImage: "square.and.arrow.up")
                    }
                    .foregroundColor(HawkTheme.primaryAccent)
                }

                // MARK: 7. Storage & Cache
                Section(header: Text("Storage & Cache").foregroundColor(HawkTheme.textSecondary)) {
                    HStack {
                        Label("Network Cache", systemImage: "arrow.triangle.2.circlepath")
                        Spacer()
                        Text(String(format: "%.1f MB", cacheSizeMB))
                            .foregroundColor(HawkTheme.textSecondary)
                    }

                    Button("Clear Network Cache") {
                        URLCache.shared.removeAllCachedResponses()
                        Task {
                            await SourceResolver.shared.clearCache()
                            updateSizes()
                            showCacheClearedAlert = true
                        }
                    }
                    .foregroundColor(HawkTheme.primaryAccent)
                }

                // MARK: 8. About HAWK
                Section(header: Text("About HAWK").foregroundColor(HawkTheme.textSecondary)) {
                    HStack(spacing: 14) {
                        Image("hawk-logo", bundle: .main)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 48, height: 48)
                            .cornerRadius(10)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("HAWK")
                                .font(.headline)
                                .foregroundColor(HawkTheme.textPrimary)
                            Text("Native iOS Music Player")
                                .font(.caption)
                                .foregroundColor(HawkTheme.textSecondary)
                        }
                    }
                    .padding(.vertical, 4)

                    HStack {
                        Text("Developer")
                        Spacer()
                        Text("Kartavya Singh")
                            .foregroundColor(HawkTheme.textSecondary)
                    }

                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.3.1 (Build 4)")
                            .foregroundColor(HawkTheme.textSecondary)
                    }

                    HStack {
                        Text("Repository")
                        Spacer()
                        Link("github.com/krtvysinghhhh/Hawk", destination: URL(string: "https://github.com/krtvysinghhhh/Hawk")!)
                            .font(.subheadline)
                            .foregroundColor(HawkTheme.primaryAccent)
                    }

                    HStack {
                        Text("Audio Subsystem")
                        Spacer()
                        Text("AVFoundation + 10-Band Biquad DSP")
                            .foregroundColor(HawkTheme.textSecondary)
                    }

                    HStack {
                        Text("CarPlay Integration")
                        Spacer()
                        Text("Apple CarPlay Audio Template")
                            .foregroundColor(HawkTheme.textSecondary)
                    }

                    HStack {
                        Text("License")
                        Spacer()
                        Text("GPLv3 / Independent")
                            .foregroundColor(HawkTheme.textSecondary)
                    }
                }
            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("Settings")
        .alert("Cache Cleared", isPresented: $showCacheClearedAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Temporary audio and network caches have been cleared.")
        }
        .alert("Playlist Export", isPresented: $showExportAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(exportMessage)
        }
        .task {
            updateSizes()
            let cross = await HawkAudioEngine.shared.crossfadeDuration
            crossfadeDuration = cross
        }
    }

    private func updateSizes() {
        let currentBytes = URLCache.shared.currentDiskUsage
        cacheSizeMB = Double(currentBytes) / (1024 * 1024)
        Task {
            let dlBytes = await DownloadManager.shared.totalDownloadedBytes()
            downloadSizeMB = Double(dlBytes) / (1024 * 1024)
        }
    }

    private func frequencyLabel(for index: Int) -> String {
        let freqs = ["32 Hz", "64 Hz", "125 Hz", "250 Hz", "500 Hz", "1 kHz", "2 kHz", "4 kHz", "8 kHz", "16 kHz"]
        guard index >= 0 && index < freqs.count else { return "" }
        return freqs[index]
    }
}

// MARK: - Song Row Component with Live Artwork
public struct SongRowView: View {
    public let song: Song
    public var showOfflineBadge: Bool = false

    public init(song: Song, showOfflineBadge: Bool = false) {
        self.song = song
        self.showOfflineBadge = showOfflineBadge
    }

    public var body: some View {
        HStack(spacing: 12) {
            if let artworkURL = song.artworkURL {
                AsyncImage(url: artworkURL) { phase in
                    if let image = phase.image {
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } else {
                        rowPlaceholder
                    }
                }
                .frame(width: 46, height: 46)
                .cornerRadius(8)
                .clipped()
            } else {
                rowPlaceholder
            }

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

    private var rowPlaceholder: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(HawkTheme.cardBackground)
            .frame(width: 46, height: 46)
            .overlay(
                Image(systemName: "music.note")
                    .font(.system(size: 18))
                    .foregroundColor(.white.opacity(0.3))
            )
    }
}

// MARK: - Library Aggregator Service
public actor LibraryAggregator {
    public static let shared = LibraryAggregator()

    public func allLibrarySongs() async -> [Song] {
        var collected: [Song] = []
        let favs = await PlaylistStore.shared.getFavorites().songs
        collected.append(contentsOf: favs)
        for p in await PlaylistStore.shared.getAllPlaylists() {
            collected.append(contentsOf: p.songs)
        }
        let downloads = await DownloadManager.shared.getDownloadedSongs()
        collected.append(contentsOf: downloads)
        let locals = await LocalLibrarySource().scanLocalTracks()
        collected.append(contentsOf: locals)
        return TrackDeduplicator.deduplicate(collected)
    }
}

// MARK: - All Songs View
public struct AllSongsView: View {
    @State private var songs: [Song] = []
    @State private var searchText: String = ""
    @State private var isLoading = true
    private var coordinator = PlaybackCoordinator.shared

    public init() {}

    private var filteredSongs: [Song] {
        if searchText.trimmingCharacters(in: .whitespaces).isEmpty {
            return songs
        }
        return songs.filter {
            $0.title.localizedCaseInsensitiveContains(searchText) ||
            $0.artist.localizedCaseInsensitiveContains(searchText)
        }
    }

    public var body: some View {
        ZStack {
            HawkTheme.darkBackground.ignoresSafeArea()
            if songs.isEmpty && !isLoading {
                VStack(spacing: 12) {
                    Image(systemName: "music.note")
                        .font(.system(size: 48))
                        .foregroundColor(HawkTheme.textTertiary)
                    Text("No Songs in Library")
                        .font(.headline)
                        .foregroundColor(HawkTheme.textSecondary)
                    Text("Favorite tracks or add songs to playlists to see them here.")
                        .font(.caption)
                        .foregroundColor(HawkTheme.textTertiary)
                }
            } else {
                List {
                    if !songs.isEmpty {
                        HStack(spacing: 16) {
                            Button {
                                if let first = filteredSongs.first {
                                    coordinator.play(song: first, context: filteredSongs)
                                }
                            } label: {
                                HStack {
                                    Image(systemName: "play.fill")
                                    Text("Play All")
                                }
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(HawkTheme.primaryAccent)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(HawkTheme.cardBackground)
                                .cornerRadius(10)
                            }

                            Button {
                                if !filteredSongs.isEmpty {
                                    let shuffled = filteredSongs.shuffled()
                                    if let first = shuffled.first {
                                        coordinator.play(song: first, context: shuffled)
                                    }
                                }
                            } label: {
                                HStack {
                                    Image(systemName: "shuffle")
                                    Text("Shuffle")
                                }
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(HawkTheme.primaryAccent)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(HawkTheme.cardBackground)
                                .cornerRadius(10)
                            }
                        }
                        .listRowBackground(Color.clear)
                        .padding(.vertical, 4)
                    }

                    ForEach(filteredSongs) { song in
                        Button {
                            coordinator.play(song: song, context: filteredSongs)
                        } label: {
                            SongRowView(song: song)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .scrollContentBackground(.hidden)
            }
        }
        .navigationTitle("Songs")
        .searchable(text: $searchText, prompt: "Search Songs")
        .task {
            songs = await LibraryAggregator.shared.allLibrarySongs().sorted { $0.title < $1.title }
            isLoading = false
        }
    }
}

// MARK: - Artists View
public struct ArtistsView: View {
    @State private var artists: [(name: String, count: Int)] = []
    @State private var isLoading = true

    public init() {}

    public var body: some View {
        ZStack {
            HawkTheme.darkBackground.ignoresSafeArea()
            if artists.isEmpty && !isLoading {
                VStack(spacing: 12) {
                    Image(systemName: "music.mic")
                        .font(.system(size: 48))
                        .foregroundColor(HawkTheme.textTertiary)
                    Text("No Artists in Library")
                        .font(.headline)
                        .foregroundColor(HawkTheme.textSecondary)
                }
            } else {
                List(artists, id: \.name) { artist in
                    NavigationLink(destination: ArtistDetailView(artistName: artist.name)) {
                        HStack(spacing: 14) {
                            ZStack {
                                Circle()
                                    .fill(HawkTheme.cardBackground)
                                    .frame(width: 44, height: 44)
                                Image(systemName: "person.fill")
                                    .foregroundColor(HawkTheme.textSecondary)
                            }
                            VStack(alignment: .leading, spacing: 3) {
                                Text(artist.name)
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(HawkTheme.textPrimary)
                                Text("\(artist.count) tracks")
                                    .font(.system(size: 13))
                                    .foregroundColor(HawkTheme.textSecondary)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
                .scrollContentBackground(.hidden)
            }
        }
        .navigationTitle("Artists")
        .task {
            let all = await LibraryAggregator.shared.allLibrarySongs()
            var counts: [String: Int] = [:]
            for s in all {
                let name = s.artist.trimmingCharacters(in: .whitespaces)
                if !name.isEmpty {
                    counts[name, default: 0] += 1
                }
            }
            artists = counts.map { (name: $0.key, count: $0.value) }.sorted { $0.name < $1.name }
            isLoading = false
        }
    }
}

// MARK: - Artist Detail View
public struct ArtistDetailView: View {
    public let artistName: String
    @State private var songs: [Song] = []
    private var coordinator = PlaybackCoordinator.shared

    public init(artistName: String) {
        self.artistName = artistName
    }

    public var body: some View {
        ZStack {
            HawkTheme.darkBackground.ignoresSafeArea()
            List {
                ForEach(songs) { song in
                    Button {
                        coordinator.play(song: song, context: songs)
                    } label: {
                        SongRowView(song: song)
                    }
                    .buttonStyle(.plain)
                }
            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle(artistName)
        .task {
            let all = await LibraryAggregator.shared.allLibrarySongs()
            songs = all.filter { $0.artist.localizedCaseInsensitiveContains(artistName) }
        }
    }
}

// MARK: - Albums View
public struct AlbumsView: View {
    public struct AlbumItem: Identifiable {
        public var id: String { title }
        public let title: String
        public let artist: String
        public let artworkURL: URL?
        public let tracks: [Song]
    }

    @State private var albums: [AlbumItem] = []
    @State private var isLoading = true

    public init() {}

    public var body: some View {
        ZStack {
            HawkTheme.darkBackground.ignoresSafeArea()
            if albums.isEmpty && !isLoading {
                VStack(spacing: 12) {
                    Image(systemName: "square.stack")
                        .font(.system(size: 48))
                        .foregroundColor(HawkTheme.textTertiary)
                    Text("No Albums in Library")
                        .font(.headline)
                        .foregroundColor(HawkTheme.textSecondary)
                }
            } else {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)], spacing: 20) {
                        ForEach(albums) { album in
                            NavigationLink(destination: AlbumDetailView(album: album)) {
                                VStack(alignment: .leading, spacing: 8) {
                                    AsyncImage(url: album.artworkURL) { phase in
                                        if let img = phase.image {
                                            img.resizable().aspectRatio(contentMode: .fill)
                                        } else {
                                            RoundedRectangle(cornerRadius: 12)
                                                .fill(HawkTheme.cardBackground)
                                                .overlay(
                                                    Image(systemName: "square.stack")
                                                        .foregroundColor(HawkTheme.textTertiary)
                                                )
                                        }
                                    }
                                    .frame(height: 160)
                                    .cornerRadius(12)
                                    .clipped()

                                    Text(album.title)
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(HawkTheme.textPrimary)
                                        .lineLimit(1)
                                    Text(album.artist)
                                        .font(.system(size: 12))
                                        .foregroundColor(HawkTheme.textSecondary)
                                        .lineLimit(1)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(20)
                }
            }
        }
        .navigationTitle("Albums")
        .task {
            let all = await LibraryAggregator.shared.allLibrarySongs()
            var grouped: [String: [Song]] = [:]
            for s in all {
                let key = s.albumTitle ?? s.title
                grouped[key, default: []].append(s)
            }
            albums = grouped.map { title, tracks in
                AlbumItem(
                    title: title,
                    artist: tracks.first?.artist ?? "Various Artists",
                    artworkURL: tracks.first?.artworkURL,
                    tracks: tracks
                )
            }.sorted { $0.title < $1.title }
            isLoading = false
        }
    }
}

// MARK: - Album Detail View
public struct AlbumDetailView: View {
    public let album: AlbumsView.AlbumItem
    private var coordinator = PlaybackCoordinator.shared

    public init(album: AlbumsView.AlbumItem) {
        self.album = album
    }

    public var body: some View {
        ZStack {
            HawkTheme.darkBackground.ignoresSafeArea()
            List {
                Section {
                    ForEach(album.tracks) { song in
                        Button {
                            coordinator.play(song: song, context: album.tracks)
                        } label: {
                            SongRowView(song: song)
                        }
                        .buttonStyle(.plain)
                    }
                } header: {
                    HStack(spacing: 16) {
                        AsyncImage(url: album.artworkURL) { phase in
                            if let img = phase.image {
                                img.resizable().aspectRatio(contentMode: .fill)
                            } else {
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(HawkTheme.cardBackground)
                            }
                        }
                        .frame(width: 80, height: 80)
                        .cornerRadius(10)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(album.title)
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(HawkTheme.textPrimary)
                            Text(album.artist)
                                .font(.system(size: 14))
                                .foregroundColor(HawkTheme.textSecondary)
                            Text("\(album.tracks.count) tracks")
                                .font(.caption)
                                .foregroundColor(HawkTheme.textTertiary)
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle(album.title)
    }
}

// MARK: - Recently Added View
public struct RecentlyAddedView: View {
    @State private var recentSongs: [Song] = []
    private var coordinator = PlaybackCoordinator.shared

    public init() {}

    public var body: some View {
        ZStack {
            HawkTheme.darkBackground.ignoresSafeArea()
            if recentSongs.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "clock")
                        .font(.system(size: 48))
                        .foregroundColor(HawkTheme.textTertiary)
                    Text("No Recently Added Songs")
                        .font(.headline)
                        .foregroundColor(HawkTheme.textSecondary)
                }
            } else {
                List(recentSongs) { song in
                    Button {
                        coordinator.play(song: song, context: recentSongs)
                    } label: {
                        SongRowView(song: song)
                    }
                    .buttonStyle(.plain)
                }
                .scrollContentBackground(.hidden)
            }
        }
        .navigationTitle("Recently Added")
        .task {
            let all = await LibraryAggregator.shared.allLibrarySongs()
            recentSongs = all.sorted { ($0.dateAdded ?? .distantPast) > ($1.dateAdded ?? .distantPast) }
        }
    }
}

// MARK: - Recently Played View
public struct RecentlyPlayedView: View {
    @State private var recentPlayedSongs: [Song] = []
    private var coordinator = PlaybackCoordinator.shared

    public init() {}

    public var body: some View {
        ZStack {
            HawkTheme.darkBackground.ignoresSafeArea()
            if recentPlayedSongs.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 48))
                        .foregroundColor(HawkTheme.textTertiary)
                    Text("No Listening History Yet")
                        .font(.headline)
                        .foregroundColor(HawkTheme.textSecondary)
                    Text("Songs you play will automatically appear here based on genuine playback time.")
                        .font(.caption)
                        .foregroundColor(HawkTheme.textTertiary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
            } else {
                List(recentPlayedSongs) { song in
                    Button {
                        coordinator.play(song: song, context: recentPlayedSongs)
                    } label: {
                        SongRowView(song: song)
                    }
                    .buttonStyle(.plain)
                }
                .scrollContentBackground(.hidden)
            }
        }
        .navigationTitle("Recently Played")
        .task {
            recentPlayedSongs = await ListeningStatsRecorder.shared.getRecentlyPlayed()
        }
    }
}

import SwiftUI
import HawkCore
import HawkPlayback
import HawkSources

/// Primary tab navigation and root interface for HAWK.
public struct MainTabView: View {
    @State private var coordinator = PlaybackCoordinator.shared
    @State private var selectedTab = 0

    public init() {}

    public var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $selectedTab) {
                HomeView()
                    .tabItem {
                        Label("Home", systemImage: "house.fill")
                    }
                    .tag(0)

                ExploreView()
                    .tabItem {
                        Label("Explore", systemImage: "safari.fill")
                    }
                    .tag(1)

                SearchView()
                    .tabItem {
                        Label("Search", systemImage: "magnifyingglass")
                    }
                    .tag(2)

                LibraryView()
                    .tabItem {
                        Label("Library", systemImage: "music.square.stack.fill")
                    }
                    .tag(3)
            }
            .accentColor(HawkTheme.primaryAccent)

            // Docked Mini Player
            if let song = coordinator.currentSong {
                MiniPlayerView(
                    song: song,
                    isPlaying: coordinator.isPlaying,
                    onPlayPause: { coordinator.togglePlayPause() },
                    onNext: { coordinator.next() },
                    onTap: { coordinator.showNowPlaying = true }
                )
                .padding(.bottom, 54) // Positioned directly over system bottom tab bar
            }
        }
#if os(iOS)
        .fullScreenCover(isPresented: $coordinator.showNowPlaying) {
            if let song = coordinator.currentSong {
                NowPlayingView(
                    song: song,
                    isPlaying: coordinator.isPlaying,
                    currentTime: coordinator.currentTime,
                    duration: coordinator.duration,
                    onPlayPause: { coordinator.togglePlayPause() },
                    onNext: { coordinator.next() },
                    onPrevious: { coordinator.previous() },
                    onSeek: { newTime in coordinator.seek(to: newTime) },
                    onDismiss: { coordinator.showNowPlaying = false }
                )
            }
        }
#else
        .sheet(isPresented: $coordinator.showNowPlaying) {
            if let song = coordinator.currentSong {
                NowPlayingView(
                    song: song,
                    isPlaying: coordinator.isPlaying,
                    currentTime: coordinator.currentTime,
                    duration: coordinator.duration,
                    onPlayPause: { coordinator.togglePlayPause() },
                    onNext: { coordinator.next() },
                    onPrevious: { coordinator.previous() },
                    onSeek: { newTime in coordinator.seek(to: newTime) },
                    onDismiss: { coordinator.showNowPlaying = false }
                )
            }
        }
#endif
    }
}

// MARK: - Live Home View
struct HomeView: View {
    @State private var trendingSongs: [Song] = []
    @State private var topHits: [Song] = []
    @State private var isLoading = true
    private var coordinator = PlaybackCoordinator.shared

    var body: some View {
        NavigationStack {
            ZStack {
                HawkTheme.darkBackground.ignoresSafeArea()
                if isLoading && trendingSongs.isEmpty {
                    VStack(spacing: 16) {
                        ProgressView()
                            .tint(HawkTheme.primaryAccent)
                            .scaleEffect(1.2)
                        Text("Loading Music...")
                            .foregroundColor(HawkTheme.textSecondary)
                            .font(.subheadline)
                    }
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 24) {
                            // Section 1: Trending Now (Horizontal Cards)
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Trending Now")
                                    .font(.system(size: 22, weight: .bold))
                                    .foregroundColor(HawkTheme.textPrimary)
                                    .padding(.horizontal)

                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 16) {
                                        ForEach(trendingSongs) { song in
                                            Button {
                                                coordinator.play(song: song)
                                            } label: {
                                                SongCardView(song: song)
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                    .padding(.horizontal)
                                }
                            }

                            // Section 2: Top Charts (Vertical List)
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Top Hits & Charts")
                                    .font(.system(size: 22, weight: .bold))
                                    .foregroundColor(HawkTheme.textPrimary)
                                    .padding(.horizontal)

                                LazyVStack(spacing: 6) {
                                    ForEach(topHits) { song in
                                        Button {
                                            coordinator.play(song: song)
                                        } label: {
                                            SongRowView(song: song)
                                                .padding(.horizontal)
                                                .padding(.vertical, 4)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }
                        .padding(.top, 16)
                        .padding(.bottom, 100) // Padding for docked miniplayer
                    }
                    .refreshable {
                        await loadHomeData()
                    }
                }
            }
            .navigationTitle("Listen Now")
            .task {
                if trendingSongs.isEmpty {
                    await loadHomeData()
                }
            }
        }
    }

    private func loadHomeData() async {
        isLoading = true
        async let ytTask = (try? YouTubeSource().search(query: "Top Global Hits 2026")) ?? []
        async let saavnTask = (try? JioSaavnSource().search(query: "Trending Hits")) ?? []

        let (yt, saavn) = await (ytTask, saavnTask)
        self.trendingSongs = !yt.isEmpty ? yt : saavn
        self.topHits = !saavn.isEmpty ? saavn : yt
        self.isLoading = false
    }
}

// MARK: - Live Explore View
struct ExploreView: View {
    private let genres = [
        ("Pop Hits", "music.note", "Pop Hits", Color.purple),
        ("Hip-Hop & Rap", "flame.fill", "Hip Hop Hits", Color.orange),
        ("Rock & Metal", "guitars.fill", "Rock Hits", Color.red),
        ("Chill & Lo-Fi", "cup.and.saucer.fill", "Lofi Beats Chill", Color.blue),
        ("Bollywood & Punjabi", "sparkles", "Bollywood Hits", Color.pink),
        ("Electronic / Dance", "bolt.fill", "EDM Dance Hits", Color.cyan),
        ("Acoustic / Indie", "leaf.fill", "Indie Folk Acoustic", Color.green),
        ("R&B / Soul", "heart.fill", "RnB Hits", Color.indigo)
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                HawkTheme.darkBackground.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Browse Categories")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(HawkTheme.textPrimary)
                            .padding(.horizontal)

                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                            ForEach(genres, id: \.0) { genre in
                                NavigationLink(destination: GenreDetailView(title: genre.0, searchQuery: genre.2, accentColor: genre.3)) {
                                    ZStack(alignment: .bottomLeading) {
                                        LinearGradient(
                                            colors: [genre.3.opacity(0.8), genre.3.opacity(0.4)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                        .frame(height: 100)
                                        .cornerRadius(12)

                                        HStack {
                                            VStack(alignment: .leading) {
                                                Spacer()
                                                Text(genre.0)
                                                    .font(.system(size: 16, weight: .bold))
                                                    .foregroundColor(.white)
                                                    .padding(12)
                                            }
                                            Spacer()
                                            Image(systemName: genre.1)
                                                .font(.system(size: 28))
                                                .foregroundColor(.white.opacity(0.35))
                                                .padding(12)
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 100)
                    }
                    .padding(.top, 16)
                }
            }
            .navigationTitle("Explore")
        }
    }
}

// MARK: - Genre Detail View
struct GenreDetailView: View {
    let title: String
    let searchQuery: String
    let accentColor: Color

    @State private var songs: [Song] = []
    @State private var isLoading = true
    private var coordinator = PlaybackCoordinator.shared

    var body: some View {
        ZStack {
            HawkTheme.darkBackground.ignoresSafeArea()
            if isLoading {
                ProgressView()
                    .tint(accentColor)
            } else {
                List(songs) { song in
                    Button {
                        coordinator.play(song: song)
                    } label: {
                        SongRowView(song: song)
                    }
                    .buttonStyle(.plain)
                }
                .scrollContentBackground(.hidden)
            }
        }
        .navigationTitle(title)
        .task {
            async let yt = (try? YouTubeSource().search(query: searchQuery)) ?? []
            async let saavn = (try? JioSaavnSource().search(query: searchQuery)) ?? []
            let results = await (!yt.isEmpty ? yt : saavn)
            self.songs = results
            self.isLoading = false
        }
    }
}

// MARK: - Live Search View
struct SearchView: View {
    @State private var query = ""
    @State private var selectedSource = 0 // 0: All, 1: YouTube, 2: JioSaavn
    @State private var results: [Song] = []
    @State private var isSearching = false
    private var coordinator = PlaybackCoordinator.shared

    var body: some View {
        NavigationStack {
            ZStack {
                HawkTheme.darkBackground.ignoresSafeArea()
                VStack(spacing: 0) {
                    Picker("Source", selection: $selectedSource) {
                        Text("All").tag(0)
                        Text("YouTube Music").tag(1)
                        Text("JioSaavn (320k)").tag(2)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    .padding(.top, 8)
                    .padding(.bottom, 12)
                    .onChange(of: selectedSource) { _, _ in
                        triggerSearch(for: query)
                    }

                    if isSearching {
                        Spacer()
                        ProgressView()
                            .tint(HawkTheme.primaryAccent)
                            .scaleEffect(1.2)
                        Text("Searching...")
                            .font(.caption)
                            .foregroundColor(HawkTheme.textSecondary)
                            .padding(.top, 8)
                        Spacer()
                    } else if results.isEmpty && !query.isEmpty {
                        Spacer()
                        VStack(spacing: 8) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 40))
                                .foregroundColor(HawkTheme.textTertiary)
                            Text("No tracks found for '\(query)'")
                                .font(.subheadline)
                                .foregroundColor(HawkTheme.textSecondary)
                        }
                        Spacer()
                    } else if results.isEmpty {
                        Spacer()
                        VStack(spacing: 8) {
                            Image(systemName: "music.note")
                                .font(.system(size: 44))
                                .foregroundColor(HawkTheme.textTertiary)
                            Text("Search songs, artists, or albums")
                                .font(.headline)
                                .foregroundColor(HawkTheme.textSecondary)
                            Text("Type to search live across YouTube Music and JioSaavn")
                                .font(.caption)
                                .foregroundColor(HawkTheme.textTertiary)
                        }
                        Spacer()
                    } else {
                        List(results) { song in
                            Button {
                                coordinator.play(song: song)
                            } label: {
                                SongRowView(song: song)
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button {
                                    Task {
                                        _ = await PlaylistStore.shared.toggleFavorite(song: song)
                                    }
                                } label: {
                                    Label("Add to Favorites", systemImage: "heart")
                                }
                                Button {
                                    coordinator.play(song: song)
                                } label: {
                                    Label("Play Immediately", systemImage: "play")
                                }
                            }
                        }
                        .scrollContentBackground(.hidden)
                        .padding(.bottom, 60)
                    }
                }
            }
            .navigationTitle("Search")
            .searchable(text: $query, prompt: "Songs, Artists, Albums...")
            .onChange(of: query) { _, newQuery in
                triggerSearch(for: newQuery)
            }
        }
    }

    private func triggerSearch(for text: String) {
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else {
            results = []
            isSearching = false
            return
        }

        isSearching = true
        Task {
            try? await Task.sleep(nanoseconds: 350_000_000) // 350ms debounce
            guard clean == self.query.trimmingCharacters(in: .whitespacesAndNewlines) else { return }

            var fetched: [Song] = []
            switch selectedSource {
            case 1:
                fetched = (try? await YouTubeSource().search(query: clean)) ?? []
            case 2:
                fetched = (try? await JioSaavnSource().search(query: clean)) ?? []
            default:
                async let yt = (try? YouTubeSource().search(query: clean)) ?? []
                async let saavn = (try? JioSaavnSource().search(query: clean)) ?? []
                let (r1, r2) = await (yt, saavn)
                // Interleave or combine results
                var combined: [Song] = []
                let maxLen = max(r1.count, r2.count)
                for i in 0..<maxLen {
                    if i < r1.count { combined.append(r1[i]) }
                    if i < r2.count && !combined.contains(where: { $0.id == r2[i].id }) {
                        combined.append(r2[i])
                    }
                }
                fetched = combined
            }

            self.results = fetched
            self.isSearching = false
        }
    }
}

// MARK: - Song Card Component
struct SongCardView: View {
    let song: Song

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .bottomTrailing) {
                if let url = song.artworkURL {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        default:
                            cardPlaceholder
                        }
                    }
                    .frame(width: 145, height: 145)
                    .cornerRadius(12)
                    .clipped()
                } else {
                    cardPlaceholder
                }

                Image(systemName: "play.circle.fill")
                    .font(.system(size: 28))
                    .foregroundColor(HawkTheme.primaryAccent)
                    .background(Circle().fill(Color.black.opacity(0.6)))
                    .padding(8)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(song.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(HawkTheme.textPrimary)
                    .lineLimit(1)

                Text(song.artist)
                    .font(.system(size: 12))
                    .foregroundColor(HawkTheme.textSecondary)
                    .lineLimit(1)
            }
        }
        .frame(width: 145)
    }

    private var cardPlaceholder: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(HawkTheme.cardBackground)
            .frame(width: 145, height: 145)
            .overlay(
                Image(systemName: "music.note")
                    .font(.system(size: 32))
                    .foregroundColor(.white.opacity(0.3))
            )
    }
}

// MARK: - Library View
struct LibraryView: View {
    var body: some View {
        NavigationStack {
            ZStack {
                HawkTheme.darkBackground.ignoresSafeArea()
                List {
                    NavigationLink(destination: FavoritesView()) {
                        Label("Favorite Songs", systemImage: "heart.fill")
                    }
                    NavigationLink(destination: PlaylistsView()) {
                        Label("Playlists", systemImage: "music.note.list")
                    }
                    NavigationLink(destination: DownloadsView()) {
                        Label("Downloaded Music", systemImage: "arrow.down.circle.fill")
                    }
                    NavigationLink(destination: LocalFilesView()) {
                        Label("Local Audio Files", systemImage: "folder.fill")
                    }
                    NavigationLink(destination: SettingsView()) {
                        Label("Settings", systemImage: "gearshape.fill")
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Library")
        }
    }
}

import SwiftUI
import HawkCore
import HawkPlayback
import HawkSources
import HawkStats

/// Primary tab navigation and root interface for HAWK.
public struct MainTabView: View {
    @AppStorage("hawk_appearance_mode") private var appearanceModeRaw: String = AppearanceMode.system.rawValue
    @State private var coordinator = PlaybackCoordinator.shared
    @State private var selectedTab = 0

    private var activeColorScheme: ColorScheme? {
        (AppearanceMode(rawValue: appearanceModeRaw) ?? .system).colorScheme
    }

    public init() {
        HawkTheme.configureSystemAppearance()
    }

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
                        Label("Library", systemImage: "square.stack.fill")
                    }
                    .tag(3)
            }
            .accentColor(HawkTheme.primaryAccent)

            // Docked Mini Player with smooth spring entrance & exit
            if let song = coordinator.currentSong {
                MiniPlayerView(
                    song: song,
                    isPlaying: coordinator.isPlaying,
                    isBuffering: coordinator.isBuffering,
                    onPlayPause: { coordinator.togglePlayPause() },
                    onNext: { coordinator.next() },
                    onTap: {
                        withAnimation(.spring(response: 0.38, dampingFraction: 0.82)) {
                            coordinator.showNowPlaying = true
                        }
                    }
                )
                .transition(.asymmetric(
                    insertion: .move(edge: .bottom).combined(with: .opacity),
                    removal: .move(edge: .bottom).combined(with: .opacity)
                ))
                .animation(.spring(response: 0.38, dampingFraction: 0.82), value: coordinator.currentSong?.id)
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
                    onDismiss: {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                            coordinator.showNowPlaying = false
                        }
                    }
                )
                .preferredColorScheme(activeColorScheme)
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
                .preferredColorScheme(activeColorScheme)
            }
        }
#endif
        .preferredColorScheme(activeColorScheme)
    }
}

// MARK: - Live Home View
struct HomeView: View {
    @State private var trendingSongs: [Song] = []
    @State private var madeForYouSongs: [Song] = []
    @State private var jumpBackInSongs: [Song] = []
    @State private var topHits: [Song] = []
    @State private var featuredSong: Song?
    @State private var isLoading = true
    private var coordinator = PlaybackCoordinator.shared

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "Good morning"
        case 12..<17: return "Good afternoon"
        default: return "Good evening"
        }
    }

    private let popularArtists: [(name: String, query: String, icon: String)] = [
        ("The Weeknd", "The Weeknd hits", "person.circle.fill"),
        ("Arijit Singh", "Arijit Singh romantic hits", "person.circle.fill"),
        ("Ed Sheeran", "Ed Sheeran hits", "person.circle.fill"),
        ("Taylor Swift", "Taylor Swift hits", "person.circle.fill"),
        ("Drake", "Drake hits", "person.circle.fill"),
        ("Billie Eilish", "Billie Eilish hits", "person.circle.fill")
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                HawkTheme.darkBackground.ignoresSafeArea()

                if isLoading && trendingSongs.isEmpty {
                    VStack(spacing: 16) {
                        ProgressView()
                            .tint(HawkTheme.primaryAccent)
                            .scaleEffect(1.2)
                        Text("Curating Your Music...")
                            .foregroundColor(HawkTheme.textSecondary)
                            .font(.subheadline)
                    }
                } else {
                    ScrollView(showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 28) {
                            // Top Dynamic Greeting Header
                            VStack(alignment: .leading, spacing: 4) {
                                Text(greeting)
                                    .font(.system(size: 32, weight: .bold))
                                    .foregroundColor(HawkTheme.textPrimary)
                                Text("Handcrafted for you on HAWK")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(HawkTheme.textTertiary)
                            }
                            .padding(.horizontal, 20)
                            .padding(.top, 8)

                            // Editorial Featured Hero Card
                            if let hero = featuredSong {
                                Button {
                                    coordinator.play(song: hero)
                                } label: {
                                    FeaturedHeroView(song: hero)
                                }
                                .buttonStyle(.plain)
                                .hawkPressEffect()
                                .padding(.horizontal, 20)
                            }

                            // Section 1: Jump Back In / Favorites
                            if !jumpBackInSongs.isEmpty {
                                carouselSection(
                                    title: "Jump Back In",
                                    subtitle: "Pick up where you left off",
                                    songs: jumpBackInSongs
                                )
                            }

                            // Section 2: Made For You (1:1 Artwork Carousel)
                            if !madeForYouSongs.isEmpty {
                                carouselSection(
                                    title: "Made For You",
                                    subtitle: "Personalised daily mix",
                                    songs: madeForYouSongs
                                )
                            }

                            // Section 3: Popular Artists (Circular Avatars)
                            VStack(alignment: .leading, spacing: 14) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Favorite Artists")
                                        .font(.system(size: 22, weight: .bold))
                                        .foregroundColor(HawkTheme.textPrimary)
                                    Text("Explore their complete catalogues")
                                        .font(.system(size: 13))
                                        .foregroundColor(HawkTheme.textTertiary)
                                }
                                .padding(.horizontal, 20)

                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 18) {
                                        ForEach(popularArtists, id: \.name) { artist in
                                            Button {
                                                Task {
                                                    let results = (try? await JioSaavnSource().search(query: artist.query)) ?? []
                                                    if let first = results.first {
                                                        coordinator.play(song: first, context: results)
                                                    }
                                                }
                                            } label: {
                                                VStack(spacing: 8) {
                                                    ZStack {
                                                        Circle()
                                                            .fill(LinearGradient(
                                                                colors: [HawkTheme.cardBackground, HawkTheme.primaryAccent.opacity(0.35)],
                                                                startPoint: .topLeading,
                                                                endPoint: .bottomTrailing
                                                            ))
                                                            .frame(width: 80, height: 80)
                                                            .overlay(
                                                                Circle()
                                                                    .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
                                                            )
                                                            .shadow(color: .black.opacity(0.3), radius: 6, y: 3)

                                                        Image(systemName: "music.mic")
                                                            .font(.system(size: 28))
                                                            .foregroundColor(HawkTheme.textPrimary)
                                                    }

                                                    Text(artist.name)
                                                        .font(.system(size: 12, weight: .semibold))
                                                        .foregroundColor(HawkTheme.textPrimary)
                                                        .lineLimit(1)
                                                }
                                                .frame(width: 88)
                                            }
                                            .buttonStyle(.plain)
                                            .hawkPressEffect()
                                        }
                                    }
                                    .padding(.horizontal, 20)
                                }
                            }

                            // Section 4: Global Hits & Trending
                            if !trendingSongs.isEmpty {
                                carouselSection(
                                    title: "Trending Worldwide",
                                    subtitle: "What listeners are playing right now",
                                    songs: trendingSongs
                                )
                            }

                            // Section 5: Top Charts List
                            if !topHits.isEmpty {
                                VStack(alignment: .leading, spacing: 12) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Top Charts")
                                            .font(.system(size: 22, weight: .bold))
                                            .foregroundColor(HawkTheme.textPrimary)
                                        Text("Most played this week")
                                            .font(.system(size: 13))
                                            .foregroundColor(HawkTheme.textTertiary)
                                    }
                                    .padding(.horizontal, 20)

                                    LazyVStack(spacing: 6) {
                                        ForEach(topHits.prefix(10)) { song in
                                            Button {
                                                coordinator.play(song: song, context: topHits)
                                            } label: {
                                                SongRowView(song: song)
                                                    .padding(.horizontal, 20)
                                                    .padding(.vertical, 4)
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.top, 12)
                        .padding(.bottom, 110) // Padding for docked miniplayer
                    }
                    .refreshable {
                        await loadHomeData()
                    }
                }
            }
            .navigationTitle("")
            #if os(iOS)
            .toolbar(.hidden, for: .navigationBar)
            #endif
            .task {
                if trendingSongs.isEmpty {
                    await loadHomeData()
                }
            }
        }
    }

    @ViewBuilder
    private func carouselSection(title: String, subtitle: String, songs: [Song]) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(HawkTheme.textPrimary)
                Text(subtitle)
                    .font(.system(size: 13))
                    .foregroundColor(HawkTheme.textTertiary)
            }
            .padding(.horizontal, 20)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(songs) { song in
                        Button {
                            coordinator.play(song: song, context: songs)
                        } label: {
                            SongCardView(song: song)
                        }
                        .buttonStyle(.plain)
                        .hawkPressEffect()
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }

    private func loadHomeData() async {
        isLoading = true

        // Load favorites from local PlaylistStore
        let favs = await PlaylistStore.shared.getFavorites().songs

        async let saavnTrending = (try? JioSaavnSource().search(query: "Top Hits 2026")) ?? []
        async let ytTrending = (try? YouTubeSource().search(query: "Top Global Hits")) ?? []
        async let popMix = (try? JioSaavnSource().search(query: "Global Pop Hits")) ?? []

        let (saavn, yt, pop) = await (saavnTrending, ytTrending, popMix)

        let dedupedTrending = TrackDeduplicator.deduplicate(saavn + yt)
        let dedupedPop = TrackDeduplicator.deduplicate(pop + yt)

        self.trendingSongs = dedupedTrending
        self.madeForYouSongs = dedupedPop
        self.topHits = TrackDeduplicator.deduplicate(yt + saavn)
        self.featuredSong = dedupedTrending.first ?? dedupedPop.first

        // Jump Back In uses actual listening history, falling back to favorites or top trending
        let history = await ListeningStatsRecorder.shared.getRecentlyPlayed()
        if !history.isEmpty {
            self.jumpBackInSongs = history
        } else if !favs.isEmpty {
            self.jumpBackInSongs = favs
        } else {
            self.jumpBackInSongs = Array(dedupedTrending.prefix(6))
        }
        self.isLoading = false
    }
}

/// Editorial Featured Hero banner at the top of the Home view.
struct FeaturedHeroView: View {
    let song: Song

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            // Background Artwork
            AsyncImage(url: song.artworkURL) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                default:
                    Rectangle()
                        .fill(HawkTheme.cardBackground)
                }
            }
            .frame(height: 220)
            .clipped()

            // Dark gradient scrim for legibility
            LinearGradient(
                colors: [Color.clear, Color.black.opacity(0.4), Color.black.opacity(0.85)],
                startPoint: .top,
                endPoint: .bottom
            )

            // Content overlay
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("FEATURED TRACK")
                        .font(.system(size: 11, weight: .heavy))
                        .foregroundColor(HawkTheme.primaryAccent)
                        .tracking(1.2)

                    Text(song.title)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(1)

                    Text(song.artist)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                        .lineLimit(1)
                }

                Spacer()

                // Floating Liquid Glass Play Button
                ZStack {
                    Circle()
                        .fill(HawkTheme.primaryAccent)
                        .frame(width: 48, height: 48)
                        .shadow(color: HawkTheme.primaryAccent.opacity(0.5), radius: 8, y: 4)

                    Image(systemName: "play.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.white)
                        .offset(x: 1.5)
                }
            }
            .padding(18)
        }
        .frame(height: 220)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.35), radius: 14, y: 7)
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
                        coordinator.play(song: song, context: songs)
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
            async let saavn = (try? JioSaavnSource().search(query: searchQuery)) ?? []
            async let yt = (try? YouTubeSource().search(query: searchQuery)) ?? []
            let (r1, r2) = await (saavn, yt)
            self.songs = TrackDeduplicator.deduplicate(r1 + r2)
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
                                coordinator.play(song: song, context: results)
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
                                    coordinator.play(song: song, context: results)
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
                async let saavn = (try? JioSaavnSource().search(query: clean)) ?? []
                async let yt = (try? YouTubeSource().search(query: clean)) ?? []
                let (rSaavn, rYt) = await (saavn, yt)
                fetched = TrackDeduplicator.deduplicate(rSaavn + rYt)
            }

            self.results = fetched
            self.isSearching = false
        }
    }
}

// MARK: - Song Card Component (1:1 Square Artwork)
struct SongCardView: View {
    let song: Song

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
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
                    .frame(width: 160, height: 160)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.12), lineWidth: 0.8)
                    )
                    .shadow(color: .black.opacity(0.28), radius: 8, y: 4)
                } else {
                    cardPlaceholder
                }

                // Mini Liquid Glass Play Accent
                ZStack {
                    Circle()
                        .fill(HawkTheme.primaryAccent)
                        .frame(width: 34, height: 34)
                        .shadow(color: .black.opacity(0.4), radius: 4, y: 2)

                    Image(systemName: "play.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.white)
                        .offset(x: 1)
                }
                .padding(10)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(song.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(HawkTheme.textPrimary)
                    .lineLimit(1)

                Text(song.artist)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(HawkTheme.textTertiary)
                    .lineLimit(1)
            }
        }
        .frame(width: 160)
    }

    private var cardPlaceholder: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [HawkTheme.cardBackground, HawkTheme.cardBackground.opacity(0.6)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: 160, height: 160)
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.08), lineWidth: 0.8)
            )
            .overlay(
                Image(systemName: "music.note")
                    .font(.system(size: 38))
                    .foregroundColor(.white.opacity(0.25))
            )
            .shadow(color: .black.opacity(0.28), radius: 8, y: 4)
    }
}

// MARK: - Library Hub View
struct LibraryView: View {
    @State private var recentLibrarySongs: [Song] = []
    private var coordinator = PlaybackCoordinator.shared

    private let librarySections: [(title: String, icon: String, color: Color, destination: AnyView)] = [
        ("Liked Songs", "heart.fill", HawkTheme.primaryAccent, AnyView(FavoritesView())),
        ("Playlists", "music.note.list", HawkTheme.primaryAccent, AnyView(PlaylistsView())),
        ("Albums", "square.stack", HawkTheme.secondaryAccent, AnyView(AlbumsView())),
        ("Artists", "music.mic", HawkTheme.secondaryAccent, AnyView(ArtistsView())),
        ("Recently Added", "clock.fill", HawkTheme.secondaryAccent, AnyView(RecentlyAddedView())),
        ("Recently Played", "play.circle.fill", HawkTheme.primaryAccent, AnyView(RecentlyPlayedView())),
        ("All Songs", "music.note", HawkTheme.secondaryAccent, AnyView(AllSongsView())),
        ("Downloaded", "arrow.down.circle.fill", HawkTheme.primaryAccent, AnyView(DownloadsView())),
        ("Local Files", "folder.fill", HawkTheme.secondaryAccent, AnyView(LocalFilesView()))
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                HawkTheme.darkBackground.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 20) {
                        // Section: Navigation List
                        VStack(spacing: 1) {
                            ForEach(librarySections, id: \.title) { sec in
                                NavigationLink(destination: sec.destination) {
                                    HStack(spacing: 14) {
                                        Image(systemName: sec.icon)
                                            .font(.system(size: 18, weight: .semibold))
                                            .foregroundColor(sec.color)
                                            .frame(width: 28, height: 28)

                                        Text(sec.title)
                                            .font(.system(size: 17, weight: .regular))
                                            .foregroundColor(HawkTheme.textPrimary)

                                        Spacer()

                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 13, weight: .semibold))
                                            .foregroundColor(HawkTheme.textTertiary)
                                    }
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 12)
                                }
                                .buttonStyle(.plain)

                                if sec.title != librarySections.last?.title {
                                    Divider()
                                        .background(Color.white.opacity(0.08))
                                        .padding(.leading, 62)
                                }
                            }
                        }
                        .background(HawkTheme.cardBackground)
                        .cornerRadius(16)
                        .padding(.horizontal, 16)
                        .padding(.top, 4)

                        // Section: Recently Added 1:1 Artwork Carousel
                        if !recentLibrarySongs.isEmpty {
                            VStack(alignment: .leading, spacing: 14) {
                                Text("Recently Added")
                                    .font(.system(size: 22, weight: .bold))
                                    .foregroundColor(HawkTheme.textPrimary)
                                    .padding(.horizontal, 20)

                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 16) {
                                        ForEach(recentLibrarySongs.prefix(10)) { song in
                                            Button {
                                                coordinator.play(song: song, context: recentLibrarySongs)
                                            } label: {
                                                SongCardView(song: song)
                                            }
                                            .buttonStyle(.plain)
                                            .hawkPressEffect()
                                        }
                                    }
                                    .padding(.horizontal, 20)
                                }
                            }
                        }
                    }
                    .padding(.bottom, 110)
                }
            }
            .navigationTitle("Library")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    NavigationLink(destination: SettingsView()) {
                        Image(systemName: "gearshape.fill")
                            .foregroundColor(HawkTheme.primaryAccent)
                    }
                }
            }
            .task {
                let all = await LibraryAggregator.shared.allLibrarySongs()
                self.recentLibrarySongs = all.sorted { ($0.dateAdded ?? .distantPast) > ($1.dateAdded ?? .distantPast) }
            }
        }
    }
}

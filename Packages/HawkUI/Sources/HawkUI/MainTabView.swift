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
    @State private var recommendationShelves: [RecommendationShelf] = []
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

                if isLoading && trendingSongs.isEmpty && recommendationShelves.isEmpty {
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
                            // Top Dynamic Greeting Header & Official Brand Mark
                            HStack(alignment: .center) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(greeting)
                                        .font(.system(size: 32, weight: .bold))
                                        .foregroundColor(HawkTheme.textPrimary)
                                    Text("Handcrafted for you on HAWK")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(HawkTheme.textTertiary)
                                    }
                                Spacer()
                                Image("hawk-logo", bundle: .main)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 40, height: 40)
                                    .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                                            .stroke(HawkTheme.dividerColor, lineWidth: 0.5)
                                    )
                                    .shadow(color: Color.black.opacity(0.2), radius: 4, x: 0, y: 2)
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

                            // Dynamic Personalized Discovery Shelves (From RecommendationEngine)
                            ForEach(recommendationShelves) { shelf in
                                carouselSection(
                                    title: shelf.title,
                                    subtitle: shelf.subtitle,
                                    songs: shelf.tracks
                                )
                            }

                            // Popular Artists (Circular Avatars)
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

                            // Trending Worldwide
                            if !trendingSongs.isEmpty {
                                carouselSection(
                                    title: "Trending Worldwide",
                                    subtitle: "What listeners are playing right now",
                                    songs: trendingSongs
                                )
                            }

                            // Top Charts List
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
                if trendingSongs.isEmpty && recommendationShelves.isEmpty {
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
                        .contextMenu {
                            Button {
                                coordinator.play(song: song, context: songs)
                            } label: {
                                Label("Play Now", systemImage: "play")
                            }

                            Button {
                                Task {
                                    await QueueManager.shared.playNext(song: song)
                                }
                            } label: {
                                Label("Play Next", systemImage: "text.line.first.and.arrowtriangle.forward")
                            }

                            Button {
                                Task {
                                    await QueueManager.shared.addToQueue(song: song)
                                }
                            } label: {
                                Label("Add to Queue", systemImage: "text.badge.plus")
                            }

                            Divider()

                            Button {
                                Task {
                                    _ = await PlaylistStore.shared.toggleFavorite(song: song)
                                    await loadHomeData()
                                }
                            } label: {
                                Label("Favorite", systemImage: "heart")
                            }

                            Button(role: .destructive) {
                                Task {
                                    await RecommendationEngine.shared.dislikeTrack(songId: song.id)
                                    await loadHomeData()
                                }
                            } label: {
                                Label("Hide / Dislike Recommendation", systemImage: "hand.thumbsdown")
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }

    private func loadHomeData() async {
        isLoading = true

        let history = await ListeningStatsRecorder.shared.getRecentlyPlayed()
        let favs = await PlaylistStore.shared.getFavorites().songs
        let librarySongs = await LibraryAggregator.shared.allLibrarySongs()

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        let monthKey = formatter.string(from: Date())
        let bucket = await ListeningStatsRecorder.shared.getMonthlyReplay(monthKey: monthKey)

        let shelves = await RecommendationEngine.shared.generateShelves(
            history: history,
            favorites: favs,
            librarySongs: librarySongs,
            monthlyBucket: bucket
        )
        self.recommendationShelves = shelves

        async let saavnTrending = (try? JioSaavnSource().search(query: "Top Hits 2026")) ?? []
        async let ytTrending = (try? YouTubeSource().search(query: "Top Global Hits")) ?? []

        let (saavn, yt) = await (saavnTrending, ytTrending)
        let dedupedTrending = TrackDeduplicator.deduplicate(saavn + yt)

        self.trendingSongs = dedupedTrending
        self.topHits = dedupedTrending
        self.featuredSong = shelves.first?.tracks.first ?? dedupedTrending.first

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
struct GenreCategory: Identifiable {
    let id = UUID()
    let name: String
    let icon: String
    let query: String
    let color: Color
}

struct GenreCardView: View {
    let genre: GenreCategory

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            LinearGradient(
                colors: [genre.color.opacity(0.8), genre.color.opacity(0.4)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .frame(height: 100)
            .cornerRadius(12)

            HStack {
                VStack(alignment: .leading) {
                    Spacer()
                    Text(genre.name)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                        .padding(12)
                }
                Spacer()
                Image(systemName: genre.icon)
                    .font(.system(size: 28))
                    .foregroundColor(.white.opacity(0.35))
                    .padding(12)
            }
        }
    }
}

struct ExploreView: View {
    private let genres: [GenreCategory] = [
        GenreCategory(name: "Pop Hits", icon: "music.note", query: "Pop Hits", color: Color.purple),
        GenreCategory(name: "Hip-Hop & Rap", icon: "flame.fill", query: "Hip Hop Hits", color: Color.orange),
        GenreCategory(name: "Rock & Metal", icon: "guitars.fill", query: "Rock Hits", color: Color.red),
        GenreCategory(name: "Chill & Lo-Fi", icon: "cup.and.saucer.fill", query: "Lofi Beats Chill", color: Color.blue),
        GenreCategory(name: "Bollywood & Punjabi", icon: "sparkles", query: "Bollywood Hits", color: Color.pink),
        GenreCategory(name: "Electronic / Dance", icon: "bolt.fill", query: "EDM Dance Hits", color: Color.cyan),
        GenreCategory(name: "Acoustic / Indie", icon: "leaf.fill", query: "Indie Folk Acoustic", color: Color.green),
        GenreCategory(name: "R&B / Soul", icon: "heart.fill", query: "RnB Hits", color: Color.indigo)
    ]

    private let gridColumns = [
        GridItem(.flexible()),
        GridItem(.flexible())
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

                        LazyVGrid(columns: gridColumns, spacing: 14) {
                            ForEach(genres) { genre in
                                NavigationLink(destination: GenreDetailView(title: genre.name, searchQuery: genre.query, accentColor: genre.color)) {
                                    GenreCardView(genre: genre)
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

    init(title: String, searchQuery: String, accentColor: Color) {
        self.title = title
        self.searchQuery = searchQuery
        self.accentColor = accentColor
    }

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

// MARK: - Universal Federated Search View
struct SearchView: View {
    @State private var query = ""
    @State private var searchResults = UniversalSearchResults()
    @State private var searchHistory: [String] = []
    @State private var isSearching = false
    @State private var searchTask: Task<Void, Never>?
    private var coordinator = PlaybackCoordinator.shared

    var body: some View {
        NavigationStack {
            ZStack {
                HawkTheme.darkBackground.ignoresSafeArea()
                VStack(spacing: 0) {
                    if isSearching {
                        Spacer()
                        ProgressView()
                            .tint(HawkTheme.primaryAccent)
                            .scaleEffect(1.2)
                        Text("Searching library, downloads & streaming...")
                            .font(HawkTypography.caption1)
                            .foregroundColor(HawkTheme.textSecondary)
                            .padding(.top, 8)
                        Spacer()
                    } else if query.trimmingCharacters(in: .whitespaces).isEmpty {
                        // Empty query: Show Search History & Suggestions
                        ScrollView {
                            VStack(alignment: .leading, spacing: HawkSpacing.lg) {
                                if !searchHistory.isEmpty {
                                    VStack(alignment: .leading, spacing: HawkSpacing.sm) {
                                        HStack {
                                            Text("Recent Searches")
                                                .font(HawkTypography.headline)
                                                .foregroundColor(HawkTheme.textPrimary)
                                            Spacer()
                                            Button("Clear") {
                                                Task {
                                                    await UniversalSearchEngine.shared.clearSearchHistory()
                                                    searchHistory = []
                                                }
                                            }
                                            .font(HawkTypography.subheadline)
                                            .foregroundColor(HawkTheme.primaryAccent)
                                        }
                                        .padding(.horizontal, HawkSpacing.md)

                                        LazyVStack(spacing: 0) {
                                            ForEach(searchHistory, id: \.self) { pastQuery in
                                                Button {
                                                    query = pastQuery
                                                    triggerSearch(for: pastQuery)
                                                } label: {
                                                    HStack(spacing: HawkSpacing.sm) {
                                                        Image(systemName: "clock.arrow.circlepath")
                                                            .font(.system(size: 15))
                                                            .foregroundColor(HawkTheme.textTertiary)

                                                        Text(pastQuery)
                                                            .font(HawkTypography.body)
                                                            .foregroundColor(HawkTheme.textPrimary)

                                                        Spacer()

                                                        Image(systemName: "arrow.up.left")
                                                            .font(.system(size: 13))
                                                            .foregroundColor(HawkTheme.textTertiary)
                                                    }
                                                    .padding(.horizontal, HawkSpacing.md)
                                                    .padding(.vertical, 12)
                                                }
                                                .buttonStyle(.plain)

                                                Divider()
                                                    .background(HawkTheme.dividerColor)
                                                    .padding(.leading, 44)
                                            }
                                        }
                                        .background(HawkTheme.cardBackground)
                                        .clipShape(RoundedRectangle(cornerRadius: HawkRadius.lg, style: .continuous))
                                        .padding(.horizontal, HawkSpacing.md)
                                    }
                                }

                                // Search Suggestions Section
                                VStack(alignment: .leading, spacing: HawkSpacing.sm) {
                                    Text("Explore Searches")
                                        .font(HawkTypography.headline)
                                        .foregroundColor(HawkTheme.textPrimary)
                                        .padding(.horizontal, HawkSpacing.md)

                                    let suggestions = ["The Weeknd", "Arijit Singh", "Ed Sheeran", "Top Hits 2026", "Lofi Beats", "Bollywood Romantic"]
                                    ScrollView(.horizontal, showsIndicators: false) {
                                        HStack(spacing: HawkSpacing.xs) {
                                            ForEach(suggestions, id: \.self) { sug in
                                                Button {
                                                    query = sug
                                                    triggerSearch(for: sug)
                                                } label: {
                                                    Text(sug)
                                                        .font(HawkTypography.subheadline)
                                                        .foregroundColor(HawkTheme.textPrimary)
                                                        .padding(.horizontal, 14)
                                                        .padding(.vertical, 8)
                                                        .background(HawkTheme.cardBackground)
                                                        .clipShape(Capsule())
                                                        .overlay(Capsule().stroke(HawkTheme.dividerColor, lineWidth: 0.8))
                                                }
                                                .buttonStyle(.plain)
                                            }
                                        }
                                        .padding(.horizontal, HawkSpacing.md)
                                    }
                                }
                            }
                            .padding(.top, HawkSpacing.md)
                            .padding(.bottom, 110)
                        }
                    } else if searchResults.isEmpty {
                        Spacer()
                        VStack(spacing: 8) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 40))
                                .foregroundColor(HawkTheme.textTertiary)
                            Text("No tracks found for '\(query)'")
                                .font(HawkTypography.subheadline)
                                .foregroundColor(HawkTheme.textSecondary)
                        }
                        Spacer()
                    } else {
                        // Categorized Search Results
                        List {
                            // Section: Top Result
                            if let top = searchResults.topResult {
                                Section(header: Text("TOP RESULT").font(HawkTypography.caption1.weight(.bold)).foregroundColor(HawkTheme.textTertiary)) {
                                    Button {
                                        coordinator.play(song: top, context: [top] + searchResults.streamingMatches)
                                    } label: {
                                        HStack(spacing: HawkSpacing.md) {
                                            HawkArtwork(url: top.artworkURL, size: 64, cornerRadius: HawkRadius.md)

                                            VStack(alignment: .leading, spacing: 4) {
                                                Text(top.title)
                                                    .font(HawkTypography.headline)
                                                    .foregroundColor(HawkTheme.textPrimary)
                                                    .lineLimit(1)
                                                Text("\(top.artist) • Song")
                                                    .font(HawkTypography.subheadline)
                                                    .foregroundColor(HawkTheme.textSecondary)
                                                    .lineLimit(1)
                                            }
                                            Spacer()
                                            Image(systemName: "play.circle.fill")
                                                .font(.system(size: 32))
                                                .foregroundColor(HawkTheme.primaryAccent)
                                        }
                                        .padding(.vertical, 4)
                                    }
                                    .buttonStyle(.plain)
                                    .hawkSongContextMenu(song: top)
                                }
                                .listRowBackground(HawkTheme.cardBackground)
                            }

                            // Section: Library Matches
                            if !searchResults.libraryMatches.isEmpty {
                                Section(header: Text("FROM YOUR LIBRARY").font(HawkTypography.caption1.weight(.bold)).foregroundColor(HawkTheme.textTertiary)) {
                                    ForEach(searchResults.libraryMatches.prefix(5)) { song in
                                        Button {
                                            coordinator.play(song: song, context: searchResults.libraryMatches)
                                        } label: {
                                            SongRowView(song: song)
                                        }
                                        .buttonStyle(.plain)
                                        .hawkSongContextMenu(song: song)
                                    }
                                }
                                .listRowBackground(HawkTheme.cardBackground)
                            }

                            // Section: Playlists Matches
                            if !searchResults.playlistMatches.isEmpty {
                                Section(header: Text("PLAYLISTS").font(HawkTypography.caption1.weight(.bold)).foregroundColor(HawkTheme.textTertiary)) {
                                    ForEach(searchResults.playlistMatches) { playlist in
                                        NavigationLink(destination: PlaylistDetailView(playlist: playlist)) {
                                            HStack(spacing: HawkSpacing.md) {
                                                ZStack {
                                                    RoundedRectangle(cornerRadius: HawkRadius.sm, style: .continuous)
                                                        .fill(HawkTheme.secondarySurface)
                                                        .frame(width: 44, height: 44)
                                                    Image(systemName: "music.note.list")
                                                        .foregroundColor(HawkLibraryStyle.iconTint)
                                                }
                                                VStack(alignment: .leading, spacing: 2) {
                                                    Text(playlist.title)
                                                        .font(HawkTypography.body.weight(.medium))
                                                        .foregroundColor(HawkTheme.textPrimary)
                                                    Text("\(playlist.songs.count) songs")
                                                        .font(HawkTypography.caption1)
                                                        .foregroundColor(HawkTheme.textSecondary)
                                                }
                                            }
                                            .padding(.vertical, 2)
                                        }
                                    }
                                }
                                .listRowBackground(HawkTheme.cardBackground)
                            }

                            // Section: Downloaded Tracks
                            if !searchResults.downloadMatches.isEmpty {
                                Section(header: Text("DOWNLOADED (OFFLINE)").font(HawkTypography.caption1.weight(.bold)).foregroundColor(HawkTheme.textTertiary)) {
                                    ForEach(searchResults.downloadMatches.prefix(5)) { song in
                                        Button {
                                            coordinator.play(song: song, context: searchResults.downloadMatches)
                                        } label: {
                                            SongRowView(song: song)
                                        }
                                        .buttonStyle(.plain)
                                        .hawkSongContextMenu(song: song)
                                    }
                                }
                                .listRowBackground(HawkTheme.cardBackground)
                            }

                            // Section: Global Streaming Results
                            if !searchResults.streamingMatches.isEmpty {
                                Section(header: Text("STREAMING & WEB").font(HawkTypography.caption1.weight(.bold)).foregroundColor(HawkTheme.textTertiary)) {
                                    ForEach(searchResults.streamingMatches) { song in
                                        Button {
                                            coordinator.play(song: song, context: searchResults.streamingMatches)
                                        } label: {
                                            SongRowView(song: song)
                                        }
                                        .buttonStyle(.plain)
                                        .hawkSongContextMenu(song: song)
                                    }
                                }
                                .listRowBackground(HawkTheme.cardBackground)
                            }
                        }
                        .scrollContentBackground(.hidden)
                        .padding(.bottom, 60)
                    }
                }
            }
            .navigationTitle("Search")
            .searchable(text: $query, prompt: "Songs, Artists, Albums, Playlists...")
            .onChange(of: query) { _, newQuery in
                triggerSearch(for: newQuery)
            }
            .task {
                searchHistory = await UniversalSearchEngine.shared.getSearchHistory()
            }
        }
    }

    private func triggerSearch(for text: String) {
        searchTask?.cancel()
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else {
            searchResults = UniversalSearchResults()
            isSearching = false
            return
        }

        isSearching = true
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 300_000_000) // 300ms debounce
            if Task.isCancelled { return }
            guard clean == self.query.trimmingCharacters(in: .whitespacesAndNewlines) else { return }

            let results = await UniversalSearchEngine.shared.search(query: clean)
            if !Task.isCancelled {
                self.searchResults = results
                self.isSearching = false
                self.searchHistory = await UniversalSearchEngine.shared.getSearchHistory()
            }
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
    @State private var allLibrarySongs: [Song] = []
    @State private var librarySearchText: String = ""
    @State private var selectedFilter: LibraryFilter = .all
    @State private var showCreatePlaylistSheet: Bool = false
    @State private var newPlaylistName: String = ""
    private var coordinator = PlaybackCoordinator.shared

    enum LibraryFilter: String, CaseIterable, Identifiable {
        case all = "All"
        case downloaded = "Downloaded"
        case youtube = "YouTube"
        case local = "Local"

        var id: String { rawValue }
    }

    private let librarySections: [(title: String, icon: String, destination: AnyView)] = [
        ("Liked Songs", "heart.fill", AnyView(FavoritesView())),
        ("Playlists", "music.note.list", AnyView(PlaylistsView())),
        ("Albums", "square.stack", AnyView(AlbumsView())),
        ("Artists", "music.mic", AnyView(ArtistsView())),
        ("Songs", "music.note", AnyView(AllSongsView())),
        ("Downloads", "arrow.down.circle.fill", AnyView(DownloadsView())),
        ("Recently Played", "clock.fill", AnyView(RecentlyPlayedView())),
        ("Local Music", "folder.fill", AnyView(LocalFilesView())),
        ("YouTube Music Imports", "play.rectangle.fill", AnyView(YouTubeMusicImportsView()))
    ]

    private var filteredSearchSongs: [Song] {
        guard !librarySearchText.trimmingCharacters(in: .whitespaces).isEmpty else { return [] }
        return allLibrarySongs.filter {
            $0.title.localizedCaseInsensitiveContains(librarySearchText) ||
            $0.artist.localizedCaseInsensitiveContains(librarySearchText)
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                HawkTheme.darkBackground.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: HawkSpacing.lg) {
                        // In-Library Search Field
                        HawkSearchField(
                            text: $librarySearchText,
                            placeholder: "Search within library..."
                        )
                        .padding(.horizontal, HawkSpacing.md)
                        .padding(.top, HawkSpacing.xs)

                        if !librarySearchText.isEmpty {
                            // Search Results within Library
                            VStack(alignment: .leading, spacing: HawkSpacing.xs) {
                                Text("Matching Library Songs (\(filteredSearchSongs.count))")
                                    .font(HawkTypography.subheadline.weight(.semibold))
                                    .foregroundColor(HawkTheme.textSecondary)
                                    .padding(.horizontal, HawkSpacing.md)

                                if filteredSearchSongs.isEmpty {
                                    Text("No matching songs found in your library.")
                                        .font(HawkTypography.footnote)
                                        .foregroundColor(HawkTheme.textTertiary)
                                        .padding(.horizontal, HawkSpacing.md)
                                        .padding(.vertical, HawkSpacing.md)
                                } else {
                                    VStack(spacing: 0) {
                                        ForEach(filteredSearchSongs.prefix(15)) { song in
                                            Button {
                                                coordinator.play(song: song, context: filteredSearchSongs)
                                            } label: {
                                                SongRowView(song: song)
                                                    .padding(.horizontal, HawkSpacing.md)
                                                    .padding(.vertical, 6)
                                            }
                                            .buttonStyle(.plain)

                                            Divider()
                                                .background(HawkTheme.dividerColor)
                                                .padding(.leading, 70)
                                        }
                                    }
                                    .background(HawkTheme.cardBackground)
                                    .clipShape(RoundedRectangle(cornerRadius: HawkRadius.lg, style: .continuous))
                                    .padding(.horizontal, HawkSpacing.md)
                                }
                            }
                        } else {
                            // Monochromatic Category Navigation List
                            VStack(spacing: 0) {
                                ForEach(Array(librarySections.enumerated()), id: \.offset) { index, sec in
                                    NavigationLink(destination: sec.destination) {
                                        HStack(spacing: HawkSpacing.md) {
                                            // Unified monochromatic tile
                                            ZStack {
                                                RoundedRectangle(cornerRadius: HawkRadius.sm, style: .continuous)
                                                    .fill(HawkTheme.secondarySurface)
                                                    .frame(width: 32, height: 32)

                                                Image(systemName: sec.icon)
                                                    .font(.system(size: 15, weight: .semibold))
                                                    .foregroundColor(HawkLibraryStyle.iconTint)
                                            }

                                            Text(sec.title)
                                                .font(HawkTypography.body.weight(.medium))
                                                .foregroundColor(HawkTheme.textPrimary)

                                            Spacer()

                                            Image(systemName: "chevron.right")
                                                .font(.system(size: 13, weight: .semibold))
                                                .foregroundColor(HawkTheme.textTertiary)
                                        }
                                        .padding(.horizontal, HawkSpacing.md)
                                        .padding(.vertical, 11)
                                    }
                                    .buttonStyle(.plain)

                                    if index < librarySections.count - 1 {
                                        Divider()
                                            .background(HawkTheme.dividerColor)
                                            .padding(.leading, 60)
                                    }
                                }
                            }
                            .background(HawkTheme.cardBackground)
                            .clipShape(RoundedRectangle(cornerRadius: HawkRadius.lg, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: HawkRadius.lg, style: .continuous)
                                    .stroke(HawkTheme.dividerColor, lineWidth: 0.8)
                            )
                            .padding(.horizontal, HawkSpacing.md)

                            // Recently Added 1:1 Artwork Carousel
                            if !recentLibrarySongs.isEmpty {
                                VStack(alignment: .leading, spacing: HawkSpacing.sm) {
                                    Text("Recently Added")
                                        .font(HawkTypography.title3)
                                        .foregroundColor(HawkTheme.textPrimary)
                                        .padding(.horizontal, HawkSpacing.md)

                                    ScrollView(.horizontal, showsIndicators: false) {
                                        HStack(spacing: HawkSpacing.md) {
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
                                        .padding(.horizontal, HawkSpacing.md)
                                    }
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
                    HStack(spacing: HawkSpacing.sm) {
                        Button {
                            showCreatePlaylistSheet = true
                        } label: {
                            Image(systemName: "plus")
                                .foregroundColor(HawkTheme.primaryAccent)
                        }

                        NavigationLink(destination: SettingsView()) {
                            Image(systemName: "gearshape.fill")
                                .foregroundColor(HawkTheme.textSecondary)
                        }
                    }
                }
            }
            .sheet(isPresented: $showCreatePlaylistSheet) {
                NavigationStack {
                    ZStack {
                        HawkTheme.darkBackground.ignoresSafeArea()
                        VStack(spacing: HawkSpacing.xl) {
                            TextField("Playlist Name", text: $newPlaylistName)
                                .font(HawkTypography.body)
                                .padding()
                                .background(HawkTheme.cardBackground)
                                .cornerRadius(HawkRadius.md)
                                .foregroundColor(HawkTheme.textPrimary)
                                .padding(.horizontal)

                            HStack(spacing: HawkSpacing.md) {
                                HawkButton("Cancel", style: .secondary, size: .medium) {
                                    showCreatePlaylistSheet = false
                                    newPlaylistName = ""
                                }

                                HawkButton("Create", style: .primary, size: .medium) {
                                    let name = newPlaylistName.trimmingCharacters(in: .whitespaces)
                                    if !name.isEmpty {
                                        Task {
                                            _ = await PlaylistStore.shared.createPlaylist(title: name)
                                            showCreatePlaylistSheet = false
                                            newPlaylistName = ""
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal)

                            Spacer()
                        }
                        .padding(.top, HawkSpacing.xl)
                    }
                    .navigationTitle("New Playlist")
                }
                .presentationDetents([.height(260)])
            }
            .task {
                let all = await LibraryAggregator.shared.allLibrarySongs()
                self.allLibrarySongs = all
                self.recentLibrarySongs = all.sorted { ($0.dateAdded ?? .distantPast) > ($1.dateAdded ?? .distantPast) }
            }
        }
    }
}

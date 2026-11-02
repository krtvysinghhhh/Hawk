import SwiftUI
import HawkCore
import HawkPlayback
import HawkSources

/// Primary tab navigation and root interface for HAWK.
public struct MainTabView: View {
    @State private var selectedTab = 0
    @State private var currentSong: Song? = Song(
        id: "demo_init",
        title: "Welcome to HAWK",
        artist: "Native Apple Music",
        duration: 215,
        artworkURL: nil
    )
    @State private var isPlaying = false
    @State private var showNowPlaying = false
    @State private var currentTime: TimeInterval = 45.0

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
            if let song = currentSong {
                MiniPlayerView(
                    song: song,
                    isPlaying: isPlaying,
                    onPlayPause: { isPlaying.toggle() },
                    onNext: {},
                    onTap: { showNowPlaying = true }
                )
                .padding(.bottom, 54) // Positioned directly over system bottom tab bar
            }
        }
        .fullScreenCover(isPresented: $showNowPlaying) {
            if let song = currentSong {
                NowPlayingView(
                    song: song,
                    isPlaying: isPlaying,
                    currentTime: currentTime,
                    duration: song.duration,
                    onPlayPause: { isPlaying.toggle() },
                    onNext: {},
                    onPrevious: {},
                    onSeek: { newTime in currentTime = newTime },
                    onDismiss: { showNowPlaying = false }
                )
            }
        }
    }
}

// MARK: - Placeholder Screens for Tabs
struct HomeView: View {
    var body: some View {
        NavigationStack {
            ZStack {
                HawkTheme.darkBackground.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        Text("Top Picks")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(HawkTheme.textPrimary)
                            .padding(.horizontal)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 16) {
                                ForEach(1...5, id: \.self) { i in
                                    VStack(alignment: .leading) {
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(HawkTheme.cardBackground)
                                            .frame(width: 140, height: 140)
                                            .overlay(Image(systemName: "music.note").foregroundColor(.white.opacity(0.4)))
                                        Text("Recommendation \(i)")
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundColor(HawkTheme.textPrimary)
                                        Text("HAWK Dynamic Mix")
                                            .font(.system(size: 12))
                                            .foregroundColor(HawkTheme.textSecondary)
                                    }
                                    .frame(width: 140)
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                    .padding(.top)
                }
            }
            .navigationTitle("Home")
        }
    }
}

struct ExploreView: View {
    var body: some View {
        NavigationStack {
            ZStack {
                HawkTheme.darkBackground.ignoresSafeArea()
                Text("Explore Moods & Charts")
                    .foregroundColor(HawkTheme.textSecondary)
            }
            .navigationTitle("Explore")
        }
    }
}

struct SearchView: View {
    @State private var query = ""

    var body: some View {
        NavigationStack {
            ZStack {
                HawkTheme.darkBackground.ignoresSafeArea()
                VStack {
                    if query.isEmpty {
                        Text("Search songs, artists, albums, or paste links")
                            .foregroundColor(HawkTheme.textTertiary)
                    } else {
                        Text("Searching for '\(query)'...")
                            .foregroundColor(HawkTheme.textSecondary)
                    }
                }
            }
            .navigationTitle("Search")
            .searchable(text: $query, prompt: "Search HAWK...")
        }
    }
}

struct LibraryView: View {
    var body: some View {
        NavigationStack {
            ZStack {
                HawkTheme.darkBackground.ignoresSafeArea()
                List {
                    NavigationLink(destination: Text("Favorites")) {
                        Label("Favorite Songs", systemImage: "heart.fill")
                    }
                    NavigationLink(destination: Text("Playlists")) {
                        Label("Playlists", systemImage: "music.note.list")
                    }
                    NavigationLink(destination: Text("Downloaded Music")) {
                        Label("Downloads", systemImage: "arrow.down.circle.fill")
                    }
                    NavigationLink(destination: Text("Local Audio Files")) {
                        Label("Local Files", systemImage: "folder.fill")
                    }
                    NavigationLink(destination: Text("Listening Replay")) {
                        Label("Replay & Statistics", systemImage: "chart.bar.xaxis")
                    }
                    NavigationLink(destination: Text("Settings")) {
                        Label("Settings", systemImage: "gearshape.fill")
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Library")
        }
    }
}

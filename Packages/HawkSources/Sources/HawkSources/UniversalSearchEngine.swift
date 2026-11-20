import Foundation
import HawkCore
import HawkNetworking

/// Structured results from a Universal Search across local, library, downloads, and streaming providers.
public struct UniversalSearchResults: Sendable {
    public let libraryMatches: [Song]
    public let playlistMatches: [Playlist]
    public let downloadMatches: [Song]
    public let streamingMatches: [Song]
    public let topResult: Song?

    public init(
        libraryMatches: [Song] = [],
        playlistMatches: [Playlist] = [],
        downloadMatches: [Song] = [],
        streamingMatches: [Song] = [],
        topResult: Song? = nil
    ) {
        self.libraryMatches = libraryMatches
        self.playlistMatches = playlistMatches
        self.downloadMatches = downloadMatches
        self.streamingMatches = streamingMatches
        self.topResult = topResult
    }

    public var isEmpty: Bool {
        libraryMatches.isEmpty && playlistMatches.isEmpty && downloadMatches.isEmpty && streamingMatches.isEmpty
    }
}

/// Actor orchestrating universal federated search across local library, downloads, playlists, and streaming engines.
public actor UniversalSearchEngine {
    public static let shared = UniversalSearchEngine()

    private let historyKey = "hawk_recent_search_history"
    private var searchHistory: [String] = []

    public init() {
        if let stored = UserDefaults.standard.stringArray(forKey: historyKey) {
            self.searchHistory = stored
        }
    }

    // MARK: - Search History Management
    public func getSearchHistory() -> [String] {
        return searchHistory
    }

    public func addSearchQuery(_ query: String) {
        let clean = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }

        searchHistory.removeAll(where: { $0.caseInsensitiveCompare(clean) == .orderedSame })
        searchHistory.insert(clean, at: 0)
        if searchHistory.count > 20 {
            searchHistory = Array(searchHistory.prefix(20))
        }
        UserDefaults.standard.set(searchHistory, forKey: historyKey)
    }

    public func removeSearchQuery(_ query: String) {
        searchHistory.removeAll(where: { $0 == query })
        UserDefaults.standard.set(searchHistory, forKey: historyKey)
    }

    public func clearSearchHistory() {
        searchHistory.removeAll()
        UserDefaults.standard.removeObject(forKey: historyKey)
    }

    // MARK: - Federated Universal Search Execution
    public func search(query: String) async -> UniversalSearchResults {
        let clean = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else {
            return UniversalSearchResults()
        }

        addSearchQuery(clean)

        // 1. Local Library & Playlists Search
        let allPlaylists = await PlaylistStore.shared.getAllPlaylists()
        let matchingPlaylists = allPlaylists.filter {
            $0.title.localizedCaseInsensitiveContains(clean)
        }

        var allLibSongs: [Song] = []
        for p in allPlaylists {
            allLibSongs.append(contentsOf: p.songs)
        }
        let matchingLibrary = TrackDeduplicator.deduplicate(allLibSongs).filter {
            $0.title.localizedCaseInsensitiveContains(clean) ||
            $0.artist.localizedCaseInsensitiveContains(clean)
        }

        // 2. Downloaded Songs Search
        let downloadedSongs = await DownloadManager.shared.getDownloadedSongs()
        let matchingDownloads = downloadedSongs.filter {
            $0.title.localizedCaseInsensitiveContains(clean) ||
            $0.artist.localizedCaseInsensitiveContains(clean)
        }

        // 3. Parallel Live Streaming Providers Search
        async let saavnResults = (try? JioSaavnSource().search(query: clean)) ?? []
        async let ytResults = (try? YouTubeSource().search(query: clean)) ?? []

        let (saavn, yt) = await (saavnResults, ytResults)
        let dedupedStreaming = TrackDeduplicator.deduplicate(saavn + yt)

        // 4. Resolve Top Result (Prioritize exact match in library or top streaming match)
        let exactMatch = matchingLibrary.first(where: {
            $0.title.localizedCaseInsensitiveCompare(clean) == .orderedSame
        })
        let topResult = exactMatch ?? matchingDownloads.first ?? dedupedStreaming.first

        return UniversalSearchResults(
            libraryMatches: matchingLibrary,
            playlistMatches: matchingPlaylists,
            downloadMatches: matchingDownloads,
            streamingMatches: dedupedStreaming,
            topResult: topResult
        )
    }
}

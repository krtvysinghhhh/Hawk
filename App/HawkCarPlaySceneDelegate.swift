#if canImport(CarPlay) && os(iOS)
import CarPlay
import UIKit
import HawkCore
import HawkPlayback
import HawkUI

/// Official native Apple CarPlay scene delegate for HAWK.
/// Provides tabbed in-car browsing (Listen Now, Playlists, Favourites, Library)
/// and full integration with CPNowPlayingTemplate.
public final class HawkCarPlaySceneDelegate: UIResponder, CPTemplateApplicationSceneDelegate {
    public var interfaceController: CPInterfaceController?

    public func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didConnect interfaceController: CPInterfaceController
    ) {
        self.interfaceController = interfaceController
        buildRootInterface()
    }

    public func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didDisconnect interfaceController: CPInterfaceController
    ) {
        self.interfaceController = nil
    }

    // MARK: - Root Interface Construction
    private func buildRootInterface() {
        guard let interfaceController = interfaceController else { return }

        let listenNowTab = buildListenNowTemplate()
        let favoritesTab = buildFavoritesTemplate()
        let playlistsTab = buildPlaylistsTemplate()
        let libraryTab = buildLibraryTemplate()

        let tabBar = CPTabBarTemplate(templates: [
            listenNowTab,
            favoritesTab,
            playlistsTab,
            libraryTab
        ])

        interfaceController.setRootTemplate(tabBar, animated: false, completion: nil)
        setupNowPlayingObservers()
    }

    // MARK: - Tab Templates

    /// Listen Now / Continue Listening tab
    private func buildListenNowTemplate() -> CPListTemplate {
        let template = CPListTemplate(
            title: "Listen Now",
            sections: [
                CPListSection(items: [
                    CPListItem(text: "Loading recommendations...", detailText: nil)
                ])
            ]
        )
        template.tabImage = UIImage(systemName: "play.circle.fill")

        Task { @MainActor [weak self, weak template] in
            guard let self = self, let template = template else { return }
            let favorites = await PlaylistStore.shared.getFavorites().songs
            var items: [CPListItem] = []

            for song in favorites.prefix(12) {
                let item = CPListItem(text: song.title, detailText: song.artist)
                item.handler = { [weak self] _, completion in
                    self?.playSong(song, context: favorites)
                    completion()
                }
                items.append(item)
            }

            if items.isEmpty {
                items.append(CPListItem(text: "No recent songs", detailText: "Favorite songs on your iPhone to see them here"))
            }

            template.updateSections([
                CPListSection(items: items, header: "Continue Listening", sectionIndexTitle: nil)
            ])
        }

        return template
    }

    /// Favourites Tab
    private func buildFavoritesTemplate() -> CPListTemplate {
        let template = CPListTemplate(
            title: "Favourites",
            sections: [
                CPListSection(items: [
                    CPListItem(text: "Loading favourites...", detailText: nil)
                ])
            ]
        )
        template.tabImage = UIImage(systemName: "heart.fill")

        Task { @MainActor [weak self, weak template] in
            guard let self = self, let template = template else { return }
            let favorites = await PlaylistStore.shared.getFavorites().songs
            var items: [CPListItem] = []

            for song in favorites {
                let item = CPListItem(text: song.title, detailText: song.artist)
                item.handler = { [weak self] _, completion in
                    self?.playSong(song, context: favorites)
                    completion()
                }
                items.append(item)
            }

            if items.isEmpty {
                items.append(CPListItem(text: "No favourites yet", detailText: "Tap the heart icon on any song on your iPhone"))
            }

            template.updateSections([
                CPListSection(items: items, header: "Favourite Tracks", sectionIndexTitle: nil)
            ])
        }

        return template
    }

    /// Playlists Tab
    private func buildPlaylistsTemplate() -> CPListTemplate {
        let template = CPListTemplate(
            title: "Playlists",
            sections: [
                CPListSection(items: [
                    CPListItem(text: "Loading playlists...", detailText: nil)
                ])
            ]
        )
        template.tabImage = UIImage(systemName: "music.note.list")

        Task { @MainActor [weak self, weak template] in
            guard let self = self, let template = template else { return }
            let playlists = await PlaylistStore.shared.getAllPlaylists()
            var items: [CPListItem] = []

            for p in playlists {
                let item = CPListItem(text: p.title, detailText: "\(p.songs.count) tracks")
                item.handler = { [weak self] _, completion in
                    self?.showPlaylistDetails(playlist: p)
                    completion()
                }
                items.append(item)
            }

            if items.isEmpty {
                items.append(CPListItem(text: "No custom playlists", detailText: "Create playlists in the HAWK Library"))
            }

            template.updateSections([
                CPListSection(items: items, header: "Your Playlists", sectionIndexTitle: nil)
            ])
        }

        return template
    }

    /// Library Hub Tab (Artists & Songs)
    private func buildLibraryTemplate() -> CPListTemplate {
        let artistsItem = CPListItem(text: "Artists", detailText: "Browse by artist")
        artistsItem.handler = { [weak self] _, completion in
            self?.showArtistsList()
            completion()
        }

        let queueItem = CPListItem(text: "Current Queue", detailText: "View upcoming tracks")
        queueItem.handler = { [weak self] _, completion in
            self?.showCurrentQueue()
            completion()
        }

        let template = CPListTemplate(
            title: "Library",
            sections: [
                CPListSection(items: [artistsItem, queueItem], header: "Music Library", sectionIndexTitle: nil)
            ]
        )
        template.tabImage = UIImage(systemName: "square.stack.fill")
        return template
    }

    // MARK: - Navigation Actions

    private func playSong(_ song: Song, context: [Song]) {
        PlaybackCoordinator.shared.play(song: song, context: context)
        pushNowPlaying()
    }

    private func pushNowPlaying() {
        interfaceController?.pushTemplate(CPNowPlayingTemplate.shared, animated: true, completion: nil)
    }

    private func showPlaylistDetails(playlist: Playlist) {
        var items: [CPListItem] = []
        for song in playlist.songs {
            let item = CPListItem(text: song.title, detailText: song.artist)
            item.handler = { [weak self] _, completion in
                self?.playSong(song, context: playlist.songs)
                completion()
            }
            items.append(item)
        }

        if items.isEmpty {
            items.append(CPListItem(text: "Playlist is empty", detailText: nil))
        }

        let detailTemplate = CPListTemplate(
            title: playlist.title,
            sections: [CPListSection(items: items)]
        )
        interfaceController?.pushTemplate(detailTemplate, animated: true, completion: nil)
    }

    private func showArtistsList() {
        Task { @MainActor [weak self] in
            guard let self = self else { return }
            let artistItems = await CarPlaySyncManager.shared.fetchArtists()
            var listItems: [CPListItem] = []

            for a in artistItems {
                let item = CPListItem(text: a.title, detailText: a.subtitle)
                item.handler = { [weak self] _, completion in
                    self?.showArtistSongs(artist: a.title)
                    completion()
                }
                listItems.append(item)
            }

            if listItems.isEmpty {
                listItems.append(CPListItem(text: "No artists found", detailText: "Add music to your library first"))
            }

            let template = CPListTemplate(
                title: "Artists",
                sections: [CPListSection(items: listItems)]
            )
            self.interfaceController?.pushTemplate(template, animated: true, completion: nil)
        }
    }

    private func showArtistSongs(artist: String) {
        Task { @MainActor [weak self] in
            guard let self = self else { return }
            let favs = await PlaylistStore.shared.getFavorites().songs
            var all: [Song] = favs
            for p in await PlaylistStore.shared.getAllPlaylists() {
                all.append(contentsOf: p.songs)
            }

            let matching = all.filter { $0.artist.localizedCaseInsensitiveContains(artist) }
            var items: [CPListItem] = []
            for song in matching {
                let item = CPListItem(text: song.title, detailText: song.artist)
                item.handler = { [weak self] _, completion in
                    self?.playSong(song, context: matching)
                    completion()
                }
                items.append(item)
            }

            let template = CPListTemplate(
                title: artist,
                sections: [CPListSection(items: items)]
            )
            self.interfaceController?.pushTemplate(template, animated: true, completion: nil)
        }
    }

    private func showCurrentQueue() {
        let queue = PlaybackCoordinator.shared.queue
        var items: [CPListItem] = []
        for song in queue {
            let item = CPListItem(text: song.title, detailText: song.artist)
            item.handler = { [weak self] _, completion in
                self?.playSong(song, context: queue)
                completion()
            }
            items.append(item)
        }

        if items.isEmpty {
            items.append(CPListItem(text: "Queue is empty", detailText: nil))
        }

        let template = CPListTemplate(
            title: "Current Queue",
            sections: [CPListSection(items: items)]
        )
        interfaceController?.pushTemplate(template, animated: true, completion: nil)
    }

    private func setupNowPlayingObservers() {
        CPNowPlayingTemplate.shared.isUpNextButtonEnabled = true
        CPNowPlayingTemplate.shared.isAlbumArtistButtonEnabled = true
    }
}
#endif

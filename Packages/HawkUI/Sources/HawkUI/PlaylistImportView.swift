import SwiftUI
import UniformTypeIdentifiers
import HawkCore
import HawkSources

/// Dedicated playlist portability interface providing file/URL import, track matching, and interactive preview.
public struct PlaylistImportView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var importSourceTab: Int = 0 // 0: URL, 1: File
    @State private var urlInput: String = ""
    @State private var isProcessing: Bool = false
    @State private var progressMessage: String = ""
    @State private var importResult: PlaylistImportResult?
    @State private var editablePlaylistTitle: String = ""
    @State private var showFilePicker: Bool = false
    @State private var errorMessage: String?

    public init() {}

    public var body: some View {
        NavigationStack {
            ZStack {
                HawkTheme.darkBackground.ignoresSafeArea()

                VStack(spacing: 0) {
                    if let result = importResult {
                        // MARK: - Step 2: Interactive Match Preview & Confirmation
                        previewContent(result: result)
                    } else {
                        // MARK: - Step 1: Input Source (Link or File)
                        inputSelectionContent
                    }
                }
            }
            .navigationTitle("Import Playlist")
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(HawkTheme.textSecondary)
                }
            }
            .fileImporter(
                isPresented: $showFilePicker,
                allowedContentTypes: [.item],
                allowsMultipleSelection: false
            ) { result in
                handleFilePicked(result: result)
            }
        }
    }

    // MARK: - Step 1 Content
    private var inputSelectionContent: some View {
        VStack(spacing: 24) {
            Picker("Source", selection: $importSourceTab) {
                Text("Playlist URL").tag(0)
                Text("Playlist File (.m3u/.json)").tag(1)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.top, 16)

            if importSourceTab == 0 {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Enter Public Playlist Link")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(HawkTheme.textPrimary)

                    TextField("https://open.spotify.com/playlist/...", text: $urlInput)
                        .padding()
                        .background(HawkTheme.cardBackground)
                        .cornerRadius(12)
                        .foregroundColor(HawkTheme.textPrimary)
                        .autocorrectionDisabled()
#if os(iOS)
                        .textInputAutocapitalization(.never)
#endif

                    Text("Supports Spotify playlist links, public YouTube Music lists, and web M3U/M3U8 playlists.")
                        .font(.caption)
                        .foregroundColor(HawkTheme.textTertiary)

                    if let err = errorMessage {
                        Text(err)
                            .font(.caption)
                            .foregroundColor(.red)
                    }

                    Button {
                        processURLInput()
                    } label: {
                        HStack {
                            if isProcessing {
                                ProgressView()
                                    .tint(.white)
                                    .padding(.trailing, 6)
                            }
                            Text(isProcessing ? progressMessage : "Fetch & Match Tracks")
                                .font(.headline)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(urlInput.trimmingCharacters(in: .whitespaces).isEmpty ? Color.gray.opacity(0.3) : HawkTheme.primaryAccent)
                        .cornerRadius(12)
                    }
                    .disabled(urlInput.trimmingCharacters(in: .whitespaces).isEmpty || isProcessing)
                    .padding(.top, 10)
                }
                .padding(.horizontal)
            } else {
                VStack(spacing: 20) {
                    Image(systemName: "doc.badge.plus")
                        .font(.system(size: 48))
                        .foregroundColor(HawkTheme.primaryAccent)
                        .padding(.top, 20)

                    Text("Import Local Playlist File")
                        .font(.headline)
                        .foregroundColor(HawkTheme.textPrimary)

                    Text("Select an M3U, M3U8, or JSON playlist file from your device Files app or iCloud Drive.")
                        .font(.caption)
                        .foregroundColor(HawkTheme.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 30)

                    Button {
                        showFilePicker = true
                    } label: {
                        Label("Choose Playlist File", systemImage: "folder")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(HawkTheme.primaryAccent)
                            .cornerRadius(12)
                    }
                    .padding(.horizontal)
                    .padding(.top, 10)

                    if isProcessing {
                        ProgressView(progressMessage)
                            .tint(HawkTheme.primaryAccent)
                            .foregroundColor(HawkTheme.textSecondary)
                    }

                    if let err = errorMessage {
                        Text(err)
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
            }

            Spacer()
        }
    }

    // MARK: - Step 2 Preview Content
    private func previewContent(result: PlaylistImportResult) -> some View {
        VStack(spacing: 16) {
            // Header stats
            VStack(alignment: .leading, spacing: 8) {
                TextField("Playlist Name", text: $editablePlaylistTitle)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(HawkTheme.textPrimary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(HawkTheme.cardBackground)
                    .cornerRadius(8)

                HStack(spacing: 12) {
                    badge(title: "\(result.matchedTracks.count) Matched", color: .green)
                    if !result.ambiguousTracks.isEmpty {
                        badge(title: "\(result.ambiguousTracks.count) Review", color: .orange)
                    }
                    if !result.missingTracks.isEmpty {
                        badge(title: "\(result.missingTracks.count) Unavailable", color: .gray)
                    }
                }
                .padding(.top, 2)
            }
            .padding(.horizontal)
            .padding(.top, 12)

            // Tracks Preview List
            List {
                Section(header: Text("Matched Songs (\(result.matchedTracks.count))").foregroundColor(HawkTheme.textSecondary)) {
                    ForEach(result.matchedTracks) { song in
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
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
                        }
                    }
                }

                if !result.ambiguousTracks.isEmpty {
                    Section(header: Text("Ambiguous Matches (\(result.ambiguousTracks.count))").foregroundColor(HawkTheme.textSecondary)) {
                        ForEach(result.ambiguousTracks) { item in
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.orange)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.title)
                                        .font(.system(size: 15, weight: .medium))
                                        .foregroundColor(HawkTheme.textPrimary)
                                    Text("\(item.artist) -> Matched as \(item.matchedSong?.title ?? "") (\(Int(item.matchConfidence * 100))%)")
                                        .font(.system(size: 12))
                                        .foregroundColor(HawkTheme.textSecondary)
                                }
                            }
                        }
                    }
                }

                if !result.missingTracks.isEmpty {
                    Section(header: Text("Retained as Metadata (\(result.missingTracks.count))").foregroundColor(HawkTheme.textSecondary)) {
                        ForEach(result.missingTracks) { item in
                            HStack {
                                Image(systemName: "minus.circle")
                                    .foregroundColor(.gray)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.title)
                                        .font(.system(size: 15, weight: .medium))
                                        .foregroundColor(HawkTheme.textSecondary)
                                    Text(item.artist)
                                        .font(.system(size: 12))
                                        .foregroundColor(HawkTheme.textTertiary)
                                }
                            }
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)

            // Import CTA
            Button {
                commitImport(result: result)
            } label: {
                Text("Save to HAWK Library")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(HawkTheme.primaryAccent)
                    .cornerRadius(12)
            }
            .padding(.horizontal)
            .padding(.bottom, 12)
        }
    }

    @ViewBuilder
    private func badge(title: String, color: Color) -> some View {
        Text(title)
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(color.opacity(0.18))
            .clipShape(Capsule())
    }

    // MARK: - Actions
    private func processURLInput() {
        guard !urlInput.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        isProcessing = true
        progressMessage = "Reading playlist metadata..."
        errorMessage = nil

        Task {
            do {
                let parsed = try await UniversalPlaylistImporter.fetchTracksFromURL(urlInput)
                progressMessage = "Matching \(parsed.tracks.count) tracks..."

                let result = await UniversalPlaylistImporter.matchAndImport(
                    tracks: parsed.tracks,
                    playlistTitle: parsed.title
                )

                self.editablePlaylistTitle = result.playlistTitle
                self.importResult = result
                self.isProcessing = false
            } catch {
                self.errorMessage = "Failed to import from URL: \(error.localizedDescription)"
                self.isProcessing = false
            }
        }
    }

    private func handleFilePicked(result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            guard url.startAccessingSecurityScopedResource() else { return }
            defer { url.stopAccessingSecurityScopedResource() }

            isProcessing = true
            progressMessage = "Parsing file..."
            errorMessage = nil

            Task {
                do {
                    let data = try Data(contentsOf: url)
                    if let stringContent = String(data: data, encoding: .utf8), stringContent.contains("#EXTM3U") {
                        let parsed = UniversalPlaylistImporter.parseM3U(content: stringContent)
                        progressMessage = "Matching \(parsed.tracks.count) tracks..."
                        let res = await UniversalPlaylistImporter.matchAndImport(tracks: parsed.tracks, playlistTitle: parsed.title)
                        self.editablePlaylistTitle = res.playlistTitle
                        self.importResult = res
                    } else if let jsonPlaylist = try? UniversalPlaylistImporter.parseJSON(data: data) {
                        let tracks = jsonPlaylist.songs.map { ($0.title, $0.artist, $0.duration) }
                        progressMessage = "Matching \(tracks.count) tracks..."
                        let res = await UniversalPlaylistImporter.matchAndImport(tracks: tracks, playlistTitle: jsonPlaylist.title)
                        self.editablePlaylistTitle = res.playlistTitle
                        self.importResult = res
                    } else {
                        self.errorMessage = "Unsupported file content format."
                    }
                    self.isProcessing = false
                } catch {
                    self.errorMessage = "File read error: \(error.localizedDescription)"
                    self.isProcessing = false
                }
            }

        case .failure(let err):
            self.errorMessage = err.localizedDescription
        }
    }

    private func commitImport(result: PlaylistImportResult) {
        Task {
            // Combine matched tracks + ambiguous approved tracks
            var finalSongs = result.matchedTracks
            for amb in result.ambiguousTracks {
                if let song = amb.matchedSong, !finalSongs.contains(where: { $0.id == song.id }) {
                    finalSongs.append(song)
                }
            }

            let title = editablePlaylistTitle.trimmingCharacters(in: .whitespaces).isEmpty
                ? result.playlistTitle : editablePlaylistTitle

            _ = await PlaylistStore.shared.createPlaylist(title: title, initialSongs: finalSongs)
            dismiss()
        }
    }
}

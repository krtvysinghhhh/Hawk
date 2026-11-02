import Foundation
import HawkCore

public enum DownloadState: Sendable, Equatable {
    case idle
    case queued
    case downloading(progress: Double)
    case completed(localURL: URL)
    case failed(String)

    public var isCompleted: Bool {
        if case .completed = self { return true }
        return false
    }

    public var isDownloading: Bool {
        if case .downloading = self { return true }
        return false
    }
}

/// Actor orchestrating offline song downloads and sandboxed cache management.
public actor DownloadManager {
    public static let shared = DownloadManager()

    private let downloadsDirectory: URL
    private let indexFileURL: URL
    private var activeStates: [String: DownloadState] = [:]
    private var downloadedSongs: [String: Song] = [:]

    public init(downloadsDirectory: URL? = nil) {
        let dir: URL
        if let customDir = downloadsDirectory {
            dir = customDir
        } else {
            let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            dir = docs.appendingPathComponent("Downloads", isDirectory: true)
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        self.downloadsDirectory = dir
        let indexURL = dir.appendingPathComponent("downloads_index.json")
        self.indexFileURL = indexURL

        var loaded: [String: Song] = [:]
        if let data = try? Data(contentsOf: indexURL),
           let list = try? JSONDecoder().decode([Song].self, from: data) {
            for song in list {
                if let url = song.localFileURL, FileManager.default.fileExists(atPath: url.path) {
                    loaded[song.id] = song
                }
            }
        }
        self.downloadedSongs = loaded
    }

    // MARK: - Query Status
    public func getDownloadedSongs() -> [Song] {
        Array(downloadedSongs.values)
    }

    public func isDownloaded(songId: String) -> Bool {
        guard let song = downloadedSongs[songId], let url = song.localFileURL else { return false }
        return FileManager.default.fileExists(atPath: url.path)
    }

    public func getState(songId: String) -> DownloadState {
        if let state = activeStates[songId] {
            return state
        }
        if isDownloaded(songId: songId), let song = downloadedSongs[songId], let url = song.localFileURL {
            return .completed(localURL: url)
        }
        return .idle
    }

    // MARK: - Download Lifecycle
    public func download(song: Song) async throws {
        if isDownloaded(songId: song.id) {
            return
        }

        activeStates[song.id] = .queued

        // Resolve stream URL
        let stream = try await SourceResolver.shared.resolve(song: song, qualityCeiling: .high)
        activeStates[song.id] = .downloading(progress: 0.1)

        let fileExtension = stream.url.pathExtension.isEmpty ? "m4a" : stream.url.pathExtension
        let destinationURL = downloadsDirectory.appendingPathComponent("\(song.id).\(fileExtension)")

        // Download stream bytes
        let (tempURL, response) = try await URLSession.shared.download(from: stream.url)

        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            activeStates[song.id] = .failed("Invalid HTTP response during download")
            throw HawkError.networkError("Download failed with HTTP status")
        }

        // Move to permanent destination
        if FileManager.default.fileExists(atPath: destinationURL.path) {
            try? FileManager.default.removeItem(at: destinationURL)
        }
        try FileManager.default.moveItem(at: tempURL, to: destinationURL)

        // Update song with local file URL
        let downloadedSong = Song(
            id: song.id,
            title: song.title,
            artist: song.artist,
            artists: song.artists,
            albumTitle: song.albumTitle,
            albumId: song.albumId,
            duration: song.duration,
            durationText: song.durationText,
            artworkURL: song.artworkURL,
            queueTier: song.queueTier,
            queueEntryId: song.queueEntryId,
            localFileURL: destinationURL,
            sourceQuality: stream.quality,
            isVideo: song.isVideo,
            isLiked: song.isLiked
        )

        downloadedSongs[song.id] = downloadedSong
        activeStates[song.id] = .completed(localURL: destinationURL)
        saveIndex()
    }

    public func deleteDownload(songId: String) {
        guard let song = downloadedSongs[songId], let url = song.localFileURL else { return }
        try? FileManager.default.removeItem(at: url)
        downloadedSongs.removeValue(forKey: songId)
        activeStates.removeValue(forKey: songId)
        saveIndex()
    }

    public func clearAllDownloads() {
        for (_, song) in downloadedSongs {
            if let url = song.localFileURL {
                try? FileManager.default.removeItem(at: url)
            }
        }
        downloadedSongs.removeAll()
        activeStates.removeAll()
        saveIndex()
    }

    public func totalDownloadedBytes() -> Int64 {
        var total: Int64 = 0
        for (_, song) in downloadedSongs {
            guard let url = song.localFileURL,
                  let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
                  let size = attrs[.size] as? Int64 else { continue }
            total += size
        }
        return total
    }

    // MARK: - Persistence
    private func saveIndex() {
        guard let data = try? JSONEncoder().encode(Array(downloadedSongs.values)) else { return }
        try? data.write(to: indexFileURL, options: .atomic)
    }
}

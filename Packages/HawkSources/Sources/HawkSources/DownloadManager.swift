import Foundation
import HawkCore

public enum DownloadState: Sendable, Equatable {
    case idle
    case queued
    case downloading(progress: Double)
    case paused(resumeData: Data?)
    case completed(localURL: URL)
    case failed(String)
    case cancelled

    public var isCompleted: Bool {
        if case .completed = self { return true }
        return false
    }

    public var isDownloading: Bool {
        if case .downloading = self { return true }
        return false
    }

    public var isPaused: Bool {
        if case .paused = self { return true }
        return false
    }
}

/// Actor orchestrating offline song downloads, lifecycle management, progress tracking, and sandboxed storage.
public actor DownloadManager {
    public static let shared = DownloadManager()

    private let downloadsDirectory: URL
    private let indexFileURL: URL
    private var activeStates: [String: DownloadState] = [:]
    private var downloadedSongs: [String: Song] = [:]
    private var activeDownloadTasks: [String: Task<Void, Error>] = [:]

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
                if let url = song.localFileURL,
                   FileManager.default.fileExists(atPath: url.path),
                   let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
                   (attrs[.size] as? Int64 ?? 0) > 1024 {
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
        guard FileManager.default.fileExists(atPath: url.path) else { return false }
        let size = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int64) ?? 0
        return size > 1024
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

        // Prevent duplicate simultaneous downloads: await in-flight task if already running
        if let existingTask = activeDownloadTasks[song.id] {
            try await existingTask.value
            return
        }

        activeStates[song.id] = .queued

        let task = Task<Void, Error> { [weak self] in
            guard let self = self else { return }

            // 1. Resolve stream URL
            let stream = try await SourceResolver.shared.resolve(song: song, qualityCeiling: .high)
            try Task.checkCancellation()

            await self.updateState(songId: song.id, state: .downloading(progress: 0.25))

            let safeId = song.id.replacingOccurrences(of: "..", with: "").components(separatedBy: CharacterSet.alphanumerics.inverted).joined(separator: "_")
            let fileExtension = stream.url.pathExtension.isEmpty ? "m4a" : stream.url.pathExtension
            let destinationURL = self.downloadsDirectory.appendingPathComponent("\(safeId).\(fileExtension)")

            // 2. Fetch media bytes
            let (tempURL, response) = try await URLSession.shared.download(from: stream.url)
            try Task.checkCancellation()

            guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
                await self.updateState(songId: song.id, state: .failed("HTTP response status error"))
                throw HawkError.networkError("Download failed with HTTP status")
            }

            await self.updateState(songId: song.id, state: .downloading(progress: 0.85))

            // 3. Move and verify file integrity
            if FileManager.default.fileExists(atPath: destinationURL.path) {
                try? FileManager.default.removeItem(at: destinationURL)
            }
            try FileManager.default.moveItem(at: tempURL, to: destinationURL)

            guard let attrs = try? FileManager.default.attributesOfItem(atPath: destinationURL.path),
                  let fileSize = attrs[.size] as? Int64, fileSize > 1024 else {
                try? FileManager.default.removeItem(at: destinationURL)
                await self.updateState(songId: song.id, state: .failed("File integrity check failed: zero-byte file"))
                throw HawkError.storageError("Downloaded audio file was empty or corrupted")
            }

            // 4. Update index
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
                isLiked: song.isLiked,
                isrc: song.isrc,
                mediaUri: song.mediaUri,
                sourceId: song.sourceId,
                version: song.version,
                providerIdentifiers: song.providerIdentifiers,
                explicitStatus: song.explicitStatus
            )

            await self.saveCompletedDownload(song: downloadedSong, url: destinationURL)
        }

        activeDownloadTasks[song.id] = task

        do {
            try await task.value
            activeDownloadTasks.removeValue(forKey: song.id)
        } catch {
            activeDownloadTasks.removeValue(forKey: song.id)
            if Task.isCancelled {
                activeStates[song.id] = .cancelled
            } else {
                activeStates[song.id] = .failed(error.localizedDescription)
                throw error
            }
        }
    }

    private func updateState(songId: String, state: DownloadState) {
        self.activeStates[songId] = state
    }

    private func saveCompletedDownload(song: Song, url: URL) {
        downloadedSongs[song.id] = song
        activeStates[song.id] = .completed(localURL: url)
        saveIndex()
    }

    public func pause(songId: String) {
        if let task = activeDownloadTasks[songId] {
            task.cancel()
            activeDownloadTasks.removeValue(forKey: songId)
            activeStates[songId] = .paused(resumeData: nil)
        }
    }

    public func resume(song: Song) async throws {
        try await download(song: song)
    }

    public func cancel(songId: String) {
        if let task = activeDownloadTasks[songId] {
            task.cancel()
            activeDownloadTasks.removeValue(forKey: songId)
        }
        activeStates[songId] = .cancelled
    }

    public func retry(song: Song) async throws {
        cancel(songId: song.id)
        try await download(song: song)
    }

    public func deleteDownload(songId: String) {
        cancel(songId: songId)
        guard let song = downloadedSongs[songId], let url = song.localFileURL else { return }
        try? FileManager.default.removeItem(at: url)
        downloadedSongs.removeValue(forKey: songId)
        activeStates.removeValue(forKey: songId)
        saveIndex()
    }

    public func clearAllDownloads() {
        for (id, _) in activeDownloadTasks {
            cancel(songId: id)
        }
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

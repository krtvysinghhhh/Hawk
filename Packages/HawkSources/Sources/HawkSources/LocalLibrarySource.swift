import Foundation
import AVFoundation
import HawkCore

/// Music provider scanning and importing audio files from the local iOS sandbox directory.
public final class LocalLibrarySource: MusicSourceProvider, @unchecked Sendable {
    public let sourceId = "local"
    public let displayName = "Local Files"
    public let capabilities: Set<SourceCapability> = [
        .search, .streamResolution, .highResolutionAudio
    ]

    private let libraryDirectory: URL

    public init(libraryDirectory: URL? = nil) {
        if let dir = libraryDirectory {
            self.libraryDirectory = dir
        } else {
            let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            self.libraryDirectory = docs.appendingPathComponent("LocalMusic", isDirectory: true)
            try? FileManager.default.createDirectory(at: self.libraryDirectory, withIntermediateDirectories: true)
        }
    }

    /// Scans the local music directory and indexes all playable audio files.
    public func scanLocalTracks() async -> [Song] {
        var collectedURLs: [URL] = []
        if let enumerator = FileManager.default.enumerator(
            at: libraryDirectory,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) {
            while let fileURL = enumerator.nextObject() as? URL {
                collectedURLs.append(fileURL)
            }
        }

        let supportedExtensions = ["mp3", "m4a", "flac", "wav", "alac", "aac", "aiff"]
        var songs: [Song] = []

        for fileURL in collectedURLs {
            guard supportedExtensions.contains(fileURL.pathExtension.lowercased()) else { continue }
            if let song = await extractMetadata(from: fileURL) {
                songs.append(song)
            }
        }

        return songs
    }

    public func search(query: String, filter: SearchFilter = .all) async throws -> [Song] {
        let all = await scanLocalTracks()
        guard !query.isEmpty else { return all }
        let q = query.lowercased()
        return all.filter {
            $0.title.lowercased().contains(q) || $0.artist.lowercased().contains(q)
        }
    }

    public func resolveStream(song: Song, qualityCeiling: AudioQuality = .lossless) async throws -> SourceStream {
        guard let localURL = song.localFileURL ?? URL(string: song.id),
              FileManager.default.fileExists(atPath: localURL.path) else {
            throw HawkError.streamNotFound(song.id)
        }

        return SourceStream(
            url: localURL,
            quality: .lossless,
            mimeType: "audio/\(localURL.pathExtension)",
            sourceId: sourceId
        )
    }

    private func extractMetadata(from fileURL: URL) async -> Song? {
        let asset = AVURLAsset(url: fileURL)
        var title = fileURL.deletingPathExtension().lastPathComponent
        var artist = "Local Artist"
        var duration: TimeInterval = 0

        if let dur = try? await asset.load(.duration) {
            duration = CMTimeGetSeconds(dur)
        }

        if let commonMetadata = try? await asset.load(.commonMetadata) {
            for item in commonMetadata {
                if let key = item.commonKey?.rawValue {
                    if key == AVMetadataKey.commonKeyTitle.rawValue,
                       let val = try? await item.load(.stringValue) {
                        title = val
                    } else if key == AVMetadataKey.commonKeyArtist.rawValue,
                              let val = try? await item.load(.stringValue) {
                        artist = val
                    }
                }
            }
        }

        return Song(
            id: fileURL.absoluteString,
            title: title,
            artist: artist,
            duration: duration,
            localFileURL: fileURL,
            sourceQuality: .lossless
        )
    }
}

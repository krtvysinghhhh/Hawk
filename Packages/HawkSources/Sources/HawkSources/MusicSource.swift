import Foundation
import HawkCore

/// Representation of an openable audio stream and its technical properties.
public struct SourceStream: Sendable {
    public let url: URL
    public let quality: AudioQuality
    public let mimeType: String
    public let headers: [String: String]
    public let duration: TimeInterval?
    public let sourceId: String

    public init(
        url: URL,
        quality: AudioQuality = .standard,
        mimeType: String = "audio/mp4",
        headers: [String: String] = [:],
        duration: TimeInterval? = nil,
        sourceId: String = "youtube"
    ) {
        self.url = url
        self.quality = quality
        self.mimeType = mimeType
        self.headers = headers
        self.duration = duration
        self.sourceId = sourceId
    }
}

public enum SourceCapability: Sendable, Hashable {
    case search
    case streamResolution
    case highResolutionAudio
    case lyrics
    case albumDetail
    case artistDetail
}

/// Abstract contract for all musical content providers in HAWK.
public protocol MusicSourceProvider: Sendable {
    var sourceId: String { get }
    var displayName: String { get }
    var capabilities: Set<SourceCapability> { get }

    func search(query: String, filter: SearchFilter) async throws -> [Song]
    func resolveStream(song: Song, qualityCeiling: AudioQuality) async throws -> SourceStream
}

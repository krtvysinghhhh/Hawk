import Foundation

/// One credited artist, with optional channel identifier for page navigation.
public struct ArtistRef: Identifiable, Codable, Sendable, Hashable {
    public var id: String { browseId ?? name }
    public let name: String
    public let browseId: String?

    public init(name: String, browseId: String? = nil) {
        self.name = name
        self.browseId = browseId
    }
}

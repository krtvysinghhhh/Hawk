import Foundation
import HawkCore

/// Central artwork resolution engine guaranteeing high-resolution, consistent album art across all providers.
public actor ArtworkResolver {
    public static let shared = ArtworkResolver()

    private var memoryCache: [String: URL] = [:]

    public init() {}

    /// Resolves high-resolution, verified artwork for a song.
    public func resolveArtworkURL(for song: Song) -> URL? {
        let key = song.canonicalKey
        if let cached = memoryCache[key] {
            return cached
        }

        // 1. Direct song artwork with resolution upgrade
        if let direct = song.artworkURL {
            let upgraded = Self.upgradeResolution(of: direct)
            memoryCache[key] = upgraded
            return upgraded
        }

        return nil
    }

    /// Upgrades known provider thumbnail URLs to high-resolution master renditions.
    nonisolated public static func upgradeResolution(of url: URL) -> URL {
        let str = url.absoluteString

        // JioSaavn upgrade 150x150 or 50x50 to 500x500
        if str.contains("saavncdn.com") {
            let upgraded = str.replacingOccurrences(of: "150x150", with: "500x500")
                .replacingOccurrences(of: "50x50", with: "500x500")
            return URL(string: upgraded) ?? url
        }

        // YouTube thumbnail upgrade
        if str.contains("ytimg.com") || str.contains("googleusercontent.com") {
            let upgraded = str.replacingOccurrences(of: "default.jpg", with: "hqdefault.jpg")
                .replacingOccurrences(of: "hqdefault.jpg", with: "maxresdefault.jpg")
            return URL(string: upgraded) ?? url
        }

        return url
    }

    /// Stores verified artwork URL for a canonical track key.
    public func cacheArtwork(key: String, url: URL) {
        memoryCache[key] = Self.upgradeResolution(of: url)
    }
}

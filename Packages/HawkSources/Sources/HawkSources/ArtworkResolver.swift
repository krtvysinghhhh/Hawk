import Foundation
import HawkCore
import HawkSecurity
import HawkNetworking

/// Production-grade artwork resolution and caching engine.
/// Provides URL resolution upgrading, two-tier (memory & disk) caching,
/// in-flight network request deduplication, and cache size bounds.
public actor ArtworkResolver {
    public static let shared = ArtworkResolver()

    private var urlMemoryCache: [String: URL] = [:]
    private let dataMemoryCache = NSCache<NSString, NSData>()
    private var inFlightTasks: [URL: Task<Data?, Never>] = [:]

    private let diskCacheDirectory: URL
    private let maxDiskCacheSizeBytes: Int64 = 150 * 1024 * 1024 // 150 MB
    private let maxCacheAgeSeconds: TimeInterval = 14 * 86400 // 14 Days

    public init(customCacheDirectory: URL? = nil) {
        if let custom = customCacheDirectory {
            self.diskCacheDirectory = custom
        } else {
            let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
            self.diskCacheDirectory = caches.appendingPathComponent("ArtworkCache", isDirectory: true)
        }

        try? FileManager.default.createDirectory(at: self.diskCacheDirectory, withIntermediateDirectories: true)

        // Configure Memory Cache bounds
        self.dataMemoryCache.countLimit = 200
        self.dataMemoryCache.totalCostLimit = 50 * 1024 * 1024 // 50 MB
    }

    // MARK: - High-Resolution URL Upgrades
    /// Resolves high-resolution, verified artwork for a song.
    public func resolveArtworkURL(for song: Song) -> URL? {
        let key = song.canonicalKey
        if let cached = urlMemoryCache[key] {
            return cached
        }

        if let direct = song.artworkURL {
            let upgraded = Self.upgradeResolution(of: direct)
            urlMemoryCache[key] = upgraded
            return upgraded
        }

        return nil
    }

    /// Upgrades known provider thumbnail URLs to high-resolution master renditions.
    nonisolated public static func upgradeResolution(of url: URL) -> URL {
        let str = url.absoluteString

        // 1. JioSaavn CDN (50x50, 150x150 -> 500x500)
        if str.contains("saavncdn.com") {
            let upgraded = str.replacingOccurrences(of: "150x150", with: "500x500")
                .replacingOccurrences(of: "50x50", with: "500x500")
            return URL(string: upgraded) ?? url
        }

        // 2. YouTube & Google User Content CDN (default, mqdefault, hqdefault, sddefault -> maxresdefault)
        if str.contains("ytimg.com") || str.contains("googleusercontent.com") {
            let upgraded = str
                .replacingOccurrences(of: "default.jpg", with: "maxresdefault.jpg")
                .replacingOccurrences(of: "mqdefault.jpg", with: "maxresdefault.jpg")
                .replacingOccurrences(of: "hqdefault.jpg", with: "maxresdefault.jpg")
                .replacingOccurrences(of: "sddefault.jpg", with: "maxresdefault.jpg")
            return URL(string: upgraded) ?? url
        }

        // 3. Apple Music / iTunes CDN (100x100bb -> 600x600bb)
        if str.contains("mzstatic.com") {
            let upgraded = str
                .replacingOccurrences(of: "100x100bb", with: "600x600bb")
                .replacingOccurrences(of: "200x200bb", with: "600x600bb")
                .replacingOccurrences(of: "300x300bb", with: "600x600bb")
            return URL(string: upgraded) ?? url
        }

        return url
    }

    /// Caches a resolved URL for a canonical track key.
    public func cacheArtwork(key: String, url: URL) {
        urlMemoryCache[key] = Self.upgradeResolution(of: url)
    }

    // MARK: - Data Fetching with In-Flight Deduplication & Two-Tier Caching
    /// Loads artwork image binary data through memory cache, persistent disk cache, or network.
    public func loadArtworkData(for url: URL) async -> Data? {
        let upgraded = Self.upgradeResolution(of: url)
        let cacheKey = cacheKeyForURL(upgraded)

        // 1. Check Tier 1 Memory Cache
        if let memoryData = dataMemoryCache.object(forKey: cacheKey as NSString) {
            return memoryData as Data
        }

        // 2. Check Tier 2 Persistent Disk Cache
        let diskURL = diskFileURL(for: cacheKey)
        if let diskData = try? Data(contentsOf: diskURL) {
            dataMemoryCache.setObject(diskData as NSData, forKey: cacheKey as NSString, cost: diskData.count)
            return diskData
        }

        // 3. Deduplicate In-Flight Requests
        if let ongoing = inFlightTasks[upgraded] {
            return await ongoing.value
        }

        // 4. Download from Network with Safe Fallback to Original URL
        let task = Task<Data?, Never> { [weak self] () -> Data? in
            guard let self else { return nil }
            var req = URLRequest(url: upgraded)
            req.timeoutInterval = 15.0
            req.cachePolicy = .useProtocolCachePolicy

            do {
                let (data, response) = try await URLSession.shared.data(for: req)
                if let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) {
                    await self.persistToCache(data: data, cacheKey: cacheKey)
                    return data
                }
            } catch {
                // Proceed to fallback on network error or timeout
            }

            // Fallback to original URL if upgraded URL failed or returned non-200
            if upgraded != url {
                var fallbackReq = URLRequest(url: url)
                fallbackReq.timeoutInterval = 10.0
                if let (fallbackData, fallbackResp) = try? await URLSession.shared.data(for: fallbackReq),
                   let http = fallbackResp as? HTTPURLResponse, (200...299).contains(http.statusCode) {
                    let fallbackKey = self.cacheKeyForURL(url)
                    await self.persistToCache(data: fallbackData, cacheKey: fallbackKey)
                    return fallbackData
                }
            }

            return nil
        }

        inFlightTasks[upgraded] = task
        let result = await task.value
        inFlightTasks.removeValue(forKey: upgraded)
        return result
    }

    private func persistToCache(data: Data, cacheKey: String) {
        // Store in Tier 1 Memory Cache
        dataMemoryCache.setObject(data as NSData, forKey: cacheKey as NSString, cost: data.count)

        // Store in Tier 2 Disk Cache
        let file = diskFileURL(for: cacheKey)
        try? data.write(to: file, options: .atomic)
    }

    // MARK: - Cache Eviction & Maintenance
    public func clearMemoryCache() {
        dataMemoryCache.removeAllObjects()
        urlMemoryCache.removeAll()
    }

    public func clearDiskCache() {
        try? FileManager.default.removeItem(at: diskCacheDirectory)
        try? FileManager.default.createDirectory(at: diskCacheDirectory, withIntermediateDirectories: true)
    }

    public func diskCacheSize() -> Int64 {
        guard let files = try? FileManager.default.contentsOfDirectory(at: diskCacheDirectory, includingPropertiesForKeys: [.fileSizeKey]) else {
            return 0
        }
        var total: Int64 = 0
        for file in files {
            if let attrs = try? file.resourceValues(forKeys: [.fileSizeKey]), let size = attrs.fileSize {
                total += Int64(size)
            }
        }
        return total
    }

    public func pruneDiskCacheIfNeeded() {
        let currentSize = diskCacheSize()
        guard currentSize > maxDiskCacheSizeBytes else { return }

        guard let files = try? FileManager.default.contentsOfDirectory(
            at: diskCacheDirectory,
            includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey]
        ) else { return }

        // Sort by oldest modification date first
        let sorted = files.sorted {
            let d1 = (try? $0.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? .distantPast
            let d2 = (try? $1.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? .distantPast
            return d1 < d2
        }

        var deletedBytes: Int64 = 0
        let targetReduction = currentSize - (maxDiskCacheSizeBytes / 2)

        for file in sorted {
            if deletedBytes >= targetReduction { break }
            if let size = (try? file.resourceValues(forKeys: [.fileSizeKey]))?.fileSize {
                try? FileManager.default.removeItem(at: file)
                deletedBytes += Int64(size)
            }
        }
    }

    // MARK: - Internal Key & Path Helpers
    nonisolated private func cacheKeyForURL(_ url: URL) -> String {
        CryptoUtils.sha256Hex(url.absoluteString)
    }

    private func diskFileURL(for cacheKey: String) -> URL {
        diskCacheDirectory.appendingPathComponent("\(cacheKey).art")
    }
}

/// Official architectural alias for HAWK 2.0.
public typealias ArtworkResolutionEngine = ArtworkResolver

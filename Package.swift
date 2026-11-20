// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "HAWK",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(name: "HawkCore", targets: ["HawkCore"]),
        .library(name: "HawkSecurity", targets: ["HawkSecurity"]),
        .library(name: "HawkNetworking", targets: ["HawkNetworking"]),
        .library(name: "HawkSources", targets: ["HawkSources"]),
        .library(name: "HawkPlayback", targets: ["HawkPlayback"]),
        .library(name: "HawkLyrics", targets: ["HawkLyrics"]),
        .library(name: "HawkStats", targets: ["HawkStats"]),
        .library(name: "HawkUI", targets: ["HawkUI"]),
        .executable(name: "HawkVerify", targets: ["HawkVerify"])
    ],
    dependencies: [],
    targets: [
        .target(
            name: "HawkCore",
            dependencies: [],
            path: "Packages/HawkCore"
        ),
        .target(
            name: "HawkSecurity",
            dependencies: ["HawkCore"],
            path: "Packages/HawkSecurity"
        ),
        .target(
            name: "HawkNetworking",
            dependencies: ["HawkCore", "HawkSecurity"],
            path: "Packages/HawkNetworking"
        ),
        .target(
            name: "HawkSources",
            dependencies: ["HawkCore", "HawkSecurity", "HawkNetworking"],
            path: "Packages/HawkSources"
        ),
        .target(
            name: "HawkPlayback",
            dependencies: ["HawkCore", "HawkSources"],
            path: "Packages/HawkPlayback"
        ),
        .target(
            name: "HawkLyrics",
            dependencies: ["HawkCore", "HawkNetworking"],
            path: "Packages/HawkLyrics"
        ),
        .target(
            name: "HawkStats",
            dependencies: ["HawkCore"],
            path: "Packages/HawkStats"
        ),
        .target(
            name: "HawkUI",
            dependencies: [
                "HawkCore",
                "HawkPlayback",
                "HawkSources",
                "HawkLyrics",
                "HawkStats"
            ],
            path: "Packages/HawkUI"
        ),
        .executableTarget(
            name: "HawkVerify",
            dependencies: [
                "HawkCore",
                "HawkSecurity",
                "HawkNetworking",
                "HawkSources",
                "HawkPlayback",
                "HawkLyrics",
                "HawkStats",
                "HawkUI"
            ],
            path: "Tests/HawkVerify"
        ),
        .testTarget(
            name: "HawkCoreTests",
            dependencies: ["HawkCore"],
            path: "Tests/HawkCoreTests"
        ),
        .testTarget(
            name: "HawkSecurityTests",
            dependencies: ["HawkCore", "HawkSecurity"],
            path: "Tests/HawkSecurityTests"
        ),
        .testTarget(
            name: "HawkNetworkingTests",
            dependencies: ["HawkCore", "HawkNetworking"],
            path: "Tests/HawkNetworkingTests"
        ),
        .testTarget(
            name: "HawkSourcesTests",
            dependencies: ["HawkCore", "HawkSources", "HawkSecurity", "HawkNetworking"],
            path: "Tests/HawkSourcesTests"
        ),
        .testTarget(
            name: "HawkPlaybackTests",
            dependencies: ["HawkCore", "HawkPlayback"],
            path: "Tests/HawkPlaybackTests"
        ),
        .testTarget(
            name: "HawkLyricsTests",
            dependencies: ["HawkCore", "HawkLyrics"],
            path: "Tests/HawkLyricsTests"
        ),
        .testTarget(
            name: "HawkStatsTests",
            dependencies: ["HawkCore", "HawkStats"],
            path: "Tests/HawkStatsTests"
        )
    ]
)

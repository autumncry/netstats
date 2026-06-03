// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "netstats",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "NetStats", targets: ["NetStatsApp"])
    ],
    targets: [
        .target(
            name: "NetStatsCore",
            path: "Sources/NetStats"
        ),
        .executableTarget(
            name: "NetStatsApp",
            dependencies: ["NetStatsCore"]
        ),
        .executableTarget(
            name: "NetStatsLogicTests",
            dependencies: ["NetStatsCore"],
            path: "Tests/NetStatsLogicTests"
        )
    ]
)

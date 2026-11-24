// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "NetStats",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "NetStats", targets: ["NetStatsApp"])
    ],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle.git", exact: "2.10.1")
    ],
    targets: [
        .target(
            name: "NetStatsCore",
            dependencies: [.product(name: "Sparkle", package: "Sparkle")],
            path: "Sources/NetStats"
        ),
        .executableTarget(
            name: "NetStatsApp",
            dependencies: ["NetStatsCore"],
            linkerSettings: [.unsafeFlags(["-Xlinker", "-rpath", "-Xlinker", "@executable_path/../Frameworks"])]
        ),
        .executableTarget(
            name: "NetStatsLogicTests",
            dependencies: ["NetStatsCore"],
            path: "Tests/NetStatsLogicTests"
        ),
        .testTarget(
            name: "NetStatsNotchTests",
            dependencies: ["NetStatsCore"],
            path: "Tests/NetStatsNotchTests"
        )
    ]
)

// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "netstats",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "NetStats", targets: ["NetStats"])
    ],
    targets: [
        .executableTarget(
            name: "NetStats"
        )
    ]
)

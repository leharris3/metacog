// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "MetaCog",
    platforms: [
        .macOS(.v15)  // Will update to macOS 26 (Tahoe) when SDK is available
    ],
    dependencies: [
        .package(url: "https://github.com/groue/GRDB.swift.git", from: "7.0.0")
    ],
    targets: [
        .executableTarget(
            name: "MetaCog",
            dependencies: [
                .product(name: "GRDB", package: "GRDB.swift")
            ],
            path: "Sources/MetaCog"
        )
    ]
)

// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let approachableConcurrencySettings: [SwiftSetting] = [
    .enableExperimentalFeature("StrictConcurrency"),
    .enableUpcomingFeature("ExistentialAny"),
    .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
    .defaultIsolation(MainActor.self),
]

let package = Package(
    name: "axPackage", // Renamed package slightly to avoid any confusion with executable name
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .library(name: "AXorcist", targets: ["AXorcist"]), // Product 'AXorcist' now comes from target 'AXorcist'
        .executable(name: "axorc", targets: ["axorc"]), // Product 'axorc' comes from target 'axorc'
    ],
    dependencies: [
        .package(path: "../../Commander"),
        .package(url: "https://github.com/apple/swift-log.git", from: "1.5.4"),
    ],
    targets: [
        .target(
            name: "AXorcist",
            dependencies: [
                .product(name: "Logging", package: "swift-log"), // Added Logging product from swift-log
            ],
            path: "Sources/AXorcist", // Be very direct about the source path
            exclude: [], // Explicitly no excludes
            sources: nil, // Explicitly let SPM find all sources in the path
            swiftSettings: approachableConcurrencySettings
        ),
        .executableTarget(
            name: "axorc", // Executable target name
            dependencies: [
                "AXorcist", // Dependency restored to AXorcist
                .product(name: "Commander", package: "Commander"),
            ],
            path: "Sources/axorc", // Explicit path
            swiftSettings: approachableConcurrencySettings
        ),
        .testTarget(
            name: "AXorcistTests",
            dependencies: [
                "AXorcist", // Dependency restored to AXorcist
            ],
            path: "Tests/AXorcistTests", // Explicit path
            swiftSettings: approachableConcurrencySettings
            // Sources will be inferred by SPM
        ),
    ],
    swiftLanguageModes: [.v6]
)

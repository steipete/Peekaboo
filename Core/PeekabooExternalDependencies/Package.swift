// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "PeekabooExternalDependencies",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "PeekabooExternalDependencies",
            targets: ["PeekabooExternalDependencies"]
        ),
    ],
    dependencies: [
        // External dependencies centralized here
        .package(path: "../AXorcist"),
        .package(url: "https://github.com/apple/swift-async-algorithms", from: "1.0.0"),
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.3.0"),
        .package(url: "https://github.com/apple/swift-log", from: "1.5.3"),
        .package(url: "https://github.com/apple/swift-system", from: "1.3.0"),
        .package(url: "https://github.com/swift-server/async-http-client", from: "1.19.0"),
    ],
    targets: [
        .target(
            name: "PeekabooExternalDependencies",
            dependencies: [
                .product(name: "AXorcist", package: "AXorcist"),
                .product(name: "AsyncAlgorithms", package: "swift-async-algorithms"),
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "Logging", package: "swift-log"),
                .product(name: "SystemPackage", package: "swift-system"),
                .product(name: "AsyncHTTPClient", package: "async-http-client"),
            ],
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency"),
            ]
        ),
    ],
    swiftLanguageModes: [.v6]
)
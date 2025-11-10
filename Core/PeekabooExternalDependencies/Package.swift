// swift-tools-version: 6.2

import PackageDescription

let approachableConcurrencySettings: [SwiftSetting] = [
    .enableExperimentalFeature("StrictConcurrency"),
    .enableUpcomingFeature("ExistentialAny"),
    .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
    .defaultIsolation(MainActor.self),
]

let package = Package(
    name: "PeekabooExternalDependencies",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "PeekabooExternalDependencies",
            targets: ["PeekabooExternalDependencies"]),
    ],
    dependencies: [
        // External dependencies centralized here
        .package(path: "../AXorcist"),
        .package(url: "https://github.com/apple/swift-async-algorithms", from: "1.0.4"),
        .package(path: "../../Vendor/swift-argument-parser"),
        .package(url: "https://github.com/apple/swift-log", from: "1.6.4"),
        .package(url: "https://github.com/apple/swift-system", from: "1.6.3"),
        .package(url: "https://github.com/apple/swift-collections", from: "1.3.0"),
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
                .product(name: "OrderedCollections", package: "swift-collections"),
            ],
            swiftSettings: approachableConcurrencySettings),
    ],
    swiftLanguageModes: [.v6])

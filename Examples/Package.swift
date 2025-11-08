// swift-tools-version: 6.2
import PackageDescription

let approachableConcurrencySettings: [SwiftSetting] = [
    .enableExperimentalFeature("StrictConcurrency"),
    .enableUpcomingFeature("ExistentialAny"),
    .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
    .defaultIsolation(MainActor.self),
]

let package = Package(
    name: "TachikomaExamples",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        // Individual executable examples
        .executable(name: "TachikomaComparison", targets: ["TachikomaComparison"]),
        .executable(name: "TachikomaBasics", targets: ["TachikomaBasics"]),
        .executable(name: "TachikomaStreaming", targets: ["TachikomaStreaming"]),
        .executable(name: "TachikomaAgent", targets: ["TachikomaAgent"]),
        .executable(name: "TachikomaMultimodal", targets: ["TachikomaMultimodal"]),

        // Shared utilities library
        .library(name: "SharedExampleUtils", targets: ["SharedExampleUtils"]),
    ],
    dependencies: [
        // Local Tachikoma dependency
        .package(path: "../Tachikoma"),

        // External dependencies for examples
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.6.2"),
        .package(url: "https://github.com/jpsim/Yams.git", from: "5.0.0"),
    ],
    targets: [
        // Shared utilities used across examples
        .target(
            name: "SharedExampleUtils",
            dependencies: [
                .product(name: "Tachikoma", package: "Tachikoma"),
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "Yams", package: "Yams"),
            ],
            swiftSettings: approachableConcurrencySettings),

        // 1. TachikomaComparison - The killer demo
        .executableTarget(
            name: "TachikomaComparison",
            dependencies: [
                "SharedExampleUtils",
                .product(name: "Tachikoma", package: "Tachikoma"),
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ],
            swiftSettings: approachableConcurrencySettings),

        // 2. TachikomaBasics - Getting started
        .executableTarget(
            name: "TachikomaBasics",
            dependencies: [
                "SharedExampleUtils",
                .product(name: "Tachikoma", package: "Tachikoma"),
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ],
            swiftSettings: approachableConcurrencySettings),

        // 3. TachikomaStreaming - Real-time responses
        .executableTarget(
            name: "TachikomaStreaming",
            dependencies: [
                "SharedExampleUtils",
                .product(name: "Tachikoma", package: "Tachikoma"),
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ],
            swiftSettings: approachableConcurrencySettings),

        // 4. TachikomaAgent - Function calling and AI agents
        .executableTarget(
            name: "TachikomaAgent",
            dependencies: [
                "SharedExampleUtils",
                .product(name: "Tachikoma", package: "Tachikoma"),
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ],
            swiftSettings: approachableConcurrencySettings),

        // 5. TachikomaMultimodal - Vision + text processing
        .executableTarget(
            name: "TachikomaMultimodal",
            dependencies: [
                "SharedExampleUtils",
                .product(name: "Tachikoma", package: "Tachikoma"),
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ],
            swiftSettings: approachableConcurrencySettings),
    ])

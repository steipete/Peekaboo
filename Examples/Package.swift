// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "TachikomaExamples",
    platforms: [
        .macOS(.v14)
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
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.0.0"),
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
            ]
        ),
        
        // 1. TachikomaComparison - The killer demo
        .executableTarget(
            name: "TachikomaComparison",
            dependencies: [
                "SharedExampleUtils",
                .product(name: "Tachikoma", package: "Tachikoma"),
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ]
        ),
        
        // 2. TachikomaBasics - Getting started
        .executableTarget(
            name: "TachikomaBasics",
            dependencies: [
                "SharedExampleUtils",
                .product(name: "Tachikoma", package: "Tachikoma"),
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ]
        ),
        
        // 3. TachikomaStreaming - Real-time responses
        .executableTarget(
            name: "TachikomaStreaming",
            dependencies: [
                "SharedExampleUtils",
                .product(name: "Tachikoma", package: "Tachikoma"),
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ]
        ),
        
        // 4. TachikomaAgent - Function calling and AI agents
        .executableTarget(
            name: "TachikomaAgent",
            dependencies: [
                "SharedExampleUtils",
                .product(name: "Tachikoma", package: "Tachikoma"),
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ]
        ),
        
        // 5. TachikomaMultimodal - Vision + text processing
        .executableTarget(
            name: "TachikomaMultimodal",
            dependencies: [
                "SharedExampleUtils",
                .product(name: "Tachikoma", package: "Tachikoma"),
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ]
        ),
    ]
)
// swift-tools-version: 6.2

import PackageDescription

let approachableConcurrencySettings: [SwiftSetting] = [
    .enableExperimentalFeature("StrictConcurrency"),
    .enableUpcomingFeature("ExistentialAny"),
    .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
]

let visualizerTargetSettings = approachableConcurrencySettings + [
    .unsafeFlags(["-parse-as-library"]),
]

let testTargetSettings: [SwiftSetting] = approachableConcurrencySettings + [
    .enableExperimentalFeature("SwiftTesting"),
]

let package = Package(
    name: "PeekabooVisualizer",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "PeekabooVisualizer",
            targets: ["PeekabooVisualizer"]),
    ],
    dependencies: [
        .package(path: "../PeekabooFoundation"),
        .package(path: "../PeekabooProtocols"),
        .package(url: "https://github.com/apple/swift-algorithms", from: "1.2.1"),
    ],
    targets: [
        .target(
            name: "PeekabooVisualizer",
            dependencies: [
                .product(name: "PeekabooFoundation", package: "PeekabooFoundation"),
                .product(name: "PeekabooProtocols", package: "PeekabooProtocols"),
                .product(name: "Algorithms", package: "swift-algorithms"),
            ],
            swiftSettings: visualizerTargetSettings),
        .testTarget(
            name: "PeekabooVisualizerTests",
            dependencies: [
                "PeekabooVisualizer",
                .product(name: "PeekabooFoundation", package: "PeekabooFoundation"),
                .product(name: "PeekabooProtocols", package: "PeekabooProtocols"),
            ],
            swiftSettings: testTargetSettings),
    ],
    swiftLanguageModes: [.v6])

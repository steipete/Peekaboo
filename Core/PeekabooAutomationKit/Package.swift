// swift-tools-version: 6.2

import PackageDescription

let approachableConcurrencySettings: [SwiftSetting] = [
    .enableExperimentalFeature("StrictConcurrency"),
    .enableUpcomingFeature("ExistentialAny"),
    .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
]

let kitTargetSettings = approachableConcurrencySettings + [
    .unsafeFlags(["-parse-as-library"]),
]

let package = Package(
    name: "PeekabooAutomationKit",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "PeekabooAutomationKit",
            targets: ["PeekabooAutomationKit"]),
    ],
    dependencies: [
        .package(path: "../PeekabooFoundation"),
        .package(path: "../PeekabooProtocols"),
        .package(path: "../../AXorcist"),
        .package(url: "https://github.com/apple/swift-algorithms", from: "1.2.1"),
    ],
    targets: [
        .target(
            name: "PeekabooAutomationKit",
            dependencies: [
                .product(name: "PeekabooFoundation", package: "PeekabooFoundation"),
                .product(name: "PeekabooProtocols", package: "PeekabooProtocols"),
                .product(name: "AXorcist", package: "AXorcist"),
                .product(name: "Algorithms", package: "swift-algorithms"),
            ],
            exclude: ["Core/README.md"],
            swiftSettings: kitTargetSettings),
        .testTarget(
            name: "PeekabooAutomationKitTests",
            dependencies: ["PeekabooAutomationKit"],
            path: "Tests/PeekabooAutomationKitTests",
            swiftSettings: approachableConcurrencySettings),
    ],
    swiftLanguageModes: [.v6])

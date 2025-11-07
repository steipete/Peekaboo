// swift-tools-version: 6.2

import PackageDescription

let approachableConcurrencySettings: [SwiftSetting] = [
    .enableExperimentalFeature("StrictConcurrency"),
    .enableUpcomingFeature("ExistentialAny"),
    .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
    .defaultIsolation(MainActor.self),
]

let foundationTargetSettings = approachableConcurrencySettings + [
    .unsafeFlags(["-parse-as-library"]),
]

let package = Package(
    name: "PeekabooFoundation",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "PeekabooFoundation",
            targets: ["PeekabooFoundation"]),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "PeekabooFoundation",
            dependencies: [],
            swiftSettings: foundationTargetSettings),
        .testTarget(
            name: "PeekabooFoundationTests",
            dependencies: ["PeekabooFoundation"],
            swiftSettings: approachableConcurrencySettings),
    ],
    swiftLanguageModes: [.v6])

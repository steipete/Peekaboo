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
    name: "Peekaboo",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "Peekaboo",
            targets: ["Peekaboo"]),
    ],
    dependencies: [
        .package(path: "../../Core/PeekabooCore"),
    ],
    targets: [
        .target(
            name: "Peekaboo",
            dependencies: [
                .product(name: "PeekabooCore", package: "PeekabooCore"),
            ],
            path: "Peekaboo",
            exclude: ["PeekabooApp.swift", "Info.plist"],
            resources: [
                .process("Assets.xcassets"),
            ],
            swiftSettings: approachableConcurrencySettings),
        .testTarget(
            name: "PeekabooTests",
            dependencies: ["Peekaboo"],
            path: "PeekabooTests",
            exclude: ["README.md"],
            swiftSettings: approachableConcurrencySettings),
    ],
    swiftLanguageModes: [.v6])


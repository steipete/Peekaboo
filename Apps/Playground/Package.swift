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
    name: "Playground",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "Playground",
            targets: ["Playground"]),
    ],
    dependencies: [
        .package(path: "../../Core/PeekabooCore"),
    ],
    targets: [
        .target(
            name: "Playground",
            dependencies: [
                .product(name: "PeekabooCore", package: "PeekabooCore"),
            ],
            path: "Playground",
            exclude: ["PlaygroundApp.swift", "Info.plist", "AppIcon.icon-source"],
            resources: [
                .process("Assets.xcassets"),
            ],
            swiftSettings: approachableConcurrencySettings),
        .testTarget(
            name: "PlaygroundTests",
            dependencies: ["Playground"],
            path: "Tests/PlaygroundTests",
            swiftSettings: approachableConcurrencySettings),
    ],
    swiftLanguageModes: [.v6])

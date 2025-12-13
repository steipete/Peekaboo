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
        .package(path: "../../Core/PeekabooUICore"),
        .package(path: "../../Tachikoma"),
        .package(url: "https://github.com/sindresorhus/KeyboardShortcuts", from: "2.0.0"),
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.8.1"),
    ],
    targets: [
        .target(
            name: "Peekaboo",
            dependencies: [
                .product(name: "PeekabooCore", package: "PeekabooCore"),
                .product(name: "PeekabooUICore", package: "PeekabooUICore"),
                .product(name: "Tachikoma", package: "Tachikoma"),
                .product(name: "TachikomaAudio", package: "Tachikoma"),
                .product(name: "KeyboardShortcuts", package: "KeyboardShortcuts"),
                .product(name: "Sparkle", package: "Sparkle"),
            ],
            path: "Peekaboo",
            exclude: ["PeekabooApp.swift", "Info.plist", "Features/StatusBar/README.md"],
            resources: [
                .process("Assets.xcassets"),
                .process("AppIcon.icon"),
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

// swift-tools-version: 6.2

import PackageDescription

let approachableConcurrencySettings: [SwiftSetting] = [
    .enableExperimentalFeature("StrictConcurrency"),
    .enableUpcomingFeature("ExistentialAny"),
    .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
]

let coreTargetSettings = approachableConcurrencySettings + [
    .unsafeFlags(["-parse-as-library"]),
]

let package = Package(
    name: "PeekabooCore",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "PeekabooCore",
            targets: ["PeekabooCore"]),
    ],
    dependencies: [
        .package(path: "../PeekabooFoundation"),
        .package(path: "../PeekabooProtocols"),
        .package(path: "../PeekabooExternalDependencies"),
        .package(path: "../../Tachikoma"),
        .package(url: "https://github.com/apple/swift-configuration", .upToNextMinor(from: "0.2.0")),
        .package(url: "https://github.com/ChimeHQ/AsyncXPCConnection.git", from: "1.3.0"),
    ],
    targets: [
        .target(
            name: "PeekabooCore",
            dependencies: [
                .product(name: "PeekabooFoundation", package: "PeekabooFoundation"),
                .product(name: "PeekabooProtocols", package: "PeekabooProtocols"),
                .product(name: "PeekabooExternalDependencies", package: "PeekabooExternalDependencies"),
                .product(name: "Tachikoma", package: "Tachikoma"),
                .product(name: "TachikomaMCP", package: "Tachikoma"),
                .product(name: "TachikomaAudio", package: "Tachikoma"),
                .product(name: "Configuration", package: "swift-configuration"),
                .product(name: "AsyncXPCConnection", package: "AsyncXPCConnection"),
            ],
            exclude: [
                "README.md",
                "Core/README.md",
                "Services/README.md",
                "Services/Agent/Tools/README.md",
            ],
            swiftSettings: coreTargetSettings),
        .testTarget(
            name: "PeekabooTests",
            dependencies: [
                "PeekabooCore",
                "PeekabooFoundation",
                "PeekabooProtocols",
            ],
            resources: [
                .process("Resources"),
            ],
            swiftSettings: approachableConcurrencySettings),
    ],
    swiftLanguageModes: [.v6])

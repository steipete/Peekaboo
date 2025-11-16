// swift-tools-version: 6.2

import Foundation
import PackageDescription

let approachableConcurrencySettings: [SwiftSetting] = [
    .enableExperimentalFeature("StrictConcurrency"),
    .enableUpcomingFeature("ExistentialAny"),
    .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
]

let coreTargetSettings = approachableConcurrencySettings + [
    .unsafeFlags(["-parse-as-library"]),
]

let includeAutomationTests = ProcessInfo.processInfo.environment["PEEKABOO_INCLUDE_AUTOMATION_TESTS"] == "true"
let testTargetSettings: [SwiftSetting] = includeAutomationTests
    ? approachableConcurrencySettings + [.define("PEEKABOO_INCLUDE_AUTOMATION_TESTS")]
    : approachableConcurrencySettings

let package = Package(
    name: "PeekabooCore",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "PeekabooAutomation",
            targets: ["PeekabooAutomation"]),
        .library(
            name: "PeekabooVisualizer",
            targets: ["PeekabooVisualizer"]),
        .library(
            name: "PeekabooAgentRuntime",
            targets: ["PeekabooAgentRuntime"]),
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
    ],
    targets: [
        .target(
            name: "PeekabooAutomation",
            dependencies: [
                .target(name: "PeekabooVisualizer"),
                .product(name: "PeekabooFoundation", package: "PeekabooFoundation"),
                .product(name: "PeekabooProtocols", package: "PeekabooProtocols"),
                .product(name: "PeekabooExternalDependencies", package: "PeekabooExternalDependencies"),
                .product(name: "Tachikoma", package: "Tachikoma"),
                .product(name: "TachikomaAudio", package: "Tachikoma"),
                .product(name: "Configuration", package: "swift-configuration"),
            ],
            path: "Sources/PeekabooAutomation",
            exclude: [
                "Services/README.md",
                "Core/README.md",
            ],
            swiftSettings: coreTargetSettings),
        .testTarget(
            name: "PeekabooAutomationTests",
            dependencies: [
                "PeekabooAutomation",
                .product(name: "PeekabooFoundation", package: "PeekabooFoundation"),
            ],
            path: "Tests/PeekabooAutomationTests",
            swiftSettings: testTargetSettings),
        .target(
            name: "PeekabooVisualizer",
            dependencies: [
                .product(name: "PeekabooFoundation", package: "PeekabooFoundation"),
                .product(name: "PeekabooProtocols", package: "PeekabooProtocols"),
                .product(name: "PeekabooExternalDependencies", package: "PeekabooExternalDependencies"),
            ],
            path: "Sources/PeekabooVisualizer",
            swiftSettings: coreTargetSettings),
        .testTarget(
            name: "PeekabooVisualizerTests",
            dependencies: [
                "PeekabooVisualizer",
                .product(name: "PeekabooFoundation", package: "PeekabooFoundation"),
            ],
            path: "Tests/PeekabooVisualizerTests",
            swiftSettings: testTargetSettings),
        .target(
            name: "PeekabooAgentRuntime",
            dependencies: [
                .target(name: "PeekabooAutomation"),
                .target(name: "PeekabooVisualizer"),
                .product(name: "PeekabooFoundation", package: "PeekabooFoundation"),
                .product(name: "PeekabooProtocols", package: "PeekabooProtocols"),
                .product(name: "PeekabooExternalDependencies", package: "PeekabooExternalDependencies"),
                .product(name: "Tachikoma", package: "Tachikoma"),
                .product(name: "TachikomaMCP", package: "Tachikoma"),
                .product(name: "Configuration", package: "swift-configuration"),
            ],
            path: "Sources/PeekabooAgentRuntime",
            exclude: [
                "Agent/Tools/README.md",
            ],
            swiftSettings: coreTargetSettings),
        .testTarget(
            name: "PeekabooAgentRuntimeTests",
            dependencies: [
                "PeekabooAgentRuntime",
                "PeekabooCore",
                .product(name: "PeekabooFoundation", package: "PeekabooFoundation"),
            ],
            path: "Tests/PeekabooAgentRuntimeTests",
            swiftSettings: testTargetSettings),
        .target(
            name: "PeekabooCore",
            dependencies: [
                .target(name: "PeekabooAutomation"),
                .target(name: "PeekabooAgentRuntime"),
                .target(name: "PeekabooVisualizer"),
                .product(name: "PeekabooFoundation", package: "PeekabooFoundation"),
                .product(name: "PeekabooProtocols", package: "PeekabooProtocols"),
                .product(name: "PeekabooExternalDependencies", package: "PeekabooExternalDependencies"),
                .product(name: "Tachikoma", package: "Tachikoma"),
                .product(name: "TachikomaMCP", package: "Tachikoma"),
                .product(name: "TachikomaAudio", package: "Tachikoma"),
                .product(name: "Configuration", package: "swift-configuration"),
            ],
            exclude: [
                "README.md",
            ],
            swiftSettings: coreTargetSettings),
        .testTarget(
            name: "PeekabooTests",
            dependencies: [
                "PeekabooCore",
                "PeekabooAutomation",
                "PeekabooAgentRuntime",
                "PeekabooFoundation",
                "PeekabooProtocols",
            ],
            resources: [
                .process("Resources"),
            ],
            swiftSettings: testTargetSettings),
    ],
    swiftLanguageModes: [.v6])

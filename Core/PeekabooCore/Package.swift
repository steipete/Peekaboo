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
let testTargetSettings: [SwiftSetting] = {
    var base = approachableConcurrencySettings + [.enableExperimentalFeature("SwiftTesting")]
    if includeAutomationTests {
        base.append(.define("PEEKABOO_INCLUDE_AUTOMATION_TESTS"))
    }
    return base
}()

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
            name: "PeekabooXPC",
            targets: ["PeekabooXPC"]),
        .library(
            name: "PeekabooCore",
            targets: ["PeekabooCore"]),
        .executable(
            name: "PeekabooHelper",
            targets: ["PeekabooHelper"]),
    ],
    dependencies: [
        .package(path: "../PeekabooAutomationKit"),
        .package(path: "../PeekabooFoundation"),
        .package(path: "../PeekabooProtocols"),
        .package(path: "../PeekabooExternalDependencies"),
        .package(path: "../../Tachikoma"),
        .package(url: "https://github.com/ChimeHQ/AsyncXPCConnection", from: "1.3.0"),
        // Use main for Swift 6.x compatibility; 0.2.0 trips key-path restrictions in Swift 6.
        .package(url: "https://github.com/apple/swift-configuration", branch: "main"),
    ],
    targets: [
        .target(
            name: "PeekabooAutomation",
            dependencies: [
                .target(name: "PeekabooVisualizer"),
                .product(name: "PeekabooAutomationKit", package: "PeekabooAutomationKit"),
                .product(name: "PeekabooFoundation", package: "PeekabooFoundation"),
                .product(name: "PeekabooProtocols", package: "PeekabooProtocols"),
                .product(name: "PeekabooExternalDependencies", package: "PeekabooExternalDependencies"),
                .product(name: "Tachikoma", package: "Tachikoma"),
                .product(name: "TachikomaAudio", package: "Tachikoma"),
                .product(name: "TachikomaMCP", package: "Tachikoma"),
                .product(name: "Configuration", package: "swift-configuration"),
            ],
            path: "Sources/PeekabooAutomation",
            exclude: [
                "Services/README.md",
            ],
            swiftSettings: coreTargetSettings),
        .testTarget(
            name: "PeekabooAutomationTests",
            dependencies: [
                "PeekabooAutomation",
                "PeekabooCore",
                .product(name: "PeekabooAutomationKit", package: "PeekabooAutomationKit"),
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
            name: "PeekabooXPC",
            dependencies: [
                .target(name: "PeekabooAutomation"),
                .target(name: "PeekabooAgentRuntime"),
                .product(name: "PeekabooFoundation", package: "PeekabooFoundation"),
                .product(name: "PeekabooExternalDependencies", package: "PeekabooExternalDependencies"),
                .product(name: "AsyncXPCConnection", package: "AsyncXPCConnection"),
            ],
            path: "Sources/PeekabooXPC",
            swiftSettings: coreTargetSettings),
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
                "PeekabooXPC",
                .product(name: "PeekabooAutomationKit", package: "PeekabooAutomationKit"),
                "PeekabooFoundation",
                "PeekabooProtocols",
            ],
            resources: [
                .process("Resources"),
            ],
            swiftSettings: testTargetSettings),
        .executableTarget(
            name: "PeekabooHelper",
            dependencies: [
                "PeekabooCore",
                "PeekabooXPC",
            ],
            path: "Sources/PeekabooHelper",
            swiftSettings: approachableConcurrencySettings),
    ],
    swiftLanguageModes: [.v6])

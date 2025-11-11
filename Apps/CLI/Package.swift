// swift-tools-version: 6.2
import Foundation
import PackageDescription

let concurrencyBaseSettings: [SwiftSetting] = [
    .enableExperimentalFeature("StrictConcurrency"),
    .enableUpcomingFeature("ExistentialAny"),
    .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
    .enableExperimentalFeature("RetroactiveConformances"),
]

let cliConcurrencySettings = concurrencyBaseSettings + [
    .defaultIsolation(MainActor.self),
]

let swiftTestingSettings = cliConcurrencySettings + [
    .enableExperimentalFeature("SwiftTesting"),
]

let includeAutomationTests = ProcessInfo.processInfo.environment["PEEKABOO_INCLUDE_AUTOMATION_TESTS"] == "true"

var targets: [Target] = [
    .target(
        name: "PeekabooCLI",
        dependencies: [
            .product(name: "Commander", package: "Commander"),
            .product(name: "MCP", package: "swift-sdk"),
            .product(name: "Spinner", package: "Spinner"),
            .product(name: "PeekabooCore", package: "PeekabooCore"),
            .product(name: "Tachikoma", package: "Tachikoma"),
            .product(name: "TachikomaMCP", package: "Tachikoma"),
        ],
        path: "Sources/PeekabooCLI",
        swiftSettings: cliConcurrencySettings),
    .executableTarget(
        name: "peekaboo",
        dependencies: [
            "PeekabooCLI",
        ],
        path: "Sources/PeekabooExec",
        swiftSettings: cliConcurrencySettings,
        linkerSettings: [
            .unsafeFlags([
                "-Xlinker", "-sectcreate",
                "-Xlinker", "__TEXT",
                "-Xlinker", "__info_plist",
                "-Xlinker", "Sources/Resources/Info.plist",
                // Ensure LC_UUID is generated for macOS 26 compatibility
                "-Xlinker", "-random_uuid",
            ]),
        ]),
    .testTarget(
        name: "CoreCLITests",
        dependencies: [
            "PeekabooCLI",
            .product(name: "PeekabooFoundation", package: "PeekabooFoundation"),
        ],
        path: "Tests/CoreCLITests",
        swiftSettings: swiftTestingSettings),
    .testTarget(
        name: "CLIRuntimeTests",
        dependencies: [
            "PeekabooCLI",
            .product(name: "PeekabooFoundation", package: "PeekabooFoundation"),
            .product(name: "Subprocess", package: "swift-subprocess"),
        ],
        path: "Tests/CLIRuntimeTests",
        swiftSettings: swiftTestingSettings),
]

if includeAutomationTests {
    targets.append(
        .testTarget(
            name: "CLIAutomationTests",
            dependencies: [
                "PeekabooCLI",
                .product(name: "PeekabooFoundation", package: "PeekabooFoundation"),
                .product(name: "Subprocess", package: "swift-subprocess"),
            ],
            path: "Tests/CLIAutomationTests",
            swiftSettings: swiftTestingSettings)
    )
}



let package = Package(
    name: "peekaboo",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .executable(
            name: "peekaboo",
            targets: ["peekaboo"]),
    ],
    dependencies: [
        .package(path: "../../Commander"),
        .package(url: "https://github.com/modelcontextprotocol/swift-sdk.git", from: "0.10.2"),
        .package(url: "https://github.com/dominicegginton/Spinner", from: "2.1.0"),
        .package(url: "https://github.com/swiftlang/swift-subprocess.git", from: "0.2.1"),
        .package(path: "../../Core/PeekabooFoundation"),
        .package(path: "../../Core/PeekabooCore"),
        .package(path: "../../Tachikoma"),
    ],
    targets: targets,
    swiftLanguageModes: [.v6])

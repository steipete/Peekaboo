// swift-tools-version: 6.2
import Foundation
import PackageDescription

let includeAutomationTests = ProcessInfo.processInfo.environment["PEEKABOO_INCLUDE_AUTOMATION_TESTS"] == "true"

var targets: [Target] = [
    .target(
        name: "PeekabooCLI",
        dependencies: [
            .product(name: "ArgumentParser", package: "swift-argument-parser"),
            .product(name: "MCP", package: "swift-sdk"),
            .product(name: "Spinner", package: "Spinner"),
            .product(name: "PeekabooCore", package: "PeekabooCore"),
            .product(name: "Tachikoma", package: "Tachikoma"),
            .product(name: "TachikomaMCP", package: "Tachikoma"),
        ],
        path: "Sources/PeekabooCLI"),
    .executableTarget(
        name: "peekaboo",
        dependencies: [
            "PeekabooCLI",
        ],
        path: "Sources/PeekabooExec",
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
        swiftSettings: []),
]

if includeAutomationTests {
    targets.append(
        .testTarget(
            name: "peekabooAutomationTests",
            dependencies: [
                "PeekabooCLI",
                .product(name: "PeekabooFoundation", package: "PeekabooFoundation"),
            ],
            path: "Tests/peekabooAutomationTests",
            swiftSettings: [])
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
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.6.2"),
        .package(url: "https://github.com/modelcontextprotocol/swift-sdk.git", from: "0.10.2"),
        .package(url: "https://github.com/dominicegginton/Spinner", from: "2.1.0"),
        .package(path: "../../Core/PeekabooFoundation"),
        .package(path: "../../Core/PeekabooCore"),
        .package(path: "../../Tachikoma"),
    ],
    targets: targets,
    swiftLanguageModes: [.v6])

// swift-tools-version: 6.0

import PackageDescription

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
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.3.0"),
        .package(url: "https://github.com/modelcontextprotocol/swift-sdk.git", from: "0.9.0"),
        .package(path: "../AXorcist"),
    ],
    targets: [
        .target(
            name: "PeekabooCore",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "MCP", package: "swift-sdk"),
                .product(name: "AXorcist", package: "AXorcist"),
            ],
            exclude: [
                "README.md",
                "Core/README.md",
                "AI/README.md",
                "Services/README.md",
                "Services/Agent/Tools/README.md",
            ]),
        .testTarget(
            name: "PeekabooTests",
            dependencies: ["PeekabooCore"]),
    ],
    swiftLanguageModes: [.v6])

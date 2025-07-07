// swift-tools-version: 5.9

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
        .package(path: "../AXorcist"),
    ],
    targets: [
        .target(
            name: "PeekabooCore",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                "AXorcist",
            ],
            path: "Sources"),
        .testTarget(
            name: "PeekabooTests",
            dependencies: ["PeekabooCore"],
            path: "Tests"),
    ])

// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

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
    ],
    targets: [
        .target(
            name: "Peekaboo",
            dependencies: [
                .product(name: "PeekabooCore", package: "PeekabooCore"),
                .product(name: "PeekabooUICore", package: "PeekabooUICore"),
                .product(name: "TachikomaCore", package: "Tachikoma"),
            ],
            path: "Peekaboo",
            exclude: ["PeekabooApp.swift", "Info.plist"],
            resources: [
                .process("Assets.xcassets"),
            ]),
        .testTarget(
            name: "PeekabooTests",
            dependencies: ["Peekaboo"],
            path: "PeekabooTests",
            exclude: ["README.md"]),
    ],
    swiftLanguageModes: [.v6])

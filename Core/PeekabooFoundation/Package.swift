// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "PeekabooFoundation",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "PeekabooFoundation",
            targets: ["PeekabooFoundation"]),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "PeekabooFoundation",
            dependencies: [],
            swiftSettings: [
                .unsafeFlags(["-parse-as-library"]),
            ]),
        .testTarget(
            name: "PeekabooFoundationTests",
            dependencies: ["PeekabooFoundation"]),
    ],
    swiftLanguageModes: [.v6])

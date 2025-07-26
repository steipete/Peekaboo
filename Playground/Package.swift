// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "Playground",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(
            name: "Playground",
            targets: ["Playground"]
        )
    ],
    targets: [
        .executableTarget(
            name: "Playground",
            dependencies: [],
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency")
            ]
        )
    ]
)
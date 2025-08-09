// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "PeekabooProtocols",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "PeekabooProtocols",
            targets: ["PeekabooProtocols"]
        ),
    ],
    dependencies: [
        .package(path: "../PeekabooFoundation"),
    ],
    targets: [
        .target(
            name: "PeekabooProtocols",
            dependencies: [
                "PeekabooFoundation",
            ],
            swiftSettings: [
                .unsafeFlags([
                    "-Xfrontend", "-warn-long-function-bodies=50",
                    "-Xfrontend", "-warn-long-expression-type-checking=50"
                ], .when(configuration: .debug)),
                .enableExperimentalFeature("StrictConcurrency"),
            ]
        ),
        .testTarget(
            name: "PeekabooProtocolsTests",
            dependencies: ["PeekabooProtocols"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
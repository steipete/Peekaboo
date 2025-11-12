// swift-tools-version: 6.2
import PackageDescription

let approachableConcurrencySettings: [SwiftSetting] = [
    .enableExperimentalFeature("StrictConcurrency"),
    .enableUpcomingFeature("ExistentialAny"),
    .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
    .defaultIsolation(MainActor.self),
]

let package = Package(
    name: "PeekabooUICore",
    platforms: [.macOS(.v14)],
    products: [
        .library(
            name: "PeekabooUICore",
            targets: ["PeekabooUICore"]),
    ],
    dependencies: [
        .package(path: "../PeekabooCore"),
        .package(path: "../../AXorcist"),
    ],
    targets: [
        .target(
            name: "PeekabooUICore",
            dependencies: [
                .product(name: "PeekabooCore", package: "PeekabooCore"),
                .product(name: "AXorcist", package: "AXorcist"),
            ],
            swiftSettings: approachableConcurrencySettings),
        .testTarget(
            name: "PeekabooUITests",
            dependencies: ["PeekabooUICore"],
            swiftSettings: approachableConcurrencySettings),
    ])

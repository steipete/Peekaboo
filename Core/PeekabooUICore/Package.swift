// swift-tools-version: 6.0
import PackageDescription

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
        .package(path: "../AXorcist"),
    ],
    targets: [
        .target(
            name: "PeekabooUICore",
            dependencies: [
                .product(name: "PeekabooCore", package: "PeekabooCore"),
                .product(name: "AXorcist", package: "AXorcist"),
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6),
            ]),
        .testTarget(
            name: "PeekabooUITests",
            dependencies: ["PeekabooUICore"],
            swiftSettings: [
                .swiftLanguageMode(.v6),
            ]),
    ])

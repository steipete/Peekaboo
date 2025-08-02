// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Tachikoma",
    platforms: [
        .macOS(.v14),
        .iOS(.v17),
        .watchOS(.v10),
        .tvOS(.v17)
    ],
    products: [
        .library(
            name: "Tachikoma",
            targets: ["Tachikoma"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-log.git", from: "1.0.0"),
    ],
    targets: [
        .target(
            name: "Tachikoma",
            dependencies: [
                .product(name: "Logging", package: "swift-log"),
            ],
            path: "Sources",
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency"),
                // Only enable upcoming features that aren't already default in Swift 6
                .enableUpcomingFeature("InternalImportsByDefault"),
            ]
        ),
        .testTarget(
            name: "TachikomaTests",
            dependencies: [
                "Tachikoma",
                .product(name: "Logging", package: "swift-log"),
            ],
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency"),
                // Only enable upcoming features that aren't already default in Swift 6
                .enableUpcomingFeature("InternalImportsByDefault"),
            ]
        ),
    ]
)
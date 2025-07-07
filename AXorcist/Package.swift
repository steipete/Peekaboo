// swift-tools-version:5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "axPackage", // Renamed package slightly to avoid any confusion with executable name
    platforms: [
        .macOS(.v13) // macOS 13.0 or later
    ],
    products: [
        .library(name: "AXorcistLib", targets: ["AXorcistLib"]),
        .executable(name: "axorc", targets: ["axorc"]) // Product 'axorc' comes from target 'axorc'
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.3.0"), // Added swift-argument-parser
        .package(url: "https://github.com/apple/swift-testing.git", from: "0.6.0") // Added swift-testing
    ],
    targets: [
        .target(
            name: "AXorcistLib",
            path: "Sources/AXorcist" // Explicit path
            // Sources will be inferred by SPM
        ),
        .executableTarget(
            name: "axorc", // Executable target name
            dependencies: [
                "AXorcistLib",
                .product(name: "ArgumentParser", package: "swift-argument-parser") // Added dependency product
            ],
            path: "Sources/axorc" // Explicit path
            // Sources (axorc.swift) will be inferred by SPM
        ),
        .testTarget(
            name: "AXorcistTests",
            dependencies: [
                "AXorcistLib",
                .product(name: "Testing", package: "swift-testing") // Added swift-testing dependency
            ],
            path: "Tests/AXorcistTests" // Explicit path
            // Sources will be inferred by SPM
        )
    ]
)

// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "peekaboo",
    platforms: [
        .macOS(.v15)
    ],
    products: [
        .executable(
            name: "peekaboo",
            targets: ["peekaboo"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.0.0")
    ],
    targets: [
        .executableTarget(
            name: "peekaboo",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ],
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency")
            ]
        ),
        .testTarget(
            name: "peekabooTests",
            dependencies: ["peekaboo"],
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency")
            ]
        )
    ]
)

// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "peekaboo",
    platforms: [
        .macOS(.v14)
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
            ]
        ),
        .testTarget(
            name: "peekabooTests",
            dependencies: ["peekaboo"]
        )
    ]
)

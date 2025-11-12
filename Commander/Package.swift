// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Commander",
    platforms: [
        .macOS(.v14),
        .iOS(.v17),
        .tvOS(.v17),
        .watchOS(.v10),
        .visionOS(.v1),
    ],
    products: [
        .library(name: "Commander", targets: ["Commander"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-docc-plugin", from: "1.4.0"),
    ],
    targets: [
        .target(
            name: "Commander",
            path: "Sources/Commander"),
        .testTarget(
            name: "CommanderTests",
            dependencies: ["Commander"],
            path: "Tests/CommanderTests"),
    ],
    swiftLanguageModes: [.v6])

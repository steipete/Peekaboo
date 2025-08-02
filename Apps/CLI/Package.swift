// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "peekaboo",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .executable(
            name: "peekaboo",
            targets: ["peekaboo"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.0.0"),
        .package(url: "https://github.com/modelcontextprotocol/swift-sdk.git", from: "0.9.0"),
        .package(path: "../../Core/PeekabooCore"),
    ],
    targets: [
        .executableTarget(
            name: "peekaboo",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "MCP", package: "swift-sdk"),
                .product(name: "PeekabooCore", package: "PeekabooCore"),
            ],
            swiftSettings: [
                .unsafeFlags(["-parse-as-library"]),
            ],
            linkerSettings: [
                .unsafeFlags([
                    "-Xlinker", "-sectcreate",
                    "-Xlinker", "__TEXT",
                    "-Xlinker", "__info_plist",
                    "-Xlinker", "Sources/Resources/Info.plist",
                    // Ensure LC_UUID is generated for macOS 26 compatibility
                    "-Xlinker", "-random_uuid",
                ]),
            ]),
        .testTarget(
            name: "peekabooTests",
            dependencies: ["peekaboo"],
            swiftSettings: []),
    ],
    swiftLanguageModes: [.v6])

// swift-tools-version: 6.0
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
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.0.0"),
        .package(url: "https://github.com/steipete/AXorcist", branch: "main")
    ],
    targets: [
        .executableTarget(
            name: "peekaboo",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "AXorcist", package: "AXorcist")
            ],
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency"),
                .unsafeFlags(["-parse-as-library"])
            ],
            linkerSettings: [
                .unsafeFlags([
                    "-Xlinker", "-sectcreate",
                    "-Xlinker", "__TEXT",
                    "-Xlinker", "__info_plist",
                    "-Xlinker", "Sources/Resources/Info.plist",
                    // Ensure LC_UUID is generated for macOS 26 compatibility
                    "-Xlinker", "-random_uuid"
                ])
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

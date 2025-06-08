// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "peekaboo",
    platforms: [
        .macOS(.v14),
        .iOS(.v13), // For potential future iOS support
        .watchOS(.v6), // For potential future watchOS support
        .tvOS(.v13) // For potential future tvOS support
    ],
    products: [
        .executable(
            name: "peekaboo",
            targets: ["peekaboo"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.0.0"),
        // Platform-specific dependencies will be conditionally included
        .package(url: "https://github.com/apple/swift-system", from: "1.0.0"), // For cross-platform system APIs
    ],
    targets: [
        .executableTarget(
            name: "peekaboo",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "SystemPackage", package: "swift-system"),
            ],
            swiftSettings: [
                // Enable platform-specific compilation
                .define("CROSS_PLATFORM_SUPPORT"),
                // Platform-specific defines
                .define("MACOS_SUPPORT", .when(platforms: [.macOS])),
                .define("WINDOWS_SUPPORT", .when(platforms: [.windows])),
                .define("LINUX_SUPPORT", .when(platforms: [.linux])),
            ],
            linkerSettings: [
                // macOS-specific frameworks
                .linkedFramework("AppKit", .when(platforms: [.macOS])),
                .linkedFramework("CoreGraphics", .when(platforms: [.macOS])),
                .linkedFramework("ScreenCaptureKit", .when(platforms: [.macOS])),
                .linkedFramework("ApplicationServices", .when(platforms: [.macOS])),
                // Windows-specific libraries
                .linkedLibrary("user32", .when(platforms: [.windows])),
                .linkedLibrary("gdi32", .when(platforms: [.windows])),
                .linkedLibrary("dwmapi", .when(platforms: [.windows])),
                .linkedLibrary("dxgi", .when(platforms: [.windows])),
                .linkedLibrary("d3d11", .when(platforms: [.windows])),
                // Linux-specific libraries
                .linkedLibrary("X11", .when(platforms: [.linux])),
                .linkedLibrary("Xcomposite", .when(platforms: [.linux])),
                .linkedLibrary("Xrandr", .when(platforms: [.linux])),
                .linkedLibrary("Xfixes", .when(platforms: [.linux])),
            ]
        ),
        .testTarget(
            name: "peekabooTests",
            dependencies: ["peekaboo"],
            swiftSettings: [
                .define("CROSS_PLATFORM_SUPPORT"),
                .define("MACOS_SUPPORT", .when(platforms: [.macOS])),
                .define("WINDOWS_SUPPORT", .when(platforms: [.windows])),
                .define("LINUX_SUPPORT", .when(platforms: [.linux])),
            ]
        )
    ]
)


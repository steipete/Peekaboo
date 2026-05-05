// swift-tools-version: 6.2
import PackageDescription

let concurrencySettings: [SwiftSetting] = [
    .enableExperimentalFeature("StrictConcurrency"),
    .enableUpcomingFeature("ExistentialAny"),
    .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
    .defaultIsolation(MainActor.self),
]

let package = Package(
    name: "BackgroundHotkeyProbe",
    platforms: [
        .macOS(.v15),
    ],
    products: [
        .executable(
            name: "BackgroundHotkeyProbe",
            targets: ["BackgroundHotkeyProbe"]
        ),
    ],
    targets: [
        .executableTarget(
            name: "BackgroundHotkeyProbe",
            swiftSettings: concurrencySettings,
            linkerSettings: [
                .linkedFramework("AppKit"),
            ]
        ),
    ],
    swiftLanguageModes: [.v6]
)

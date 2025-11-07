// swift-tools-version: 6.2
import PackageDescription

let approachableConcurrencySettings: [SwiftSetting] = [
    .enableExperimentalFeature("StrictConcurrency"),
    .enableUpcomingFeature("ExistentialAny"),
    .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
    .defaultIsolation(MainActor.self),
]

let package = Package(
    name: "PeekabooTestHost",
    platforms: [
        .macOS(.v13),
    ],
    products: [
        .executable(
            name: "PeekabooTestHost",
            targets: ["PeekabooTestHost"]
        ),
    ],
    targets: [
        .executableTarget(
            name: "PeekabooTestHost",
            path: ".",
            sources: ["TestHostApp.swift", "ContentView.swift"],
            swiftSettings: approachableConcurrencySettings
        ),
    ],
    swiftLanguageModes: [.v6]
)

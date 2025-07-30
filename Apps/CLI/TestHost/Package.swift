// swift-tools-version: 6.0
import PackageDescription

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
            swiftSettings: [
                .swiftLanguageMode(.v6),
            ]
        ),
    ]
)

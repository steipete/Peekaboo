// swift-tools-version: 6.2
import PackageDescription

let approachableConcurrencySettings: [SwiftSetting] = [
    .enableExperimentalFeature("StrictConcurrency"),
    .enableUpcomingFeature("ExistentialAny"),
    .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
    .defaultIsolation(MainActor.self),
]

let package = Package(
    name: "PeekabooInspector",
    platforms: [.macOS(.v14)],
    products: [
        .executable(
            name: "PeekabooInspector",
            targets: ["PeekabooInspector"]),
    ],
    dependencies: [
        .package(path: "../../Core/AXorcist"),
        .package(path: "../../Core/PeekabooCore"),
        .package(path: "../../Core/PeekabooUICore"),
    ],
    targets: [
        .executableTarget(
            name: "PeekabooInspector",
            dependencies: [
                .product(name: "AXorcist", package: "AXorcist"),
                .product(name: "PeekabooCore", package: "PeekabooCore"),
                .product(name: "PeekabooUICore", package: "PeekabooUICore"),
            ],
            path: "Inspector",
            exclude: ["Info.plist", "PeekabooInspector.entitlements"],
            resources: [
                .process("Assets.xcassets"),
                .process("AppIcon.icon"),
            ],
            swiftSettings: approachableConcurrencySettings),
        .testTarget(
            name: "PeekabooInspectorTests",
            dependencies: ["PeekabooInspector"],
            path: "Tests/PeekabooInspectorTests",
            swiftSettings: approachableConcurrencySettings),
    ])

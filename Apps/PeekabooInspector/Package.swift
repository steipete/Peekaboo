// swift-tools-version: 6.0
import PackageDescription

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
            path: "PeekabooInspector",
            resources: [
                .process("Assets.xcassets"),
                .process("AppIcon.icon"),
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6),
            ]),
    ])

// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PeekabooInspector",
    platforms: [.macOS(.v14)],
    products: [
        .executable(
            name: "PeekabooInspector",
            targets: ["PeekabooInspector"]
        ),
    ],
    dependencies: [
        .package(path: "../../Core/AXorcist"),
    ],
    targets: [
        .executableTarget(
            name: "PeekabooInspector",
            dependencies: [
                .product(name: "AXorcist", package: "AXorcist"),
            ],
            path: "PeekabooInspector",
            resources: [
                .process("Assets.xcassets"),
                .process("AppIcon.icon"),
            ]
        ),
    ]
)
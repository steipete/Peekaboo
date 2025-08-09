// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "PeekabooCore",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "PeekabooCore",
            targets: ["PeekabooCore"]),
    ],
    dependencies: [
        .package(path: "../PeekabooFoundation"),
        .package(path: "../PeekabooProtocols"),
        .package(path: "../PeekabooExternalDependencies"),
        .package(path: "../../Tachikoma"),
    ],
    targets: [
        .target(
            name: "PeekabooCore",
            dependencies: [
                .product(name: "PeekabooFoundation", package: "PeekabooFoundation"),
                .product(name: "PeekabooProtocols", package: "PeekabooProtocols"),
                .product(name: "PeekabooExternalDependencies", package: "PeekabooExternalDependencies"),
                .product(name: "Tachikoma", package: "Tachikoma"),
                .product(name: "TachikomaMCP", package: "Tachikoma"),
                .product(name: "TachikomaAudio", package: "Tachikoma"),
            ],
            exclude: [
                "README.md",
                "Core/README.md",
                "Services/README.md",
                "Services/Agent/Tools/README.md",
            ],
            swiftSettings: [
                .unsafeFlags(["-parse-as-library"]),
            ]),
        .testTarget(
            name: "PeekabooTests",
            dependencies: [
                "PeekabooCore",
                "PeekabooFoundation",
                "PeekabooProtocols",
            ],
            resources: [
                .process("Resources")
            ]),
    ],
    swiftLanguageModes: [.v6])

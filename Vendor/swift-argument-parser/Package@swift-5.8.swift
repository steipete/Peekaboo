// swift-tools-version:5.8
//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift Argument Parser open source project
//
// Copyright (c) 2020 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
//
//===----------------------------------------------------------------------===//

import PackageDescription

var package = Package(
  name: "swift-argument-parser",
  products: [
    .library(
      name: "ArgumentParser",
      targets: ["ArgumentParser"]),
    .plugin(
      name: "GenerateDoccReference",
      targets: ["GenerateDoccReference"]),
    .plugin(
      name: "GenerateManual",
      targets: ["GenerateManual"]),
  ],
  dependencies: [],
  targets: [
    // Core Library
    .target(
      name: "ArgumentParser",
      dependencies: ["ArgumentParserToolInfo"],
      exclude: ["CMakeLists.txt"],
      swiftSettings: [.enableExperimentalFeature("StrictConcurrency")]),
    .target(
      name: "ArgumentParserTestHelpers",
      dependencies: ["ArgumentParser", "ArgumentParserToolInfo"],
      exclude: ["CMakeLists.txt"]),
    .target(
      name: "ArgumentParserToolInfo",
      exclude: ["CMakeLists.txt"]),

    // Plugins
    .plugin(
      name: "GenerateDoccReference",
      capability: .command(
        intent: .custom(
          verb: "generate-docc-reference",
          description:
            "Generate a documentation reference for a specified target."),
        permissions: [
          .writeToPackageDirectory(
            reason: "This command generates documentation.")
        ]),
      dependencies: ["generate-docc-reference"]),
    .plugin(
      name: "GenerateManual",
      capability: .command(
        intent: .custom(
          verb: "generate-manual",
          description: "Generate a manual entry for a specified target.")),
      dependencies: ["generate-manual"]),

    // Examples
    .executableTarget(
      name: "roll",
      dependencies: ["ArgumentParser"],
      path: "Examples/roll"),
    .executableTarget(
      name: "math",
      dependencies: ["ArgumentParser"],
      path: "Examples/math"),
    .executableTarget(
      name: "repeat",
      dependencies: ["ArgumentParser"],
      path: "Examples/repeat"),
    .executableTarget(
      name: "color",
      dependencies: ["ArgumentParser"],
      path: "Examples/color"),

    // Tools
    .executableTarget(
      name: "generate-docc-reference",
      dependencies: ["ArgumentParser", "ArgumentParserToolInfo"],
      path: "Tools/generate-docc-reference"),
    .executableTarget(
      name: "generate-manual",
      dependencies: ["ArgumentParser", "ArgumentParserToolInfo"],
      path: "Tools/generate-manual"),

    // Tests
    .testTarget(
      name: "ArgumentParserEndToEndTests",
      dependencies: ["ArgumentParser", "ArgumentParserTestHelpers"],
      exclude: ["CMakeLists.txt"]),
    .testTarget(
      name: "ArgumentParserExampleTests",
      dependencies: ["ArgumentParserTestHelpers"],
      exclude: ["Snapshots"],
      resources: [.copy("CountLinesTest.txt")]),
    .testTarget(
      name: "ArgumentParserGenerateDoccReferenceTests",
      dependencies: ["ArgumentParserTestHelpers"],
      exclude: ["Snapshots"]),
    .testTarget(
      name: "ArgumentParserGenerateManualTests",
      dependencies: ["ArgumentParserTestHelpers"],
      exclude: ["Snapshots"]),
    .testTarget(
      name: "ArgumentParserPackageManagerTests",
      dependencies: ["ArgumentParser", "ArgumentParserTestHelpers"],
      exclude: ["CMakeLists.txt"]),
    .testTarget(
      name: "ArgumentParserToolInfoTests",
      dependencies: ["ArgumentParserToolInfo"],
      exclude: ["Examples"]),
    .testTarget(
      name: "ArgumentParserUnitTests",
      dependencies: ["ArgumentParser", "ArgumentParserTestHelpers"],
      exclude: ["CMakeLists.txt", "Snapshots"]),
  ]
)

#if os(macOS)
package.targets.append(contentsOf: [
  // Examples
  .executableTarget(
    name: "count-lines",
    dependencies: ["ArgumentParser"],
    path: "Examples/count-lines"),

  // Tools
  .executableTarget(
    name: "changelog-authors",
    dependencies: ["ArgumentParser"],
    path: "Tools/changelog-authors"),
])
#endif

for target in package.targets {
  switch target.type {
  case .regular, .test, .executable:
    var settings = target.swiftSettings ?? []
    // https://github.com/swiftlang/swift-evolution/blob/main/proposals/0444-member-import-visibility.md
    settings.append(.enableUpcomingFeature("MemberImportVisibility"))
    target.swiftSettings = settings
  case .macro, .plugin, .system, .binary:
    break  // not applicable
  @unknown default:
    break  // we don't know what to do here, do nothing
  }
}

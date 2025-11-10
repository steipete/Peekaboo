//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift Argument Parser open source project
//
// Copyright (c) 2025 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
//
//===----------------------------------------------------------------------===//

import Foundation
import PackagePlugin

@main
struct GenerateDoccReferencePlugin: CommandPlugin {
  func performCommand(
    context: PluginContext,
    arguments: [String]
  ) async throws {
    // Locate generation tool.
    let generationTool = "generate-docc-reference"
    let generationToolFile = try context.tool(named: generationTool).path

    // Create an extractor to extract plugin-only arguments from the `arguments`
    // array.
    var extractor = ArgumentExtractor(arguments)

    // Run generation tool once if help is requested.
    if extractor.helpRequest() {
      try generationToolFile.exec(arguments: ["--help"])
      print(
        """
        ADDITIONAL OPTIONS:
          --configuration <configuration>
                      Tool build configuration used to generate the
                      reference document. (default: release)

        NOTE: The "GenerateDoccReference" plugin handles passing the "<tool>" and
        "--output-directory <output-directory>" arguments. Manually supplying
        these arguments will result in a runtime failure.
        """)
      return
    }

    // Extract configuration argument before making it to the
    // "generate-docc-reference" tool.
    let configuration = try extractor.configuration()

    // Build all products first.
    print("Building package in \(configuration) mode...")
    let buildResult = try packageManager.build(
      .all(includingTests: false),
      parameters: .init(configuration: configuration))

    guard buildResult.succeeded else {
      throw GenerateDoccReferencePluginError.buildFailed(buildResult.logText)
    }
    print("Built package in \(configuration) mode")

    // Run generate-docc-reference on all executable artifacts.
    for builtArtifact in buildResult.builtArtifacts {
      // Skip non-executable targets
      guard builtArtifact.kind == .executable else { continue }

      // Skip executables without a matching product.
      guard let product = builtArtifact.matchingProduct(context: context)
      else { continue }

      // Skip products without a dependency on ArgumentParser.
      guard product.hasDependency(named: "ArgumentParser") else { continue }

      // Skip products with multiple underlying targets.
      guard product.targets.count == 1 else { continue }
      let target = product.targets[0]

      // Get the artifacts name.
      let executableName = builtArtifact.path.lastComponent
      print("Generating docc reference for \(executableName)...")

      // Create output directory.
      let outputDirectory = target.directory
        .appending("\(target.name).docc")
      try outputDirectory.createOutputDirectory()

      // Create generation tool arguments.
      var generationToolArguments = [
        builtArtifact.path.string,
        "--output-directory",
        outputDirectory.string,
      ]
      generationToolArguments.append(
        contentsOf: extractor.remainingArguments)

      // Spawn generation tool.
      try generationToolFile.exec(arguments: generationToolArguments)
      print("Generated docc reference in '\(outputDirectory)'")
    }
  }
}

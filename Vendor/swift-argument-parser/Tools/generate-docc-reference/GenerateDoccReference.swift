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

import ArgumentParser
import ArgumentParserToolInfo
import Foundation

enum GenerateDoccReferenceError: Error {
  case failedToRunSubprocess(error: Error)
  case unableToParseToolOutput(error: Error)
  case unsupportedDumpHelpVersion(expected: Int, found: Int)
  case failedToGenerateDoccReference(error: Error)
}

extension GenerateDoccReferenceError: CustomStringConvertible {
  var description: String {
    switch self {
    case .failedToRunSubprocess(let error):
      return "Failed to run subprocess: \(error)"
    case .unableToParseToolOutput(let error):
      return "Failed to parse tool output: \(error)"
    case .unsupportedDumpHelpVersion(let expected, let found):
      return
        "Unsupported dump help version, expected '\(expected)' but found: '\(found)'"
    case .failedToGenerateDoccReference(let error):
      return "Failed to generated docc reference: \(error)"
    }
  }
}

/// The flavor of generated markdown to emit.
enum OutputStyle: String, EnumerableFlag, ExpressibleByArgument {
  /// DocC-supported markdown
  case docc
  /// GitHub-flavored markdown
  case github
}

@main
struct GenerateDoccReference: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "generate-docc-reference",
    abstract: "Generate a docc reference for the provided tool.")

  @Argument(help: "Tool to generate docc reference for.")
  var tool: String

  @Option(
    name: .shortAndLong,
    help: "Directory to save generated docc reference. Use '-' for stdout.")
  var outputDirectory: String

  @Option(
    name: .shortAndLong,
    help: "Use docc flavored markdown for the generated output.")
  var style: OutputStyle = .github

  func validate() throws {
    if outputDirectory != "-" {
      // outputDirectory must already exist, `GenerateDoccReference` will not create it.
      var objcBool: ObjCBool = true
      guard
        FileManager.default.fileExists(
          atPath: outputDirectory, isDirectory: &objcBool)
      else {
        throw ValidationError(
          "Output directory \(outputDirectory) does not exist")
      }

      guard objcBool.boolValue else {
        throw ValidationError(
          "Output directory \(outputDirectory) is not a directory")
      }
    }
  }

  func run() throws {
    let data: Data
    // runs the tool with the --experimental-dump-help argument to capture
    // the output.
    do {
      let tool = URL(fileURLWithPath: tool)
      let output = try executeCommand(
        executable: tool, arguments: ["--experimental-dump-help"])
      data = output.data(using: .utf8) ?? Data()
    } catch {
      throw GenerateDoccReferenceError.failedToRunSubprocess(error: error)
    }

    // ToolInfoHeader is intentionally kept internal to argument parser to
    // allow the library some flexibility to update/change its content/format.
    do {
      let toolInfoThin = try JSONDecoder().decode(
        ToolInfoHeader.self, from: data)
      // verify the serialization version is known/expected
      guard toolInfoThin.serializationVersion == 0 else {
        throw GenerateDoccReferenceError.unsupportedDumpHelpVersion(
          expected: 0,
          found: toolInfoThin.serializationVersion)
      }
    } catch {
      throw GenerateDoccReferenceError.unableToParseToolOutput(error: error)
    }

    let toolInfo: ToolInfoV0
    do {
      toolInfo = try JSONDecoder().decode(ToolInfoV0.self, from: data)
    } catch {
      throw GenerateDoccReferenceError.unableToParseToolOutput(error: error)
    }

    do {
      if self.outputDirectory == "-" {
        try self.generatePages(
          from: toolInfo.command, savingTo: nil, flavor: style)
      } else {
        try self.generatePages(
          from: toolInfo.command,
          savingTo: URL(fileURLWithPath: outputDirectory),
          flavor: style)
      }
    } catch {
      throw GenerateDoccReferenceError.failedToGenerateDoccReference(
        error: error)
    }
  }

  /// Generates a markdown file from the CommandInfoV0 object you provide.
  /// - Parameters:
  ///   - command: The command to parse into a markdown output.
  ///   - directory: The directory to save the generated markdown file, printing it if `nil`.
  ///   - flavor: The flavor of markdown to use when generating the content.
  /// - Throws: An error if the markdown file cannot be generated or saved.
  func generatePages(
    from command: CommandInfoV0, savingTo directory: URL?, flavor: OutputStyle
  )
    throws
  {
    let page = command.toMarkdown([], markdownStyle: style)

    if let directory = directory {
      let fileName = command.doccReferenceFileName
      let outputPath = directory.appendingPathComponent(fileName)
      try page.write(to: outputPath, atomically: false, encoding: .utf8)
    } else {
      print(page)
    }
  }
}

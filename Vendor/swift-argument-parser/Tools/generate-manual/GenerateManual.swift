//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift Argument Parser open source project
//
// Copyright (c) 2021 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
//
//===----------------------------------------------------------------------===//

import ArgumentParser
import ArgumentParserToolInfo
import Foundation

enum GenerateManualError: Error {
  case failedToRunSubprocess(error: Error)
  case unableToParseToolOutput(error: Error)
  case unsupportedDumpHelpVersion(expected: Int, found: Int)
  case failedToGenerateManualPages(error: Error)
}

extension GenerateManualError: CustomStringConvertible {
  var description: String {
    switch self {
    case .failedToRunSubprocess(let error):
      return "Failed to run subprocess: \(error)"
    case .unableToParseToolOutput(let error):
      return "Failed to parse tool output: \(error)"
    case .unsupportedDumpHelpVersion(let expected, let found):
      return
        "Unsupported dump help version, expected '\(expected)' but found: '\(found)'"
    case .failedToGenerateManualPages(let error):
      return "Failed to generated manual pages: \(error)"
    }
  }
}

@main
struct GenerateManual: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "generate-manual",
    abstract: "Generate a manual for the provided tool.")

  @Argument(help: "Tool to generate manual for.")
  var tool: String

  @Flag(help: "Generate a separate manual for each subcommand.")
  var multiPage = false

  @Option(
    name: .long,
    help: "Override the creation date of the manual. Format: 'yyyy-mm-dd'.")
  var date: Date = Date()

  @Option(name: .long, help: "Section of the manual.")
  var section: Int = 1

  @Option(
    name: .long,
    help: "Names and/or emails of the tool's authors. Format: 'name<email>'.")
  var authors: [AuthorArgument] = []

  @Option(
    name: .shortAndLong,
    help: "Directory to save generated manual. Use '-' for stdout.")
  var outputDirectory: String

  func validate() throws {
    // Only man pages 1 through 9 are valid.
    guard (1...9).contains(section) else {
      throw ValidationError("Invalid manual section passed to --section")
    }

    if outputDirectory != "-" {
      // outputDirectory must already exist, `GenerateManual` will not create it.
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
      throw GenerateManualError.failedToRunSubprocess(error: error)
    }

    // ToolInfoHeader is intentionally kept internal to argument parser to
    // allow the library some flexibility to update/change its content/format.
    do {
      let toolInfoThin = try JSONDecoder().decode(
        ToolInfoHeader.self, from: data)
      // verify the serialization version is known/expected
      guard toolInfoThin.serializationVersion == 0 else {
        throw GenerateManualError.unsupportedDumpHelpVersion(
          expected: 0,
          found: toolInfoThin.serializationVersion)
      }
    } catch {
      throw GenerateManualError.unableToParseToolOutput(error: error)
    }

    let toolInfo: ToolInfoV0
    do {
      toolInfo = try JSONDecoder().decode(ToolInfoV0.self, from: data)
    } catch {
      throw GenerateManualError.unableToParseToolOutput(error: error)
    }

    do {
      if outputDirectory == "-" {
        try generatePages(from: toolInfo.command, savingTo: nil)
      } else {
        try generatePages(
          from: toolInfo.command,
          savingTo: URL(fileURLWithPath: outputDirectory))
      }
    } catch {
      throw GenerateManualError.failedToGenerateManualPages(error: error)
    }
  }

  func generatePages(from command: CommandInfoV0, savingTo directory: URL?)
    throws
  {
    let document = Document(
      multiPage: multiPage,
      date: date,
      section: section,
      authors: authors,
      command: command)
    let page = document.ast.map { $0.serialized() }.joined(separator: "\n")

    if let directory = directory {
      let fileName = command.manualPageFileName(section: section)
      let outputPath = directory.appendingPathComponent(fileName)
      try page.write(to: outputPath, atomically: false, encoding: .utf8)
    } else {
      print(page)
    }

    if multiPage {
      for subcommand in command.subcommands ?? [] {
        try generatePages(from: subcommand, savingTo: directory)
      }
    }
  }
}

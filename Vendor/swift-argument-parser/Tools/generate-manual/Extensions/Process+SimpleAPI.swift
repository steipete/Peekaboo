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

import Foundation

enum SubprocessError: Swift.Error, LocalizedError, CustomStringConvertible {
  case missingExecutable(url: URL)
  case failedToLaunch(error: Swift.Error)
  case nonZeroExitCode(code: Int, stderr: String?)

  var description: String {
    switch self {
    case .missingExecutable(let url):
      return "No executable at '\(url.standardizedFileURL.path)'."
    case .failedToLaunch(let error):
      return "Couldn't run command process. \(error.localizedDescription)"
    case .nonZeroExitCode(let code, let stderr):
      var description = "Process returned non-zero exit code '\(code)'."
      if let stderr = stderr {
        description.append(
          """
           Standard error:
          \(stderr)
          """)
      }
      return description
    }
  }

  var errorDescription: String? { description }
}

func executeCommand(
  executable: URL,
  arguments: [String]
) throws -> String {
  guard (try? executable.checkResourceIsReachable()) ?? false else {
    throw SubprocessError.missingExecutable(url: executable)
  }

  let process = Process()
  process.executableURL = executable
  process.arguments = arguments

  let output = Pipe()
  process.standardOutput = output
  let error = Pipe()
  process.standardError = error

  do {
    try process.run()
  } catch {
    throw SubprocessError.failedToLaunch(error: error)
  }
  let outputData = output.fileHandleForReading.readDataToEndOfFile()
  let errorData = error.fileHandleForReading.readDataToEndOfFile()
  process.waitUntilExit()

  guard process.terminationStatus == 0 else {
    let errorActual = String(data: errorData, encoding: .utf8)?
      .trimmingCharacters(in: .whitespacesAndNewlines)
    throw SubprocessError.nonZeroExitCode(
      code: Int(process.terminationStatus),
      stderr: errorActual)
  }

  let outputActual =
    String(data: outputData, encoding: .utf8)?
    .trimmingCharacters(in: .whitespacesAndNewlines)
    ?? ""

  return outputActual
}

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

import ArgumentParser
import Foundation

@main
@available(macOS 12, iOS 15, visionOS 1, tvOS 15, watchOS 8, *)
struct CountLines: AsyncParsableCommand {
  @Argument(
    help: "A file to count lines in. If omitted, counts the lines of stdin.",
    completion: .file(), transform: URL.init(fileURLWithPath:))
  var inputFile: URL? = nil

  @Option(help: "Only count lines with this prefix.")
  var prefix: String? = nil

  @Flag(help: "Include extra information in the output.")
  var verbose = false

  var fileHandle: FileHandle {
    get throws {
      guard let inputFile else {
        return .standardInput
      }
      return try FileHandle(forReadingFrom: inputFile)
    }
  }

  func printCount(_ count: Int) {
    guard verbose else {
      print(count)
      return
    }

    if let filename = inputFile?.lastPathComponent {
      print("Lines in '\(filename)'", terminator: "")
    } else {
      print("Lines from stdin", terminator: "")
    }

    if let prefix {
      print(", prefixed by '\(prefix)'", terminator: "")
    }

    print(": \(count)")
  }

  mutating func run() async throws {
    var lineCount = 0
    for try await line in try fileHandle.bytes.lines {
      if let prefix {
        lineCount += line.starts(with: prefix) ? 1 : 0
      } else {
        lineCount += 1
      }
    }
    printCount(lineCount)
  }
}

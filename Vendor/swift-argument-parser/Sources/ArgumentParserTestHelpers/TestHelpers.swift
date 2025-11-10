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
import ArgumentParserToolInfo
import XCTest

@available(macOS 10.15, iOS 13.0, watchOS 6.0, tvOS 13.0, *)
extension CollectionDifference.Change {
  var offset: Int {
    switch self {
    case .insert(let offset, _, _):
      return offset
    case .remove(let offset, _, _):
      return offset
    }
  }
}

@available(macOS 10.15, iOS 13.0, watchOS 6.0, tvOS 13.0, *)
extension CollectionDifference.Change: Swift.Comparable
where ChangeElement: Equatable {
  public static func < (lhs: Self, rhs: Self) -> Bool {
    guard lhs.offset == rhs.offset else {
      return lhs.offset < rhs.offset
    }
    switch (lhs, rhs) {
    case (.remove, .insert):
      return true
    case (.insert, .remove):
      return false
    default:
      return true
    }
  }
}

// extensions to the ParsableArguments protocol to facilitate XCTestExpectation support
public protocol TestableParsableArguments: ParsableArguments {
  var didValidateExpectation: XCTestExpectation { get }
}

extension TestableParsableArguments {
  public mutating func validate() throws {
    didValidateExpectation.fulfill()
  }
}

// extensions to the ParsableCommand protocol to facilitate XCTestExpectation support
public protocol TestableParsableCommand: ParsableCommand,
  TestableParsableArguments
{
  var didRunExpectation: XCTestExpectation { get }
}

extension TestableParsableCommand {
  public mutating func run() throws {
    didRunExpectation.fulfill()
  }
}

extension XCTestExpectation {
  public convenience init(singleExpectation description: String) {
    self.init(description: description)
    expectedFulfillmentCount = 1
    assertForOverFulfill = true
  }
}

// swift-format-ignore: AlwaysUseLowerCamelCase
public func AssertResultFailure<T, U: Error>(
  _ expression: @autoclosure () -> Result<T, U>,
  _ message: @autoclosure () -> String = "",
  file: StaticString = #filePath,
  line: UInt = #line
) {
  switch expression() {
  case .success:
    let msg = message()
    XCTFail(msg.isEmpty ? "Incorrectly succeeded" : msg, file: file, line: line)
  case .failure:
    break
  }
}

// swift-format-ignore: AlwaysUseLowerCamelCase
public func AssertErrorMessage<A>(
  _ type: A.Type, _ arguments: [String], _ errorMessage: String,
  file: StaticString = #filePath, line: UInt = #line
) where A: ParsableArguments {
  do {
    _ = try A.parse(arguments)
    XCTFail("Parsing should have failed.", file: file, line: line)
  } catch {
    // We expect to hit this path, i.e. getting an error:
    XCTAssertEqual(A.message(for: error), errorMessage, file: file, line: line)
  }
}

// swift-format-ignore: AlwaysUseLowerCamelCase
public func AssertFullErrorMessage<A>(
  _ type: A.Type, _ arguments: [String], _ errorMessage: String,
  file: StaticString = #filePath, line: UInt = #line
) where A: ParsableArguments {
  do {
    _ = try A.parse(arguments)
    XCTFail("Parsing should have failed.", file: (file), line: line)
  } catch {
    // We expect to hit this path, i.e. getting an error:
    XCTAssertEqual(
      A.fullMessage(for: error), errorMessage, file: (file), line: line)
  }
}

// swift-format-ignore: AlwaysUseLowerCamelCase
public func AssertParse<A>(
  _ type: A.Type, _ arguments: [String], file: StaticString = #filePath,
  line: UInt = #line, closure: (A) throws -> Void
) where A: ParsableArguments {
  do {
    let parsed = try type.parse(arguments)
    try closure(parsed)
  } catch {
    let message = type.message(for: error)
    XCTFail("\"\(message)\" — \(error)", file: (file), line: line)
  }
}

// swift-format-ignore: AlwaysUseLowerCamelCase
public func AssertParseCommand<A: ParsableCommand>(
  _ rootCommand: ParsableCommand.Type, _ type: A.Type, _ arguments: [String],
  file: StaticString = #filePath, line: UInt = #line,
  closure: (A) throws -> Void
) {
  do {
    let command = try rootCommand.parseAsRoot(arguments)
    guard let aCommand = command as? A else {
      XCTFail(
        "Command is of unexpected type: \(command)", file: (file), line: line)
      return
    }
    try closure(aCommand)
  } catch {
    let message = rootCommand.message(for: error)
    XCTFail("\"\(message)\" — \(error)", file: file, line: line)
  }
}

// swift-format-ignore: AlwaysUseLowerCamelCase
public func AssertParseCommandErrorMessage<A: ParsableCommand>(
  _ rootCommand: ParsableCommand.Type, _ type: A.Type, _ arguments: [String],
  _ errorMessage: String,
  file: StaticString = #filePath, line: UInt = #line
) {
  do {
    let command = try rootCommand.parseAsRoot(arguments)
    guard (command as? A) != nil else {
      XCTFail(
        "Command is of unexpected type: \(command)", file: (file), line: line)
      return
    }
    XCTFail("Parsing as root should have failed.", file: file, line: line)
  } catch {
    let message = rootCommand.message(for: error)
    XCTAssertEqual(message, errorMessage, file: file, line: line)
  }
}

// swift-format-ignore: AlwaysUseLowerCamelCase
public func AssertEqualStrings(
  actual: String,
  expected: String,
  file: StaticString = #filePath,
  line: UInt = #line
) {
  // Normalize line endings to '\n'.
  let actual =
    actual
    .replacingOccurrences(of: "\r\n", with: "\n")
    .replacingOccurrences(of: "\r", with: "\n")
  let expected =
    expected
    .replacingOccurrences(of: "\r\n", with: "\n")
    .replacingOccurrences(of: "\r", with: "\n")

  // If the input strings are not equal, create a simple diff for debugging...
  guard actual != expected else {
    // Otherwise they are equal, early exit.
    return
  }

  let stringComparison: String

  // If collectionDifference is available, use it to make a nicer error message.
  if #available(macOS 10.15, iOS 13.0, watchOS 6.0, tvOS 13.0, *) {
    let actualLines = actual.components(separatedBy: .newlines)
    let expectedLines = expected.components(separatedBy: .newlines)

    let difference = actualLines.difference(from: expectedLines)

    var result = ""

    var insertions: [Int: String] = [:]
    var removals: [Int: String] = [:]

    for change in difference {
      switch change {
      case .insert(let offset, let element, _):
        insertions[offset] = element
      case .remove(let offset, let element, _):
        removals[offset] = element
      }
    }

    var expectedLine = 0
    var actualLine = 0

    while expectedLine < expectedLines.count || actualLine < actualLines.count {
      if let removal = removals[expectedLine] {
        result += "–\(removal)\n"
        expectedLine += 1
      } else if let insertion = insertions[actualLine] {
        result += "+\(insertion)\n"
        actualLine += 1
      } else {
        result += " \(expectedLines[expectedLine])\n"
        expectedLine += 1
        actualLine += 1
      }
    }

    stringComparison = result
  } else {
    stringComparison = """
      Expected:
      \(expected)

      Actual:
      \(actual)
      """
  }

  XCTFail(
    "Actual output does not match the expected output:\n\(stringComparison)",
    file: file,
    line: line)
}

// swift-format-ignore: AlwaysUseLowerCamelCase
public func AssertHelp<T: ParsableArguments>(
  _ visibility: ArgumentVisibility,
  for _: T.Type,
  columns: Int? = 80,
  equals expected: String,
  file: StaticString = #filePath,
  line: UInt = #line
) {
  let flag: String
  let includeHidden: Bool

  switch visibility {
  case .default:
    flag = "--help"
    includeHidden = false
  case .hidden:
    flag = "--help-hidden"
    includeHidden = true
  case .private:
    XCTFail("Should not be called.", file: file, line: line)
    return
  default:
    XCTFail("Unrecognized visibility.", file: file, line: line)
    return
  }

  do {
    _ = try T.parse([flag])
    XCTFail(file: file, line: line)
  } catch {
    let helpString = T.fullMessage(for: error, columns: columns)
    AssertEqualStrings(
      actual: helpString, expected: expected, file: file, line: line)
  }

  let helpString = T.helpMessage(includeHidden: includeHidden, columns: columns)
  AssertEqualStrings(
    actual: helpString, expected: expected, file: file, line: line)
}

// swift-format-ignore: AlwaysUseLowerCamelCase
public func AssertHelp<T: ParsableCommand, U: ParsableCommand>(
  _ visibility: ArgumentVisibility,
  for _: T.Type,
  root _: U.Type,
  columns: Int? = 80,
  equals expected: String,
  file: StaticString = #filePath,
  line: UInt = #line
) {
  let includeHidden: Bool

  switch visibility {
  case .default:
    includeHidden = false
  case .hidden:
    includeHidden = true
  case .private:
    XCTFail("Should not be called.", file: file, line: line)
    return
  default:
    XCTFail("Unrecognized visibility.", file: file, line: line)
    return
  }

  let helpString = U.helpMessage(
    for: T.self, includeHidden: includeHidden, columns: columns)
  AssertEqualStrings(
    actual: helpString, expected: expected, file: file, line: line)
}

extension XCTest {
  public var debugURL: URL {
    let bundleURL = Bundle(for: type(of: self)).bundleURL
    return bundleURL.lastPathComponent.hasSuffix("xctest")
      ? bundleURL.deletingLastPathComponent()
      : bundleURL
  }

  // swift-format-ignore: AlwaysUseLowerCamelCase
  @discardableResult
  public func AssertExecuteCommand(
    command: String,
    expected: String? = nil,
    exitCode: ExitCode = .success,
    file: StaticString = #filePath,
    line: UInt = #line,
    environment: [String: String] = [:]
  ) throws -> String {
    try AssertExecuteCommand(
      command: command.split(separator: " ").map(String.init),
      expected: expected,
      exitCode: exitCode,
      file: file,
      line: line,
      environment: environment
    )
  }

  // swift-format-ignore: AlwaysUseLowerCamelCase
  @discardableResult
  public func AssertExecuteCommand(
    command: [String],
    expected: String? = nil,
    exitCode: ExitCode = .success,
    file: StaticString = #filePath,
    line: UInt = #line,
    environment: [String: String] = [:]
  ) throws -> String {
    #if os(Windows)
    throw XCTSkip("Unsupported on this platform")
    #endif

    let arguments = Array(command.dropFirst())
    let commandName = String(command.first!)
    let commandURL = debugURL.appendingPathComponent(commandName)
    guard (try? commandURL.checkResourceIsReachable()) ?? false else {
      XCTFail(
        "No executable at '\(commandURL.standardizedFileURL.path)'.",
        file: file, line: line)
      return ""
    }

    #if !canImport(Darwin) || os(macOS)
    let process = Process()
    process.executableURL = commandURL
    process.arguments = arguments

    let output = Pipe()
    process.standardOutput = output
    let error = Pipe()
    process.standardError = error

    if !environment.isEmpty {
      if let existingEnvironment = process.environment {
        process.environment =
          existingEnvironment.merging(environment) { (_, new) in new }
      } else {
        process.environment = environment
      }
    }

    guard (try? process.run()) != nil else {
      XCTFail("Couldn't run command process.", file: file, line: line)
      return ""
    }
    process.waitUntilExit()

    let outputData = output.fileHandleForReading.readDataToEndOfFile()
    let outputActual = String(data: outputData, encoding: .utf8)!

    let errorData = error.fileHandleForReading.readDataToEndOfFile()
    let errorActual = String(data: errorData, encoding: .utf8)!

    if let expected = expected {
      AssertEqualStrings(
        actual: errorActual + outputActual,
        expected: expected,
        file: file,
        line: line)
    }

    XCTAssertEqual(
      process.terminationStatus, exitCode.rawValue, file: file, line: line)
    #else
    throw XCTSkip("Not supported on this platform")
    #endif
    return outputActual
  }

  // swift-format-ignore: AlwaysUseLowerCamelCase
  public func AssertJSONEqualFromString<T: Codable & Equatable>(
    actual: String, expected: String, for type: T.Type,
    file: StaticString = #filePath, line: UInt = #line
  ) throws {
    AssertEqualStrings(
      actual: actual,
      expected: expected,
      file: file,
      line: line)

    let actualJSONData = try XCTUnwrap(
      actual.data(using: .utf8), file: file, line: line)
    let actualDumpJSON = try XCTUnwrap(
      JSONDecoder().decode(type, from: actualJSONData), file: file, line: line)

    let expectedJSONData = try XCTUnwrap(
      expected.data(using: .utf8), file: file, line: line)
    let expectedDumpJSON = try XCTUnwrap(
      JSONDecoder().decode(type, from: expectedJSONData), file: file, line: line
    )
    XCTAssertEqual(actualDumpJSON, expectedDumpJSON)
  }
}

// MARK: - Snapshot testing
extension XCTest {
  @discardableResult
  public func assertSnapshot(
    actual: String,
    extension: String,
    record: Bool = false,
    test: StaticString = #function,
    file: StaticString = #filePath,
    line: UInt = #line
  ) throws -> String? {
    let snapshotDirectoryURL = URL(fileURLWithPath: "\(file)")
      .deletingLastPathComponent()
      .appendingPathComponent("Snapshots")
    let snapshotFileURL =
      snapshotDirectoryURL
      .appendingPathComponent("\(test).\(`extension`)")

    let snapshotExists = FileManager.default.fileExists(
      atPath: snapshotFileURL.path)
    let recordEnvironment =
      ProcessInfo.processInfo.environment["RECORD_SNAPSHOTS"] != nil

    if record || recordEnvironment || !snapshotExists {
      let recordedValue = actual
      try FileManager.default.createDirectory(
        at: snapshotDirectoryURL,
        withIntermediateDirectories: true,
        attributes: nil)
      try recordedValue.write(
        to: snapshotFileURL, atomically: true, encoding: .utf8)
      XCTFail("Recorded new baseline", file: file, line: line)
      return nil
    } else {
      let expected = try String(contentsOf: snapshotFileURL, encoding: .utf8)
      AssertEqualStrings(
        actual: actual,
        expected: expected,
        file: file,
        line: line)
      return expected
    }
  }

  public func assertGenerateManual(
    multiPage: Bool,
    command: String,
    record: Bool = false,
    test: StaticString = #function,
    file: StaticString = #filePath,
    line: UInt = #line
  ) throws {
    #if os(Windows)
    throw XCTSkip("Unsupported on this platform")
    #endif

    let commandURL = debugURL.appendingPathComponent(command)
    var command = [
      "generate-manual", commandURL.path,
      "--date", "1996-05-12",
      "--section", "9",
      "--authors", "Jane Appleseed",
      "--authors", "<johnappleseed@apple.com>",
      "--authors", "The Appleseeds<appleseeds@apple.com>",
      "--output-directory", "-",
    ]
    if multiPage {
      command.append("--multi-page")
    }
    let actual = try AssertExecuteCommand(
      command: command,
      file: file,
      line: line)

    try self.assertSnapshot(
      actual: actual,
      extension: "mdoc",
      record: record,
      test: test,
      file: file,
      line: line)
  }

  public func assertGeneratedReference(
    command: String,
    doccFlavored: Bool,
    record: Bool = false,
    test: StaticString = #function,
    file: StaticString = #filePath,
    line: UInt = #line
  ) throws {
    #if os(Windows)
    throw XCTSkip("Unsupported on this platform")
    #endif

    let commandURL = debugURL.appendingPathComponent(command)
    let command: [String]
    if doccFlavored {
      command = [
        "generate-docc-reference", commandURL.path,
        "--output-directory", "-",
        "--style", "docc",
      ]
    } else {
      command = [
        "generate-docc-reference", commandURL.path,
        "--output-directory", "-",
      ]
    }
    let actual = try AssertExecuteCommand(
      command: command,
      file: file,
      line: line)

    try self.assertSnapshot(
      actual: actual,
      extension: "md",
      record: record,
      test: test,
      file: file,
      line: line)
  }

  public func assertDumpHelp<T: ParsableArguments>(
    type: T.Type,
    record: Bool = false,
    test: StaticString = #function,
    file: StaticString = #filePath,
    line: UInt = #line
  ) throws {
    let actual: String
    do {
      _ = try T.parse(["--experimental-dump-help"])
      XCTFail(file: file, line: line)
      return
    } catch {
      actual = T.fullMessage(for: error)
    }

    let apiOutput = T._dumpHelp()
    AssertEqualStrings(actual: actual, expected: apiOutput)

    let expected = try self.assertSnapshot(
      actual: actual,
      extension: "json",
      record: record,
      test: test,
      file: file,
      line: line)

    guard let expected else { return }

    try AssertJSONEqualFromString(
      actual: actual,
      expected: expected,
      for: ToolInfoV0.self,
      file: file,
      line: line)
  }

  public func assertDumpHelp(
    command: String,
    record: Bool = false,
    test: StaticString = #function,
    file: StaticString = #filePath,
    line: UInt = #line
  ) throws {
    let actual = try AssertExecuteCommand(
      command: command + " --experimental-dump-help",
      expected: nil,
      file: file,
      line: line)
    try self.assertSnapshot(
      actual: actual,
      extension: "json",
      record: record,
      test: test,
      file: file,
      line: line)
  }
}

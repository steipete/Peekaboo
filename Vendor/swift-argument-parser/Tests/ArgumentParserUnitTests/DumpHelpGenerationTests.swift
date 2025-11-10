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

import ArgumentParserTestHelpers
import XCTest

@testable import ArgumentParser

final class DumpHelpGenerationTests: XCTestCase {
  public func testADumpHelp() throws {
    try assertDumpHelp(type: A.self)
  }

  public func testBDumpHelp() throws {
    try assertDumpHelp(type: B.self)
  }

  public func testCDumpHelp() throws {
    try assertDumpHelp(type: C.self)
  }

  func testMathDumpHelp() throws {
    try assertDumpHelp(command: "math")
  }

  func testMathAddDumpHelp() throws {
    try assertDumpHelp(command: "math add")
  }

  func testMathMultiplyDumpHelp() throws {
    try assertDumpHelp(command: "math multiply")
  }

  func testMathStatsDumpHelp() throws {
    try assertDumpHelp(command: "math stats")
  }
}

extension DumpHelpGenerationTests {
  struct A: ParsableCommand {
    enum TestEnum: String, CaseIterable, ExpressibleByArgument {
      case a = "one"
      case b = "two"
      case c = "three"
    }

    @Option
    var enumeratedOption: TestEnum

    @Option
    var enumeratedOptionWithDefaultValue: TestEnum = .b

    @Option
    var noHelpOption: Int

    @Option(help: "int value option")
    var intOption: Int

    @Option(help: "int value option with default value")
    var intOptionWithDefaultValue: Int = 0

    @Argument
    var arg: Int

    @Argument(help: "argument with help")
    var argWithHelp: Int

    @Argument(help: "argument with default value")
    var argWithDefaultValue: Int = 1
  }

  struct Options: ParsableArguments {
    @Flag
    var verbose = false

    @Option
    var name: String
  }

  struct B: ParsableCommand {
    @OptionGroup(title: "Other")
    var options: Options
  }

  struct C: ParsableCommand {
    static let configuration = CommandConfiguration(shouldDisplay: false)

    enum Color: String, CaseIterable, ExpressibleByArgument {
      case blue
      case red
      case yellow

      var defaultValueDescription: String {
        switch self {
        case .blue:
          return "A blue color, like the sky!"
        case .red:
          return "A red color, like a rose!"
        case .yellow:
          return "A yellow color, like the sun!"
        }
      }
    }

    @Option(help: "A color to select.")
    var color: Color

    @Option(help: "Another color to select!")
    var defaultColor: Color = .red

    @Option(help: "An optional color.")
    var opt: Color?

    @Option(
      help: .init(
        discussion:
          "A preamble for the list of values in the discussion section."))
    var extra: Color

    @Option(help: .init(discussion: "A discussion."))
    var discussion: String
  }
}

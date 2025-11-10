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

final class MathExampleTests: XCTestCase {
  override func setUp() {
    Platform.Environment[.columns] = nil
  }

  func testMath_Simple() throws {
    try AssertExecuteCommand(command: "math 1 2 3 4 5", expected: "15\n")
    try AssertExecuteCommand(
      command: "math multiply 1 2 3 4 5", expected: "120\n")
  }

  func testMath_Help() throws {
    let helpText = """
      OVERVIEW: A utility for performing maths.

      USAGE: math <subcommand>

      OPTIONS:
        --version               Show the version.
        -h, --help              Show help information.

      SUBCOMMANDS:
        add (default)           Print the sum of the values.
        multiply, mul           Print the product of the values.
        stats                   Calculate descriptive statistics.

        See 'math help <subcommand>' for detailed help.

      """

    try AssertExecuteCommand(command: "math -h", expected: helpText)
    try AssertExecuteCommand(command: "math --help", expected: helpText)
    try AssertExecuteCommand(command: "math help", expected: helpText)
  }

  func testMath_AddHelp() throws {
    let helpText = """
      OVERVIEW: Print the sum of the values.

      USAGE: math add [--hex-output] [<values> ...]

      ARGUMENTS:
        <values>                A group of integers to operate on.

      OPTIONS:
        -x, --hex-output        Use hexadecimal notation for the result.
        --version               Show the version.
        -h, --help              Show help information.


      """

    try AssertExecuteCommand(command: "math add -h", expected: helpText)
    try AssertExecuteCommand(command: "math add --help", expected: helpText)
    try AssertExecuteCommand(command: "math help add", expected: helpText)

    // Verify that extra help flags are ignored.
    try AssertExecuteCommand(command: "math help add -h", expected: helpText)
    try AssertExecuteCommand(command: "math help add -help", expected: helpText)
    try AssertExecuteCommand(
      command: "math help add --help", expected: helpText)
  }

  func testMath_StatsMeanHelp() throws {
    let helpText = """
      OVERVIEW: Print the average of the values.

      USAGE: math stats average [--kind <kind>] [<values> ...]

      ARGUMENTS:
        <values>                A group of floating-point values to operate on.

      OPTIONS:
        --kind <kind>           The kind of average to provide. (values: mean,
                                median, mode; default: mean)
        --version               Show the version.
        -h, --help              Show help information.


      """

    try AssertExecuteCommand(
      command: "math stats average -h", expected: helpText)
    try AssertExecuteCommand(
      command: "math stats average --help", expected: helpText)
    try AssertExecuteCommand(
      command: "math help stats average", expected: helpText)
  }

  func testMath_StatsQuantilesHelp() throws {
    let helpText = """
      OVERVIEW: Print the quantiles of the values (TBD).

      USAGE: math stats quantiles [<one-of-four>] [<custom-arg>] [<custom-deprecated-arg>] [<values> ...] [--file <file>] [--directory <directory>] [--shell <shell>] [--custom <custom>] [--custom-deprecated <custom-deprecated>]

      ARGUMENTS:
        <one-of-four>
        <custom-arg>
        <custom-deprecated-arg>
        <values>                A group of floating-point values to operate on.

      OPTIONS:
        --file <file>
        --directory <directory>
        --shell <shell>
        --custom <custom>
        --custom-deprecated <custom-deprecated>
        --version               Show the version.
        -h, --help              Show help information.


      """

    // The "quantiles" subcommand's run() method is unimplemented, so it
    // just generates the help text.
    try AssertExecuteCommand(
      command: "math stats quantiles", expected: helpText)

    try AssertExecuteCommand(
      command: "math stats quantiles -h", expected: helpText)
    try AssertExecuteCommand(
      command: "math stats quantiles --help", expected: helpText)
    try AssertExecuteCommand(
      command: "math help stats quantiles", expected: helpText)
  }

  func testMath_CustomValidation() throws {
    try AssertExecuteCommand(
      command: "math stats average --kind mode",
      expected: """
        Error: Please provide at least one value to calculate the mode.
        Usage: math stats average [--kind <kind>] [<values> ...]
          See 'math stats average --help' for more information.

        """,
      exitCode: .validationFailure)
  }

  func testMath_Versions() throws {
    try AssertExecuteCommand(
      command: "math --version",
      expected: "1.0.0\n")
    try AssertExecuteCommand(
      command: "math stats --version",
      expected: "1.0.0\n")
    try AssertExecuteCommand(
      command: "math stats average --version",
      expected: "1.5.0-alpha\n")
  }

  func testMath_ExitCodes() throws {
    try AssertExecuteCommand(
      command: "math stats quantiles --test-success-exit-code",
      expected: "",
      exitCode: .success)
    try AssertExecuteCommand(
      command: "math stats quantiles --test-failure-exit-code",
      expected: "",
      exitCode: .failure)
    try AssertExecuteCommand(
      command: "math stats quantiles --test-validation-exit-code",
      expected: "",
      exitCode: .validationFailure)
    try AssertExecuteCommand(
      command: "math stats quantiles --test-custom-exit-code 42",
      expected: "",
      exitCode: ExitCode(42))
  }

  func testMath_Fail() throws {
    try AssertExecuteCommand(
      command: "math --foo",
      expected: """
        Error: Unknown option '--foo'
        Usage: math add [--hex-output] [<values> ...]
          See 'math add --help' for more information.

        """,
      exitCode: .validationFailure)

    try AssertExecuteCommand(
      command: "math ZZZ",
      expected: """
        Error: The value 'ZZZ' is invalid for '<values>'
        Help:  <values>  A group of integers to operate on.
        Usage: math add [--hex-output] [<values> ...]
          See 'math add --help' for more information.

        """,
      exitCode: .validationFailure)
  }
}

// MARK: - Completion Script

// swift-format-ignore: AlwaysUseLowerCamelCase
// https://github.com/apple/swift-argument-parser/issues/710
extension MathExampleTests {
  func testMathBashCompletionScript() throws {
    let script = try AssertExecuteCommand(
      command: "math --generate-completion-script bash")
    try assertSnapshot(actual: script, extension: "bash")
  }

  func testMathZshCompletionScript() throws {
    let script = try AssertExecuteCommand(
      command: "math --generate-completion-script zsh")
    try assertSnapshot(actual: script, extension: "zsh")
  }

  func testMathFishCompletionScript() throws {
    let script = try AssertExecuteCommand(
      command: "math --generate-completion-script fish")
    try assertSnapshot(actual: script, extension: "fish")
  }

  func testMath_BashCustomCompletion() throws {
    try testMath_CustomCompletion(forShell: .bash)
  }

  func testMath_FishCustomCompletion() throws {
    try testMath_CustomCompletion(forShell: .fish)
  }

  func testMath_ZshCustomCompletion() throws {
    try testMath_CustomCompletion(forShell: .zsh)
  }

  private func testMath_CustomCompletion(
    forShell shell: CompletionShell
  ) throws {
    try AssertExecuteCommand(
      command: "math ---completion stats quantiles -- --custom 0 0",
      expected: shell.format(completions: [
        "hello",
        "helicopter",
        "heliotrope",
      ]) + "\n",
      environment: [
        Platform.Environment.Key.shellName.rawValue: shell.rawValue
      ]
    )

    try AssertExecuteCommand(
      command: "math ---completion stats quantiles -- --custom 0 1 h",
      expected: shell.format(completions: [
        "hello",
        "helicopter",
        "heliotrope",
      ]) + "\n",
      environment: [
        Platform.Environment.Key.shellName.rawValue: shell.rawValue
      ]
    )

    try AssertExecuteCommand(
      command: "math ---completion stats quantiles -- --custom 0 1 a",
      expected: shell.format(completions: [
        "aardvark",
        "aaaaalbert",
      ]) + "\n",
      environment: [
        Platform.Environment.Key.shellName.rawValue: shell.rawValue
      ]
    )
  }
}

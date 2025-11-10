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

private func candidates(prefix: String) -> [String] {
  switch CompletionShell.requesting {
  case CompletionShell.bash:
    return ["\(prefix)1_bash", "\(prefix)2_bash", "\(prefix)3_bash"]
  case CompletionShell.fish:
    return ["\(prefix)1_fish", "\(prefix)2_fish", "\(prefix)3_fish"]
  case CompletionShell.zsh:
    return ["\(prefix)1_zsh", "\(prefix)2_zsh", "\(prefix)3_zsh"]
  default:
    return []
  }
}

private func candidatesAsync(prefix: String) async -> [String] {
  candidates(prefix: prefix)
}

final class CompletionScriptTests: XCTestCase {}

// swift-format-ignore: AlwaysUseLowerCamelCase
// https://github.com/apple/swift-argument-parser/issues/710
extension CompletionScriptTests {
  struct Path: ExpressibleByArgument {
    var path: String

    init?(argument: String) {
      self.path = argument
    }

    static var defaultCompletionKind: CompletionKind {
      .file()
    }
  }

  enum Kind:
    String,
    ExpressibleByArgument,
    EnumerableFlag,
    CustomStringConvertible
  {
    case one, two
    case three = "custom-three"
  }

  struct NestedArguments: ParsableArguments {
    @Argument(completion: .custom { _, _, _ in candidates(prefix: "a") })
    var nestedArgument: String
  }

  struct Base: ParsableCommand {
    static let configuration = CommandConfiguration(
      commandName: "base-test",
      subcommands: [SubCommand.self, HiddenChild.self, EscapedCommand.self])

    @Option(help: "The user's name.") var name: String
    @Option() var kind: Kind
    @Option(completion: .list(candidates(prefix: "b"))) var otherKind: Kind

    @Option() var path1: Path
    @Option() var path2: Path?
    @Option(completion: .list(candidates(prefix: "c"))) var path3: Path

    @Flag(help: .hidden) var verbose = false
    @Flag var allowedKinds: [Kind] = []
    @Flag var kindCounter: Int

    @Option() var rep1: [String]
    @Option(name: [.short, .long]) var rep2: [String]

    @Argument(completion: .custom { _, _, _ in candidates(prefix: "d") })
    var argument: String
    @OptionGroup var nested: NestedArguments

    struct SubCommand: ParsableCommand {
      static let configuration = CommandConfiguration(
        commandName: "sub-command")
    }

    struct HiddenChild: ParsableCommand {
      static let configuration = CommandConfiguration(shouldDisplay: false)
    }

    struct EscapedCommand: ParsableCommand {
      @Option(
        name: .customLong("o:n[e"),
        help: ArgumentHelp(
          #"Escaped chars: '[]\."#, valueName: "path[:options]"
        )
      )
      var one: String

      @Argument(completion: .custom { _, _, _ in candidates(prefix: "i") })
      var two: String
    }
  }

  func testBase_Zsh() throws {
    let script1 = try CompletionsGenerator(command: Base.self, shell: .zsh)
      .generateCompletionScript()
    try assertSnapshot(actual: script1, extension: "zsh")

    let script2 = try CompletionsGenerator(command: Base.self, shellName: "zsh")
      .generateCompletionScript()
    try assertSnapshot(actual: script2, extension: "zsh")

    let script3 = Base.completionScript(for: .zsh)
    try assertSnapshot(actual: script3, extension: "zsh")
  }

  func testBase_Bash() throws {
    let script1 = try CompletionsGenerator(command: Base.self, shell: .bash)
      .generateCompletionScript()
    try assertSnapshot(actual: script1, extension: "bash")

    let script2 = try CompletionsGenerator(
      command: Base.self, shellName: "bash"
    )
    .generateCompletionScript()
    try assertSnapshot(actual: script2, extension: "bash")

    let script3 = Base.completionScript(for: .bash)
    try assertSnapshot(actual: script3, extension: "bash")
  }

  func testBase_Fish() throws {
    let script1 = try CompletionsGenerator(command: Base.self, shell: .fish)
      .generateCompletionScript()
    try assertSnapshot(actual: script1, extension: "fish")

    let script2 = try CompletionsGenerator(
      command: Base.self, shellName: "fish"
    )
    .generateCompletionScript()
    try assertSnapshot(actual: script2, extension: "fish")

    let script3 = Base.completionScript(for: .fish)
    try assertSnapshot(actual: script3, extension: "fish")
  }
}

extension CompletionScriptTests {
  struct Custom: ParsableCommand {
    @Option(
      name: .shortAndLong,
      completion: .custom { _, _, _ in candidates(prefix: "e") }
    )
    var one: String

    @Argument(completion: .custom { _, _, _ in candidates(prefix: "f") })
    var two: String

    @Option(
      name: .customShort("z"),
      completion: .custom { _, _, _ in candidates(prefix: "g") }
    )
    var three: String

    @OptionGroup var nested: NestedArguments

    struct NestedArguments: ParsableArguments {
      @Argument(completion: .custom { _, _, _ in candidates(prefix: "h") })
      var four: String
    }

    @Argument(
      completion: .custom { _, _, _ in await candidatesAsync(prefix: "j") }
    )
    var five: String
  }

  func assertCustomCompletion(
    _ arg: String,
    shell: CompletionShell,
    prefix: String = "",
    file: StaticString = #filePath,
    line: UInt = #line
  ) throws {
    #if !os(Windows) && !os(WASI)
    do {
      Platform.Environment[.shellName, as: CompletionShell.self] = shell
      defer { Platform.Environment[.shellName] = nil }
      _ = try Custom.parse(["---completion", "--", arg, "0", "0"])
      XCTFail("Didn't error as expected", file: file, line: line)
    } catch let error as CommandError {
      guard case .completionScriptCustomResponse(let output) = error.parserError
      else {
        throw error
      }
      AssertEqualStrings(
        actual: output,
        expected: shell.format(completions: [
          "\(prefix)1_\(shell.rawValue)",
          "\(prefix)2_\(shell.rawValue)",
          "\(prefix)3_\(shell.rawValue)",
        ]),
        file: file,
        line: line)
    }
    #endif
  }

  func assertCustomCompletions(
    shell: CompletionShell,
    file: StaticString = #filePath,
    line: UInt = #line
  ) throws {
    #if !os(Windows) && !os(WASI)
    try assertCustomCompletion(
      "-o", shell: shell, prefix: "e", file: file, line: line)
    try assertCustomCompletion(
      "--one", shell: shell, prefix: "e", file: file, line: line)
    try assertCustomCompletion(
      "two", shell: shell, prefix: "f", file: file, line: line)
    try assertCustomCompletion(
      "-z", shell: shell, prefix: "g", file: file, line: line)
    try assertCustomCompletion(
      "nested.four", shell: shell, prefix: "h", file: file, line: line)
    try assertCustomCompletion(
      "five", shell: shell, prefix: "j", file: file, line: line)

    XCTAssertThrowsError(
      try assertCustomCompletion("--bad", shell: shell, file: file, line: line))
    XCTAssertThrowsError(
      try assertCustomCompletion("four", shell: shell, file: file, line: line))
    #endif
  }

  func testBashCustomCompletions() throws {
    try assertCustomCompletions(shell: .bash)
  }

  func testFishCustomCompletions() throws {
    try assertCustomCompletions(shell: .fish)
  }

  func testZshCustomCompletions() throws {
    try assertCustomCompletions(shell: .zsh)
  }
}

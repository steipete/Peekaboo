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
import ArgumentParserToolInfo
import XCTest

@testable import ArgumentParser

final class DefaultSubcommandEndToEndTests: XCTestCase {
}

// MARK: -

private struct Main: ParsableCommand {
  static let configuration = CommandConfiguration(
    subcommands: [Default.self, Foo.self, Bar.self],
    defaultSubcommand: Default.self
  )
}

private struct Default: ParsableCommand {
  enum Mode: String, CaseIterable, ExpressibleByArgument {
    case foo, bar, baz
  }

  @Option var mode: Mode = .foo
}

private struct Foo: ParsableCommand {}
private struct Bar: ParsableCommand {}

extension DefaultSubcommandEndToEndTests {
  func testDefaultSubcommand() {
    AssertParseCommand(Main.self, Default.self, []) { def in
      XCTAssertEqual(.foo, def.mode)
    }

    AssertParseCommand(Main.self, Default.self, ["--mode=bar"]) { def in
      XCTAssertEqual(.bar, def.mode)
    }

    AssertParseCommand(Main.self, Default.self, ["--mode", "bar"]) { def in
      XCTAssertEqual(.bar, def.mode)
    }

    AssertParseCommand(Main.self, Default.self, ["--mode", "baz"]) { def in
      XCTAssertEqual(.baz, def.mode)
    }
  }

  func testNonDefaultSubcommand() {
    AssertParseCommand(Main.self, Foo.self, ["foo"]) { _ in }
    AssertParseCommand(Main.self, Bar.self, ["bar"]) { _ in }

    AssertParseCommand(Main.self, Default.self, ["default", "--mode", "bar"]) {
      def in
      XCTAssertEqual(.bar, def.mode)
    }
  }

  func testParsingFailure() {
    XCTAssertThrowsError(try Main.parseAsRoot(["--mode", "qux"]))
    XCTAssertThrowsError(try Main.parseAsRoot(["qux"]))
  }
}

extension DefaultSubcommandEndToEndTests {
  fileprivate struct MyCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
      subcommands: [
        Plugin.self, NonDefault.self, Other.self, Child.self, BadParent.self,
      ],
      defaultSubcommand: Plugin.self
    )

    @Option var foo: String?

    @OptionGroup
    var options: CommonOptions
  }

  fileprivate struct CommonOptions: ParsableArguments {
    @Flag(
      name: [.customLong("verbose"), .customShort("v")],
      help: "Enable verbose aoutput.")
    var verbose = false
  }

  fileprivate struct Plugin: ParsableCommand {
    @OptionGroup var options: CommonOptions
    @Argument var pluginName: String

    @Argument(parsing: .captureForPassthrough)
    var pluginArguments: [String] = []
  }

  fileprivate struct NonDefault: ParsableCommand {
    @OptionGroup var options: CommonOptions
    @Argument var pluginName: String

    @Argument(parsing: .captureForPassthrough)
    var pluginArguments: [String] = []
  }

  fileprivate struct Other: ParsableCommand {
    @OptionGroup var options: CommonOptions
  }

  fileprivate struct Child: ParsableCommand {
    @ParentCommand var parent: MyCommand
  }

  fileprivate struct BadParent: ParsableCommand {
    @ParentCommand var notMyParent: Other
  }

  func testAccessToParent() throws {
    AssertParseCommand(
      MyCommand.self, Child.self, ["--verbose", "--foo=bar", "child"]
    ) { child in
      XCTAssertEqual(child.parent.foo, "bar")
      XCTAssertEqual(child.parent.options.verbose, true)
    }
  }

  func testNotMyParent() throws {
    AssertParseCommandErrorMessage(
      MyCommand.self, BadParent.self, ["--verbose", "bad-parent"],
      "Command 'Other' is not a parent of the current command.")
  }

  func testNotLeakingParentOptions() throws {
    // Verify that the help for the child command doesn't leak the parent command's options in the help
    let childHelp = MyCommand.message(for: CleanExit.helpRequest(Child.self))
    XCTAssertEqual(
      childHelp,
      """
      USAGE: my-command child

      OPTIONS:
        -h, --help              Show help information.

      """)

    // Now check that the foo option doesn't leak into the JSON dump
    let toolInfo = ToolInfoV0(commandStack: [MyCommand.self.asCommand])

    let arguments = toolInfo.command.arguments
    guard let arguments else {
      XCTFail(
        "MyCommand is expected to have a top-level command arguments in its tool info"
      )
      return
    }

    let subcommands = toolInfo.command.subcommands
    guard let subcommands else {
      XCTFail(
        "MyCommand is expected to have a top-level command arguments in its tool info"
      )
      return
    }

    // The foo option is present int he parent
    XCTAssertNotNil(arguments.first { $0.valueName == "foo" })

    let childInfo = subcommands.first { cmd in
      cmd.commandName == "child"
    }

    guard let childInfo else {
      XCTFail("The child subcommand is expected to be present in the tool info")
      return
    }

    guard let childArguments = childInfo.arguments else {
      XCTFail(
        "The child subcommand is expected to have arguments in the tool info")
      return
    }

    // It's not there in the child subcommand
    XCTAssertNil(childArguments.first { $0.valueName == "foo" })
  }

  func testRemainingDefaultImplicit() throws {
    AssertParseCommand(MyCommand.self, Plugin.self, ["my-plugin"]) { plugin in
      XCTAssertEqual(plugin.pluginName, "my-plugin")
      XCTAssertEqual(plugin.pluginArguments, [])
      XCTAssertEqual(plugin.options.verbose, false)
    }
    AssertParseCommand(MyCommand.self, Plugin.self, ["my-plugin", "--verbose"])
    { plugin in
      XCTAssertEqual(plugin.pluginName, "my-plugin")
      XCTAssertEqual(plugin.pluginArguments, ["--verbose"])
      XCTAssertEqual(plugin.options.verbose, false)
    }
    AssertParseCommand(
      MyCommand.self, Plugin.self, ["--verbose", "my-plugin", "--verbose"]
    ) { plugin in
      XCTAssertEqual(plugin.pluginName, "my-plugin")
      XCTAssertEqual(plugin.pluginArguments, ["--verbose"])
      XCTAssertEqual(plugin.options.verbose, true)
    }
    AssertParseCommand(MyCommand.self, Plugin.self, ["my-plugin", "--help"]) {
      plugin in
      XCTAssertEqual(plugin.pluginName, "my-plugin")
      XCTAssertEqual(plugin.pluginArguments, ["--help"])
      XCTAssertEqual(plugin.options.verbose, false)
    }
  }

  func testRemainingDefaultExplicit() throws {
    AssertParseCommand(MyCommand.self, Plugin.self, ["plugin", "my-plugin"]) {
      plugin in
      XCTAssertEqual(plugin.pluginName, "my-plugin")
      XCTAssertEqual(plugin.pluginArguments, [])
      XCTAssertEqual(plugin.options.verbose, false)
    }
    AssertParseCommand(
      MyCommand.self, Plugin.self, ["plugin", "my-plugin", "--verbose"]
    ) { plugin in
      XCTAssertEqual(plugin.pluginName, "my-plugin")
      XCTAssertEqual(plugin.pluginArguments, ["--verbose"])
      XCTAssertEqual(plugin.options.verbose, false)
    }
    AssertParseCommand(
      MyCommand.self, Plugin.self,
      ["--verbose", "plugin", "my-plugin", "--verbose"]
    ) { plugin in
      XCTAssertEqual(plugin.pluginName, "my-plugin")
      XCTAssertEqual(plugin.pluginArguments, ["--verbose"])
      XCTAssertEqual(plugin.options.verbose, true)
    }
    AssertParseCommand(
      MyCommand.self, Plugin.self,
      ["--verbose", "plugin", "my-plugin", "--help"]
    ) { plugin in
      XCTAssertEqual(plugin.pluginName, "my-plugin")
      XCTAssertEqual(plugin.pluginArguments, ["--help"])
      XCTAssertEqual(plugin.options.verbose, true)
    }
  }

  func testRemainingNonDefault() throws {
    AssertParseCommand(
      MyCommand.self, NonDefault.self, ["non-default", "my-plugin"]
    ) { nondef in
      XCTAssertEqual(nondef.pluginName, "my-plugin")
      XCTAssertEqual(nondef.pluginArguments, [])
      XCTAssertEqual(nondef.options.verbose, false)
    }
    AssertParseCommand(
      MyCommand.self, NonDefault.self,
      ["non-default", "my-plugin", "--verbose"]
    ) { nondef in
      XCTAssertEqual(nondef.pluginName, "my-plugin")
      XCTAssertEqual(nondef.pluginArguments, ["--verbose"])
      XCTAssertEqual(nondef.options.verbose, false)
    }
    AssertParseCommand(
      MyCommand.self, NonDefault.self,
      ["--verbose", "non-default", "my-plugin", "--verbose"]
    ) { nondef in
      XCTAssertEqual(nondef.pluginName, "my-plugin")
      XCTAssertEqual(nondef.pluginArguments, ["--verbose"])
      XCTAssertEqual(nondef.options.verbose, true)
    }
    AssertParseCommand(
      MyCommand.self, NonDefault.self,
      ["--verbose", "non-default", "my-plugin", "--help"]
    ) { nondef in
      XCTAssertEqual(nondef.pluginName, "my-plugin")
      XCTAssertEqual(nondef.pluginArguments, ["--help"])
      XCTAssertEqual(nondef.options.verbose, true)
    }
  }

  func testRemainingDefaultOther() throws {
    AssertParseCommand(MyCommand.self, Other.self, ["other"]) { other in
      XCTAssertEqual(other.options.verbose, false)
    }
    AssertParseCommand(MyCommand.self, Other.self, ["other", "--verbose"]) {
      other in
      XCTAssertEqual(other.options.verbose, true)
    }
  }

  func testRemainingDefaultFailure() {
    XCTAssertThrowsError(try MyCommand.parseAsRoot([]))
    XCTAssertThrowsError(try MyCommand.parseAsRoot(["--verbose"]))
    XCTAssertThrowsError(
      try MyCommand.parseAsRoot(["plugin", "--verbose", "my-plugin"]))
  }
}

extension DefaultSubcommandEndToEndTests {
  struct RootWithPassthroughDefault: ParsableCommand {
    static let configuration = CommandConfiguration(
      subcommands: [PassthroughDefault.self],
      defaultSubcommand: PassthroughDefault.self,
      helpNames: [.short, .long, .customLong("help", withSingleDash: true)]
    )
  }

  struct PassthroughDefault: ParsableCommand {
    @Argument(parsing: .captureForPassthrough)
    var remaining: [String] = []
  }

  // Test fix for https://github.com/apple/swift-package-manager/issues/7218
  func testHelpWithPassthroughDefault() throws {
    AssertParseCommand(
      RootWithPassthroughDefault.self, HelpCommand.self, ["-h"]
    ) { _ in }
    AssertParseCommand(
      RootWithPassthroughDefault.self, HelpCommand.self, ["-help"]
    ) { _ in }
    AssertParseCommand(
      RootWithPassthroughDefault.self, HelpCommand.self, ["--help"]
    ) { _ in }
  }
}

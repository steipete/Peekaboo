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

final class HelpGenerationTests: XCTestCase {
}

extension Foundation.URL: ArgumentParser.ExpressibleByArgument {
  public init?(argument: String) {
    guard let url = URL(string: argument) else {
      return nil
    }
    self = url
  }

  public var defaultValueDescription: String {
    self.path
  }
}

// MARK: -

extension HelpGenerationTests {
  struct A: ParsableArguments {
    @Option(help: "Your name") var name: String
    @Option(help: "Your title") var title: String?
  }

  func testHelp() {
    AssertHelp(
      .default, for: A.self,
      equals: """
        USAGE: a --name <name> [--title <title>]

        OPTIONS:
          --name <name>           Your name
          --title <title>         Your title
          -h, --help              Show help information.

        """)
  }

  struct B: ParsableArguments {
    @Option(help: "Your name") var name: String
    @Option(help: "Your title") var title: String?

    @Argument(help: .hidden) var hiddenName: String?
    @Option(help: .hidden) var hiddenTitle: String?
    @Flag(help: .hidden) var hiddenFlag: Bool = false
    @Flag(inversion: .prefixedNo, help: .hidden) var hiddenInvertedFlag: Bool =
      true
  }

  func testHelpWithHidden() {
    AssertHelp(
      .default, for: B.self,
      equals: """
        USAGE: b --name <name> [--title <title>]

        OPTIONS:
          --name <name>           Your name
          --title <title>         Your title
          -h, --help              Show help information.

        """)

    AssertHelp(
      .hidden, for: B.self,
      equals: """
        USAGE: b --name <name> [--title <title>] [<hidden-name>] [--hidden-title <hidden-title>] [--hidden-flag] [--hidden-inverted-flag] [--no-hidden-inverted-flag]

        ARGUMENTS:
          <hidden-name>

        OPTIONS:
          --name <name>           Your name
          --title <title>         Your title
          --hidden-title <hidden-title>
          --hidden-flag
          --hidden-inverted-flag/--no-hidden-inverted-flag
                                  (default: --hidden-inverted-flag)
          -h, --help              Show help information.

        """)
  }

  struct C: ParsableArguments {
    @Option(
      help: ArgumentHelp(
        "Your name.",
        discussion: "Your name is used to greet you and say hello."))
    var name: String
  }

  func testHelpWithDiscussion() {
    AssertHelp(
      .default, for: C.self,
      equals: """
        USAGE: c --name <name>

        OPTIONS:
          --name <name>           Your name.
                Your name is used to greet you and say hello.
          -h, --help              Show help information.

        """)
  }

  struct Issue27: ParsableArguments {
    @Option
    var two: String = "42"
    @Option(help: "The third option")
    var three: String
    @Option(help: "A fourth option")
    var four: String?
    @Option(help: "A fifth option")
    var five: String = ""
  }

  func testHelpWithDefaultValueButNoDiscussion() {
    AssertHelp(
      .default, for: Issue27.self,
      equals: """
        USAGE: issue27 [--two <two>] --three <three> [--four <four>] [--five <five>]

        OPTIONS:
          --two <two>             (default: 42)
          --three <three>         The third option
          --four <four>           A fourth option
          --five <five>           A fifth option
          -h, --help              Show help information.

        """)
  }

  enum OptionFlags: String, EnumerableFlag { case optional, required }
  enum Degree {
    case bachelor, graduate, doctorate

    @Sendable
    static func degreeTransform(_ string: String) throws -> Degree {
      switch string {
      case "bachelor":
        return .bachelor
      case "graduate":
        return .graduate
      case "doctorate":
        return .doctorate
      default:
        throw ValidationError("Not a valid string for 'Degree'")
      }
    }
  }

  struct D: ParsableCommand {
    @Argument(help: "Your occupation.")
    var occupation: String = "--"

    @Option(help: "Your name.")
    var name: String = "John"

    @Option(help: "Your age.")
    var age: Int = 20

    @Option(help: "Whether logging is enabled.")
    var logging: Bool = false

    @Option(
      parsing: .upToNextOption,
      help: ArgumentHelp("Your lucky numbers.", valueName: "numbers"))
    var lucky: [Int] = [7, 14]

    @Flag(help: "Vegan diet.")
    var nda: OptionFlags = .optional

    @Option(help: "Your degree.", transform: Degree.degreeTransform)
    var degree: Degree = .bachelor

    @Option(help: "Directory.")
    var directory: URL = URL(fileURLWithPath: "/path/to/file")

    enum Manual: Int, ExpressibleByArgument {
      case foo
      var defaultValueDescription: String { "default-value" }
    }
    @Option(help: "Manual Option.")
    var manual: Manual = .foo

    enum UnspecializedSynthesized: Int, CaseIterable, ExpressibleByArgument {
      case one, two
    }
    @Option(help: "Unspecialized Synthesized")
    var unspecial: UnspecializedSynthesized = .one

    enum SpecializedSynthesized: String, CaseIterable, ExpressibleByArgument {
      case apple = "Apple"
      case banana = "Banana"
    }
    @Option(help: "Specialized Synthesized")
    var special: SpecializedSynthesized = .apple
  }

  func testHelpWithDefaultValues() {
    AssertHelp(
      .default, for: D.self,
      equals: """
        USAGE: d [<occupation>] [--name <name>] [--age <age>] [--logging <logging>] [--lucky <numbers> ...] [--optional] [--required] [--degree <degree>] [--directory <directory>] [--manual <manual>] [--unspecial <unspecial>] [--special <special>]

        ARGUMENTS:
          <occupation>            Your occupation. (default: --)

        OPTIONS:
          --name <name>           Your name. (default: John)
          --age <age>             Your age. (default: 20)
          --logging <logging>     Whether logging is enabled. (default: false)
          --lucky <numbers>       Your lucky numbers. (default: 7, 14)
          --optional/--required   Vegan diet. (default: --optional)
          --degree <degree>       Your degree.
          --directory <directory> Directory. (default: /path/to/file)
          --manual <manual>       Manual Option. (default: default-value)
          --unspecial <unspecial> Unspecialized Synthesized (values: 0, 1; default: 0)
          --special <special>     Specialized Synthesized (values: Apple, Banana;
                                  default: Apple)
          -h, --help              Show help information.

        """)
  }

  struct E: ParsableCommand {
    enum OutputBehaviour: String, EnumerableFlag {
      case stats, count, list

      static func name(for value: OutputBehaviour) -> NameSpecification {
        .shortAndLong
      }
    }

    @Flag(help: "Change the program output")
    var behaviour: OutputBehaviour
  }

  struct F: ParsableCommand {
    enum OutputBehaviour: String, EnumerableFlag {
      case stats, count, list

      static func name(for value: OutputBehaviour) -> NameSpecification {
        .short
      }
    }

    @Flag(help: "Change the program output")
    var behaviour: OutputBehaviour = .list
  }

  struct G: ParsableCommand {
    @Flag(inversion: .prefixedNo, help: "Whether to flag")
    var flag: Bool = false
  }

  func testHelpWithMutuallyExclusiveFlags() {
    AssertHelp(
      .default, for: E.self,
      equals: """
        USAGE: e --stats --count --list

        OPTIONS:
          -s, --stats/-c, --count/-l, --list
                                  Change the program output
          -h, --help              Show help information.

        """)

    AssertHelp(
      .default, for: F.self,
      equals: """
        USAGE: f [-s] [-c] [-l]

        OPTIONS:
          -s/-c/-l                Change the program output (default: -l)
          -h, --help              Show help information.

        """)

    AssertHelp(
      .default, for: G.self,
      equals: """
        USAGE: g [--flag] [--no-flag]

        OPTIONS:
          --flag/--no-flag        Whether to flag (default: --no-flag)
          -h, --help              Show help information.

        """)
  }

  struct H: ParsableCommand {
    struct CommandWithVeryLongName: ParsableCommand {}
    struct ShortCommand: ParsableCommand {
      static let configuration: CommandConfiguration = CommandConfiguration(
        abstract: "Test short command name.")
    }
    struct AnotherCommandWithVeryLongName: ParsableCommand {
      static let configuration: CommandConfiguration = CommandConfiguration(
        abstract: "Test long command name.")
    }
    struct AnotherCommand: ParsableCommand {
      @Option()
      var someOptionWithVeryLongName: String?

      @Option()
      var option: String?

      @Argument(help: "This is an argument with a long name.")
      var argumentWithVeryLongNameAndHelp: String = ""

      @Argument
      var argumentWithVeryLongName: String = ""

      @Argument
      var argument: String = ""
    }
    static let configuration = CommandConfiguration(subcommands: [
      CommandWithVeryLongName.self, ShortCommand.self,
      AnotherCommandWithVeryLongName.self, AnotherCommand.self,
    ])
  }

  func testHelpWithSubcommands() {
    AssertHelp(
      .default, for: H.self,
      equals: """
        USAGE: h <subcommand>

        OPTIONS:
          -h, --help              Show help information.

        SUBCOMMANDS:
          command-with-very-long-name
          short-command           Test short command name.
          another-command-with-very-long-name
                                  Test long command name.
          another-command

          See 'h help <subcommand>' for detailed help.
        """)

    AssertHelp(
      .default, for: H.AnotherCommand.self, root: H.self,
      equals: """
        USAGE: h another-command [--some-option-with-very-long-name <some-option-with-very-long-name>] [--option <option>] [<argument-with-very-long-name-and-help>] [<argument-with-very-long-name>] [<argument>]

        ARGUMENTS:
          <argument-with-very-long-name-and-help>
                                  This is an argument with a long name.
          <argument-with-very-long-name>
          <argument>

        OPTIONS:
          --some-option-with-very-long-name <some-option-with-very-long-name>
          --option <option>
          -h, --help              Show help information.

        """)
  }

  struct I: ParsableCommand {
    static let configuration = CommandConfiguration(version: "1.0.0")
  }

  func testHelpWithVersion() {
    AssertHelp(
      .default, for: I.self,
      equals: """
        USAGE: i

        OPTIONS:
          --version               Show the version.
          -h, --help              Show help information.

        """)

  }

  struct J: ParsableCommand {
    static let configuration = CommandConfiguration(discussion: "test")
  }

  func testOverviewButNoAbstractSpacing() {
    let renderedHelp = HelpGenerator(J.self, visibility: .default)
      .rendered()
    AssertEqualStrings(
      actual: renderedHelp,
      expected: """
        OVERVIEW: \n\
        test

        USAGE: j

        OPTIONS:
          -h, --help              Show help information.

        """)
  }

  struct K: ParsableCommand {
    @Argument(help: "A list of paths.")
    var paths: [String] = []

    func validate() throws {
      if paths.isEmpty {
        throw ValidationError("At least one path must be specified.")
      }
    }
  }

  func testHelpWithNoValueForArray() {
    AssertHelp(
      .default, for: K.self,
      equals: """
        USAGE: k [<paths> ...]

        ARGUMENTS:
          <paths>                 A list of paths.

        OPTIONS:
          -h, --help              Show help information.

        """)
  }

  struct L: ParsableArguments {
    @Option(
      name: [
        .short, .customLong("remote"), .customLong("remote"), .short,
        .customLong("when"), .long, .customLong("other", withSingleDash: true),
        .customLong("there"), .customShort("x"), .customShort("y"),
      ],
      help: "Help Message")
    var time: String?
  }

  func testHelpWithMultipleCustomNames() {
    AssertHelp(
      .default, for: L.self,
      equals: """
        USAGE: l [--remote <remote>]

        OPTIONS:
          -t, -x, -y, --remote, --when, --time, -other, --there <remote>
                                  Help Message
          -h, --help              Show help information.

        """)
  }

  struct M: ParsableCommand {
  }
  struct N: ParsableCommand {
    static let configuration = CommandConfiguration(
      subcommands: [M.self], defaultSubcommand: M.self)
  }

  func testHelpWithDefaultCommand() {
    AssertHelp(
      .default, for: N.self,
      equals: """
        USAGE: n <subcommand>

        OPTIONS:
          -h, --help              Show help information.

        SUBCOMMANDS:
          m (default)

          See 'n help <subcommand>' for detailed help.
        """)
  }

  enum O: String, ExpressibleByArgument {
    case small
    case medium
    case large

    init?(argument: String) {
      guard let result = Self(rawValue: argument) else {
        return nil
      }
      self = result
    }
  }
  struct P: ParsableArguments {
    @Option(name: [.short], help: "Help Message")
    var o: [O] = [.small, .medium]

    @Argument(help: "Help Message")
    var remainder: [O] = [.large]
  }

  func testHelpWithDefaultValueForArray() {
    AssertHelp(
      .default, for: P.self,
      equals: """
        USAGE: p [-o <o> ...] [<remainder> ...]

        ARGUMENTS:
          <remainder>             Help Message (default: large)

        OPTIONS:
          -o <o>                  Help Message (default: small, medium)
          -h, --help              Show help information.

        """)
  }

  struct Foo: ParsableCommand {
    public static let configuration = CommandConfiguration(
      commandName: "foo",
      abstract: "Perform some foo",
      subcommands: [
        Bar.self
      ],
      helpNames: [.short, .long, .customLong("help", withSingleDash: true)])

    @Option(help: "Name for foo")
    var fooName: String?

    public init() {}
  }

  struct Bar: ParsableCommand {
    static let configuration = CommandConfiguration(
      commandName: "bar",
      _superCommandName: "foo",
      abstract: "Perform bar operations",
      helpNames: [.short, .long, .customLong("help", withSingleDash: true)])

    @Option(help: "Bar Strength")
    var barStrength: String?

    public init() {}
  }

  func testHelpExcludingSuperCommand() throws {
    AssertHelp(
      .default, for: Bar.self, root: Foo.self,
      equals: """
        OVERVIEW: Perform bar operations

        USAGE: foo bar [--bar-strength <bar-strength>]

        OPTIONS:
          --bar-strength <bar-strength>
                                  Bar Strength
          -h, -help, --help       Show help information.

        """)
  }

  struct WithSubgroups: ParsableCommand {
    static let configuration = CommandConfiguration(
      commandName: "subgroupings",
      subcommands: [M.self],
      groupedSubcommands: [
        CommandGroup(
          name: "Broken",
          subcommands: [Foo.self, Bar.self]
        ),
        CommandGroup(name: "Complicated", subcommands: [N.self]),
      ]
    )
  }

  func testHelpSubcommandGroups() throws {
    AssertHelp(
      .default, for: WithSubgroups.self,
      equals: """
        USAGE: subgroupings <subcommand>

        OPTIONS:
          -h, --help              Show help information.

        SUBCOMMANDS:
          m

        BROKEN SUBCOMMANDS:
          foo                     Perform some foo
          bar                     Perform bar operations

        COMPLICATED SUBCOMMANDS:
          n

          See 'subgroupings help <subcommand>' for detailed help.
        """)
  }

  struct OnlySubgroups: ParsableCommand {
    static let configuration = CommandConfiguration(
      commandName: "subgroupings",
      groupedSubcommands: [
        CommandGroup(
          name: "Broken",
          subcommands: [Foo.self, Bar.self]
        ),
        CommandGroup(
          name: "Complicated",
          subcommands: [M.self, N.self]
        ),
      ]
    )
  }

  func testHelpOnlySubcommandGroups() throws {
    AssertHelp(
      .default, for: OnlySubgroups.self,
      equals: """
        USAGE: subgroupings <subcommand>

        OPTIONS:
          -h, --help              Show help information.

        BROKEN SUBCOMMANDS:
          foo                     Perform some foo
          bar                     Perform bar operations

        COMPLICATED SUBCOMMANDS:
          m
          n

          See 'subgroupings help <subcommand>' for detailed help.
        """)
  }
}

extension HelpGenerationTests {
  private struct OptionsToHide: ParsableArguments {
    @Flag(help: "Verbose")
    var verbose: Bool = false

    @Option(help: "Custom Name")
    var customName: String?

    @Option(help: .hidden)
    var hiddenOption: String?

    @Argument(help: .private)
    var privateArg: String?
  }

  @available(*, deprecated)
  private struct HideOptionGroupLegacyDriver: ParsableCommand {
    static let configuration = CommandConfiguration(
      commandName: "driver", abstract: "Demo hiding option groups")

    @OptionGroup(_hiddenFromHelp: true)
    var hideMe: OptionsToHide

    @Option(help: "Time to wait before timeout (in seconds)")
    var timeout: Int?
  }

  private struct HideOptionGroupDriver: ParsableCommand {
    static let configuration = CommandConfiguration(
      commandName: "driver", abstract: "Demo hiding option groups")

    @OptionGroup(visibility: .hidden)
    var hideMe: OptionsToHide

    @Option(help: "Time to wait before timeout (in seconds)")
    var timeout: Int?
  }

  private struct PrivateOptionGroupDriver: ParsableCommand {
    static let configuration = CommandConfiguration(
      commandName: "driver", abstract: "Demo hiding option groups")

    @OptionGroup(visibility: .private)
    var hideMe: OptionsToHide

    @Option(help: "Time to wait before timeout (in seconds)")
    var timeout: Int?
  }

  private var helpMessage: String {
    """
    OVERVIEW: Demo hiding option groups

    USAGE: driver [--timeout <timeout>]

    OPTIONS:
      --timeout <timeout>     Time to wait before timeout (in seconds)
      -h, --help              Show help information.

    """
  }

  private var helpHiddenMessage: String {
    """
    OVERVIEW: Demo hiding option groups

    USAGE: driver [--verbose] [--custom-name <custom-name>] [--hidden-option <hidden-option>] [--timeout <timeout>]

    OPTIONS:
      --verbose               Verbose
      --custom-name <custom-name>
                              Custom Name
      --hidden-option <hidden-option>
      --timeout <timeout>     Time to wait before timeout (in seconds)
      -h, --help              Show help information.

    """
  }

  @available(*, deprecated)
  func testHidingOptionGroup() throws {
    AssertHelp(
      .default, for: HideOptionGroupLegacyDriver.self, equals: helpMessage)
    AssertHelp(.default, for: HideOptionGroupDriver.self, equals: helpMessage)
    AssertHelp(
      .default, for: PrivateOptionGroupDriver.self, equals: helpMessage)
  }

  @available(*, deprecated)
  func testHelpHiddenShowsDefaultAndHidden() throws {
    AssertHelp(
      .hidden, for: HideOptionGroupLegacyDriver.self, equals: helpHiddenMessage)
    AssertHelp(
      .hidden, for: HideOptionGroupDriver.self, equals: helpHiddenMessage)

    // Note: Private option groups are not visible at `.hidden` help level.
    AssertHelp(.hidden, for: PrivateOptionGroupDriver.self, equals: helpMessage)
  }
}

extension HelpGenerationTests {
  struct AllValues: ParsableCommand {
    enum Manual: Int, ExpressibleByArgument {
      case foo
      static let allValueStrings = ["bar"]
    }

    enum UnspecializedSynthesized: Int, CaseIterable, ExpressibleByArgument {
      case one, two
    }

    enum SpecializedSynthesized: String, CaseIterable, ExpressibleByArgument {
      case apple = "Apple"
      case banana = "Banana"
    }

    @Argument var manualArgument: Manual
    @Option var manualOption: Manual

    @Argument var unspecializedSynthesizedArgument: UnspecializedSynthesized
    @Option var unspecializedSynthesizedOption: UnspecializedSynthesized

    @Argument var specializedSynthesizedArgument: SpecializedSynthesized
    @Option var specializedSynthesizedOption: SpecializedSynthesized
  }

  func testAllValueStrings() throws {
    XCTAssertEqual(AllValues.Manual.allValueStrings, ["bar"])
    XCTAssertEqual(
      AllValues.UnspecializedSynthesized.allValueStrings, ["0", "1"])
    XCTAssertEqual(
      AllValues.SpecializedSynthesized.allValueStrings, ["Apple", "Banana"])
  }

  func testAllValues() {
    let opts = ArgumentSet(AllValues.self, visibility: .private, parent: nil)
    XCTAssertEqual(
      AllValues.Manual.allValueStrings, opts[0].help.allValueStrings)
    XCTAssertEqual(
      AllValues.Manual.allValueStrings, opts[1].help.allValueStrings)

    XCTAssertEqual(
      AllValues.UnspecializedSynthesized.allValueStrings,
      opts[2].help.allValueStrings)
    XCTAssertEqual(
      AllValues.UnspecializedSynthesized.allValueStrings,
      opts[3].help.allValueStrings)

    XCTAssertEqual(
      AllValues.SpecializedSynthesized.allValueStrings,
      opts[4].help.allValueStrings)
    XCTAssertEqual(
      AllValues.SpecializedSynthesized.allValueStrings,
      opts[5].help.allValueStrings)
  }

  struct Q: ParsableArguments {
    @Option(help: "Your name") var name: String
    @Option(help: "Your title") var title: String?

    @Argument(help: .private) var privateName: String?
    @Option(help: .private) var privateTitle: String?
    @Flag(help: .private) var privateFlag: Bool = false
    @Flag(inversion: .prefixedNo, help: .private) var privateInvertedFlag:
      Bool = true
  }

  func testHelpWithPrivate() {
    AssertHelp(
      .default, for: Q.self,
      equals: """
        USAGE: q --name <name> [--title <title>]

        OPTIONS:
          --name <name>           Your name
          --title <title>         Your title
          -h, --help              Show help information.

        """)
  }
}

// MARK: - Issue #278 https://github.com/apple/swift-argument-parser/issues/278

extension HelpGenerationTests {
  private struct ParserBug: ParsableCommand {
    static let configuration = CommandConfiguration(
      commandName: "parserBug",
      subcommands: [Sub.self])

    struct CommonOptions: ParsableCommand {
      @Flag(help: "example flag")
      var example: Bool = false
    }

    struct Sub: ParsableCommand {
      @OptionGroup()
      var commonOptions: CommonOptions

      @Argument(help: "Non-mandatory argument")
      var argument: String?
    }
  }

  func testIssue278() {
    AssertHelp(
      .default, for: ParserBug.Sub.self, root: ParserBug.self,
      equals: """
        USAGE: parserBug sub [--example] [<argument>]

        ARGUMENTS:
          <argument>              Non-mandatory argument

        OPTIONS:
          --example               example flag
          -h, --help              Show help information.

        """)
  }
}

// swift-format-ignore: AlwaysUseLowerCamelCase
// https://github.com/apple/swift-argument-parser/issues/710
extension HelpGenerationTests {
  struct NonCustomUsage: ParsableCommand {
    struct ExampleSubcommand: ParsableCommand {
      static let configuration = CommandConfiguration()
      @Argument var output: String
    }

    static let configuration = CommandConfiguration(
      subcommands: [ExampleSubcommand.self])

    @Argument var file: String
    @Flag var verboseMode = false
  }

  struct CustomUsageShort: ParsableCommand {
    static let configuration = CommandConfiguration(
      usage: """
        example [--verbose] <file-name>
        """)

    @Argument var file: String
    @Flag var verboseMode = false
  }

  struct CustomUsageLong: ParsableCommand {
    static let configuration = CommandConfiguration(
      usage: """
        example <file-name>
        example --verbose <file-name>
        example --help
        """)

    @Argument var file: String
    @Flag var verboseMode = false
  }

  struct CustomUsageHidden: ParsableCommand {
    static let configuration = CommandConfiguration(usage: "")

    @Argument var file: String
    @Flag var verboseMode = false
  }

  func test_usageCustomization_helpMessage() {
    AssertEqualStrings(
      actual: NonCustomUsage.helpMessage(columns: 80),
      expected: """
        USAGE: non-custom-usage <file> [--verbose-mode] <subcommand>

        ARGUMENTS:
          <file>

        OPTIONS:
          --verbose-mode
          -h, --help              Show help information.

        SUBCOMMANDS:
          example-subcommand

          See 'non-custom-usage help <subcommand>' for detailed help.
        """)

    AssertEqualStrings(
      actual: NonCustomUsage.helpMessage(
        for: NonCustomUsage.ExampleSubcommand.self, columns: 80),
      expected: """
        USAGE: non-custom-usage example-subcommand <output>

        ARGUMENTS:
          <output>

        OPTIONS:
          -h, --help              Show help information.

        """)

    AssertEqualStrings(
      actual: CustomUsageShort.helpMessage(columns: 80),
      expected: """
        USAGE: example [--verbose] <file-name>

        ARGUMENTS:
          <file>

        OPTIONS:
          --verbose-mode
          -h, --help              Show help information.

        """)

    AssertEqualStrings(
      actual: CustomUsageLong.helpMessage(columns: 80),
      expected: """
        USAGE: example <file-name>
               example --verbose <file-name>
               example --help

        ARGUMENTS:
          <file>

        OPTIONS:
          --verbose-mode
          -h, --help              Show help information.

        """)

    AssertEqualStrings(
      actual: CustomUsageHidden.helpMessage(columns: 80),
      expected: """
        ARGUMENTS:
          <file>

        OPTIONS:
          --verbose-mode
          -h, --help              Show help information.

        """)
  }

  func test_usageCustomization_fullMessage() {
    AssertEqualStrings(
      actual: NonCustomUsage.fullMessage(for: ValidationError("Test")),
      expected: """
        Error: Test
        Usage: non-custom-usage <file> [--verbose-mode] <subcommand>
          See 'non-custom-usage --help' for more information.
        """)

    AssertEqualStrings(
      actual: CustomUsageShort.fullMessage(for: ValidationError("Test")),
      expected: """
        Error: Test
        Usage: example [--verbose] <file-name>
          See 'custom-usage-short --help' for more information.
        """)

    AssertEqualStrings(
      actual: CustomUsageLong.fullMessage(for: ValidationError("Test")),
      expected: """
        Error: Test
        Usage: example <file-name>
               example --verbose <file-name>
               example --help
          See 'custom-usage-long --help' for more information.
        """)

    AssertEqualStrings(
      actual: CustomUsageHidden.fullMessage(for: ValidationError("Test")),
      expected: """
        Error: Test
          See 'custom-usage-hidden --help' for more information.
        """)
  }

  func test_usageCustomization_usageString() {
    AssertEqualStrings(
      actual: NonCustomUsage.usageString(),
      expected: """
        non-custom-usage <file> [--verbose-mode] <subcommand>
        """)

    AssertEqualStrings(
      actual: NonCustomUsage.usageString(
        for: NonCustomUsage.ExampleSubcommand.self),
      expected: """
        non-custom-usage example-subcommand <output>
        """)

    AssertEqualStrings(
      actual: CustomUsageShort.usageString(),
      expected: """
        example [--verbose] <file-name>
        """)

    AssertEqualStrings(
      actual: CustomUsageLong.usageString(),
      expected: """
        example <file-name>
        example --verbose <file-name>
        example --help
        """)

    AssertEqualStrings(
      actual: CustomUsageHidden.usageString(),
      expected: """
        """)
  }
}

// swift-format-ignore: AlwaysUseLowerCamelCase
// https://github.com/apple/swift-argument-parser/issues/710
extension HelpGenerationTests {
  enum OptionValues: String, CaseIterable, ExpressibleByArgument {
    case blue
    case red
    case yellow

    public var defaultValueDescription: String {
      switch self {
      case .blue:
        return "The color of the sky."
      case .red:
        return "The color of a rose."
      case .yellow:
        return "The color of the sun."
      }
    }
  }

  struct CustomOption: ParsableCommand {
    @Option(help: "An option with enumerable values.") var opt: OptionValues
  }

  func testEnumerableOptionValuesWithoutDefault() {
    AssertHelp(
      .default, for: CustomOption.self,
      equals: """
        USAGE: custom-option --opt <opt>

        OPTIONS:
          --opt <opt>             An option with enumerable values.
                blue              - The color of the sky.
                red               - The color of a rose.
                yellow            - The color of the sun.
          -h, --help              Show help information.

        """)
  }

  struct CustomOptionAsListWithSingleDefaultValue: ParsableCommand {
    @Option(
      help: "An option with enumerable values.")
    var opt: [OptionValues] = [.red]
  }

  func testEnumerableOptionAsListWithSingleDefault() {
    AssertHelp(
      .default,
      for: CustomOptionAsListWithSingleDefaultValue.self,
      columns: 100,
      equals: """
        USAGE: custom-option-as-list-with-single-default-value [--opt <opt> ...]

        OPTIONS:
          --opt <opt>             An option with enumerable values. (default: red)
                blue              - The color of the sky.
                red               - The color of a rose.
                yellow            - The color of the sun.
          -h, --help              Show help information.

        """)
  }

  struct CustomOptionAsListWithMultipleDefaultValue: ParsableCommand {
    @Option(
      help: "An option with multiple enumerable values.")
    var opt: [OptionValues] = [.red, .blue]
  }

  func testEnumerableOptionAsListWithMultipleDefault() {
    AssertHelp(
      .default,
      for: CustomOptionAsListWithMultipleDefaultValue.self,
      columns: 100,
      equals: """
        USAGE: custom-option-as-list-with-multiple-default-value [--opt <opt> ...]

        OPTIONS:
          --opt <opt>             An option with multiple enumerable values. (default: red, blue)
                blue              - The color of the sky.
                red               - The color of a rose.
                yellow            - The color of the sun.
          -h, --help              Show help information.

        """)

  }

  struct CustomOptionAsListWithEmptyArrayAsDefault: ParsableCommand {
    @Option(
      help: "An option with default value set to empty array.")
    var opt: [OptionValues] = []
  }

  func testEnumerableOptionAsListWithEmptyArrayAsDefault() {
    AssertHelp(
      .default,
      for: CustomOptionAsListWithEmptyArrayAsDefault.self,
      columns: 100,
      equals: """
        USAGE: custom-option-as-list-with-empty-array-as-default [--opt <opt> ...]

        OPTIONS:
          --opt <opt>             An option with default value set to empty array.
                blue              - The color of the sky.
                red               - The color of a rose.
                yellow            - The color of the sun.
          -h, --help              Show help information.

        """)

  }

  struct CustomOptionWithDefault: ParsableCommand {
    @Option(help: "An option with enumerable values and a custom default.")
    var opt: OptionValues = .red
  }

  func testEnumerableOptionValuesWithDefault() {
    AssertHelp(
      .default, for: CustomOptionWithDefault.self,
      equals: """
        USAGE: custom-option-with-default [--opt <opt>]

        OPTIONS:
          --opt <opt>             An option with enumerable values and a custom
                                  default. (default: red)
                blue              - The color of the sky.
                red               - The color of a rose.
                yellow            - The color of the sun.
          -h, --help              Show help information.

        """)
  }

  struct Optional: ParsableCommand {
    @Option(help: "Optional option type.") var optional: OptionValues?
  }

  func testOptionalEnumerableOptionValue() {
    AssertHelp(
      .default, for: Optional.self,
      equals: """
        USAGE: optional [--optional <optional>]

        OPTIONS:
          --optional <optional>   Optional option type.
                blue              - The color of the sky.
                red               - The color of a rose.
                yellow            - The color of the sun.
          -h, --help              Show help information.

        """)
  }

  struct NoAbstract: ParsableCommand {
    @Option var a: OptionValues
    @Option var b: OptionValues = .red
  }

  func testEnumerableOptionValue_NoAbstract() {
    AssertHelp(
      .default, for: NoAbstract.self,
      equals: """
        USAGE: no-abstract --a <a> [--b <b>]

        OPTIONS:
          --a <a>
                blue              - The color of the sky.
                red               - The color of a rose.
                yellow            - The color of the sun.
          --b <b>                 (default: red)
                blue              - The color of the sky.
                red               - The color of a rose.
                yellow            - The color of the sun.
          -h, --help              Show help information.

        """)
  }

  struct Preamble: ParsableCommand {
    @Option(
      help:
        .init(
          discussion:
            """
            A preamble. This will be appended to the top \
            of the discussion block, before the list of option values.
            """
        )
    )
    var a: OptionValues

    @Option(
      help:
        .init(
          "An abstract.",
          discussion: "A discussion."
        )
    )
    var b: OptionValues?
  }

  func testEnumerableValuesWithPreamble() {
    AssertHelp(
      .default, for: Preamble.self,
      equals: """
        USAGE: preamble --a <a> [--b <b>]

        OPTIONS:
          --a <a>
                A preamble. This will be appended to the top of the discussion block,
                before the list of option values.
                blue              - The color of the sky.
                red               - The color of a rose.
                yellow            - The color of the sun.
          --b <b>                 An abstract.
                A discussion.
                blue              - The color of the sky.
                red               - The color of a rose.
                yellow            - The color of the sun.
          -h, --help              Show help information.

        """)
  }

  enum OptionWithoutEnumerationHelpText: String, CaseIterable,
    ExpressibleByArgument
  {
    case one = "1"
    case two = "2"
    case three = "3"
  }

  struct HelpTextComparison: ParsableCommand {
    @Option(help: .init("An abstract.", discussion: "A discussion."))
    var enumerable: OptionValues

    @Option(
      help: "This is an option without explicit enumeration in the help text.")
    var values: OptionWithoutEnumerationHelpText
  }

  func testOptionHelpTextWithAndWithoutEnumeratedDescriptions() {
    AssertHelp(
      .default, for: HelpTextComparison.self,
      equals: """
        USAGE: help-text-comparison --enumerable <enumerable> --values <values>

        OPTIONS:
          --enumerable <enumerable>
                                  An abstract.
                A discussion.
                blue              - The color of the sky.
                red               - The color of a rose.
                yellow            - The color of the sun.
          --values <values>       This is an option without explicit enumeration in the
                                  help text. (values: 1, 2, 3)
          -h, --help              Show help information.

        """)
  }
}

extension HelpGenerationTests {
  enum Empty: CaseIterable, ExpressibleByArgument {
    var defaultValueDescription: String {
      "none"
    }

    init?(argument: String) {
      return nil
    }
  }

  struct EmptyCommand: ParsableCommand {
    @Option(help: "An option with no values.") var empty: Empty
  }

  func testEmptyOptionValues() {
    AssertHelp(
      .default, for: EmptyCommand.self,
      equals: """
        USAGE: empty-command --empty <empty>

        OPTIONS:
          --empty <empty>         An option with no values.
          -h, --help              Show help information.

        """)
  }
}

extension HelpGenerationTests {
  enum Cases: String, CaseIterable, ExpressibleByArgument {
    case short
    case longDesc
    case longLabel = "long-label-that-is-too-long-for-description"
    case longLabelAndDesc = "long-label-that-is-too-long-for-longer-description"

    var defaultValueDescription: String {
      switch self {
      case .short:
        return "short label option"
      case .longDesc:
        return
          "this is my very long label option, and it should wrap this text when the help is printed."
      case .longLabel:
        return "this is a discussion text."
      case .longLabelAndDesc:
        return
          "this discussion text should be wrapped, and the label is simply too long for this text to be on the same line."
      }
    }
  }

  struct LongLabelHelp: ParsableCommand {
    @Option(
      help: "A collection of cases with varying lengths of labels/descriptions."
    )
    var argument: Cases
  }

  func testLongOptionLabelAndDescriptionHelp() {
    AssertHelp(
      .default, for: LongLabelHelp.self,
      equals: """
        USAGE: long-label-help --argument <argument>

        OPTIONS:
          --argument <argument>   A collection of cases with varying lengths of
                                  labels/descriptions.
                short             - short label option
                longDesc          - this is my very long label option, and it should
                                    wrap this text when the help is printed.
                long-label-that-is-too-long-for-description
                                  - this is a discussion text.
                long-label-that-is-too-long-for-longer-description
                                  - this discussion text should be wrapped, and the
                                    label is simply too long for this text to be on the
                                    same line.
          -h, --help              Show help information.

        """)
  }

  struct LongLabelHelpWithOptionDescription: ParsableCommand {
    @Option(
      help:
        .init(
          "A collection of cases with varying lengths of labels/descriptions.",
          discussion: "This is a discussion text - don't mind me!"
        )
    )
    var argument: Cases
  }

  func testLongOptionLabelAndDescriptionHelpWithOptionDescription() {
    AssertHelp(
      .default, for: LongLabelHelpWithOptionDescription.self,
      equals: """
        USAGE: long-label-help-with-option-description --argument <argument>

        OPTIONS:
          --argument <argument>   A collection of cases with varying lengths of
                                  labels/descriptions.
                This is a discussion text - don't mind me!
                short             - short label option
                longDesc          - this is my very long label option, and it should
                                    wrap this text when the help is printed.
                long-label-that-is-too-long-for-description
                                  - this is a discussion text.
                long-label-that-is-too-long-for-longer-description
                                  - this discussion text should be wrapped, and the
                                    label is simply too long for this text to be on the
                                    same line.
          -h, --help              Show help information.

        """)
  }
}

extension HelpGenerationTests {
  private struct WideHelp: ParsableCommand {
    @Argument(help: "54 characters of help, so as to wrap when columns < 80")
    var argument: String?
  }

  func testColumnsEnvironmentOverride() throws {
    #if !(os(Windows) || os(WASI))
    defer { Platform.Environment[.columns] = nil }
    Platform.Environment[.columns] = nil
    AssertHelp(
      .default, for: WideHelp.self, columns: nil,
      equals: """
        USAGE: wide-help [<argument>]

        ARGUMENTS:
          <argument>              54 characters of help, so as to wrap when columns < 80

        OPTIONS:
          -h, --help              Show help information.

        """)

    Platform.Environment[.columns, as: Int.self] = 60
    AssertHelp(
      .default, for: WideHelp.self, columns: nil,
      equals: """
        USAGE: wide-help [<argument>]

        ARGUMENTS:
          <argument>              54 characters of help, so as to
                                  wrap when columns < 80

        OPTIONS:
          -h, --help              Show help information.

        """)

    Platform.Environment[.columns, as: Int.self] = 79
    AssertHelp(
      .default, for: WideHelp.self, columns: nil,
      equals: """
        USAGE: wide-help [<argument>]

        ARGUMENTS:
          <argument>              54 characters of help, so as to wrap when columns <
                                  80

        OPTIONS:
          -h, --help              Show help information.

        """)
    #endif
  }
}

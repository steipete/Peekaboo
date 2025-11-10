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

#if compiler(>=6.0)
internal import ArgumentParserToolInfo
#else
import ArgumentParserToolInfo
#endif

extension ToolInfoV0 {
  var fishCompletionScript: String {
    command.fishCompletionScript
  }
}

extension CommandInfoV0 {
  fileprivate var fishCompletionScript: String {
    """
    function \(shouldOfferCompletionsForFunctionName) -a expected_commands -a expected_positional_index
        set -l unparsed_tokens (\(tokensFunctionName) -pc)
        set -l positional_index 0
        set -l commands

        switch $unparsed_tokens[1]
    \(commandCases)
        end

        test "$commands" = "$expected_commands" -a \\( -z "$expected_positional_index" -o "$expected_positional_index" -eq "$positional_index" \\)
    end

    function \(tokensFunctionName)
        if test (string split -m 1 -f 1 -- . "$FISH_VERSION") -gt 3
            commandline --tokens-raw $argv
        else
            commandline -o $argv
        end
    end

    function \(parseSubcommandFunctionName) -S
        argparse -s r -- $argv
        set -l positional_count $argv[1]
        set -l option_specs $argv[2..]

        set -a commands $unparsed_tokens[1]
        set -e unparsed_tokens[1]

        set positional_index 0

        while true
            argparse -sn "$commands" $option_specs -- $unparsed_tokens 2> /dev/null
            set unparsed_tokens $argv
            set positional_index (math $positional_index + 1)
            if test (count $unparsed_tokens) -eq 0 -o \\( -z "$_flag_r" -a "$positional_index" -gt "$positional_count" \\)
                return 0
            end
            set -e unparsed_tokens[1]
        end
    end

    function \(completeDirectoriesFunctionName)
        set -l token (commandline -t)
        string match -- '*/' $token
        set -l subdirs $token*/
        printf '%s\\n' $subdirs
    end

    function \(customCompletionFunctionName)
        set -x \(Platform.Environment.Key.shellName.rawValue) fish
        set -x \(Platform.Environment.Key.shellVersion.rawValue) $FISH_VERSION

        set -l tokens (\(tokensFunctionName) -p)
        if test -z (\(tokensFunctionName) -t)
            set -l index (count (\(tokensFunctionName) -pc))
            set tokens $tokens[..$index] \\'\\' $tokens[(math $index + 1)..]
        end
        command $tokens[1] $argv $tokens
    end

    complete -c '\(commandName)' -f
    \(completions.joined(separator: "\n"))
    """
  }

  private var commandCases: String {
    let subcommands = (subcommands ?? []).filter(\.shouldDisplay)
    return """
      case '\(commandName)'
          \(parseSubcommandFunctionName) \(positionalArgumentCountArguments) \(
            completableArguments
            .compactMap(\.optionSpec)
            .map { "'\($0.fishEscapeForSingleQuotedString())'" }
            .joined(separator: separator)
          )\(
            subcommands.isEmpty
              ? ""
              : """

                  switch $unparsed_tokens[1]
              \(subcommands.map(\.commandCases).joined(separator: "\n"))
                  end
              """
          )
      """
      .indentingEachLine(by: 4)
  }

  private var completions: [String] {
    let prefix = """
      complete -c '\(initialCommand)'\
       -n '\(shouldOfferCompletionsForFunctionName)\
       "\(commandContext.joined(separator: separator))"
      """

    let subcommands = (subcommands ?? []).filter(\.shouldDisplay)

    var positionalIndex = 0

    let argumentCompletions =
      completableArguments
      .map { arg in
        """
        \(prefix)\(
          arg.kind == .positional
          ? """
          \({
            positionalIndex += 1
            return " \(positionalIndex)"
          }())
          """
          : ""
        )' \(argumentSegments(arg).joined(separator: separator))
        """
      }

    positionalIndex += 1

    return
      argumentCompletions
      + subcommands.map {
        "\(prefix) \(positionalIndex)' -fa '\($0.commandName)' -d '\($0.abstract?.fishEscapeForSingleQuotedString() ?? "")'"
      }
      + subcommands.flatMap(\.completions)
  }

  private var completableArguments: [ArgumentInfoV0] {
    (arguments ?? []).compactMap { arg in
      switch arg.completionKind {
      case .none where arg.names?.isEmpty ?? true:
        return nil
      default:
        return
          arg.shouldDisplay
          ? arg
          : nil
      }
    }
  }

  private func argumentSegments(_ arg: ArgumentInfoV0) -> [String] {
    var results: [String] = []

    if let names = arg.names, !names.isEmpty {
      results += names.map(\.asCompleteArgument)
      if let abstract = arg.abstract, !abstract.isEmpty {
        results += [
          "-d '\(abstract.fishEscapeForSingleQuotedString())'"
        ]
      }
    }

    let r = arg.kind == .positional ? "" : "r"

    switch arg.completionKind {
    case .none:
      switch arg.kind {
      case .positional,
        .option:
        results += ["-\(r)fka ''"]
      default:
        break
      }
      break
    case .list(let list):
      results += ["-\(r)fka '\(list.joined(separator: separator))'"]
    case .file(let extensions):
      switch extensions.count {
      case 0:
        results += ["-\(r)F"]
      case 1:
        results += [
          """
          -\(r)fa '(\
          for p in (string match -e -- \\'*/\\' (commandline -t);or printf \\n)*.\\'\(extensions.map { $0.fishEscapeForSingleQuotedString(iterationCount: 2) }.joined())\\';printf %s\\n $p;end;\
          __fish_complete_directories (commandline -t) \\'\\'\
          )'
          """
        ]
      default:
        results += [
          """
          -\(r)fa '(\
          set -l exts \(extensions.map { "\\'\($0.fishEscapeForSingleQuotedString(iterationCount: 2))\\'" }.joined(separator: separator));\
          for p in (string match -e -- \\'*/\\' (commandline -t);or printf \\n)*.{$exts};printf %s\\n $p;end;\
          __fish_complete_directories (commandline -t) \\'\\'\
          )'
          """
        ]
      }
    case .directory:
      results += ["-\(r)fa '(\(completeDirectoriesFunctionName))'"]
    case .shellCommand(let shellCommand):
      results += [
        "-\(r)fka '(\(shellCommand.fishEscapeForSingleQuotedString()))'"
      ]
    case .custom, .customAsync:
      results += [
        """
        -\(r)fka '(\
        \(customCompletionFunctionName) \(arg.commonCustomCompletionCall(command: self)) \
        (count (\(tokensFunctionName) -pc)) (\(tokensFunctionName) -tC)\
        )'
        """
      ]
    case .customDeprecated:
      results += [
        """
        -\(r)fka '(\(customCompletionFunctionName) \(arg.commonCustomCompletionCall(command: self)))'
        """
      ]
    }

    return results
  }

  var positionalArgumentCountArguments: String {
    let positionalArguments = positionalArguments
    return """
      \(positionalArguments.contains(where: { $0.isRepeating }) ? "-r " : "")\(positionalArguments.count)
      """
  }

  private var shouldOfferCompletionsForFunctionName: String {
    "\(completionFunctionPrefix)_should_offer_completions_for"
  }

  private var tokensFunctionName: String {
    "\(completionFunctionPrefix)_tokens"
  }

  private var parseSubcommandFunctionName: String {
    "\(completionFunctionPrefix)_parse_subcommand"
  }

  private var completeDirectoriesFunctionName: String {
    "\(completionFunctionPrefix)_complete_directories"
  }

  private var customCompletionFunctionName: String {
    "\(completionFunctionPrefix)_custom_completion"
  }
}

extension ArgumentInfoV0 {
  fileprivate var optionSpec: String? {
    guard let shortName = name(.short) else {
      guard let longName = name(.long) else {
        return nil
      }
      return optionSpecRequiresValue(longName)
    }
    guard let longName = name(.long) else {
      return optionSpecRequiresValue(shortName)
    }
    return optionSpecRequiresValue("\(shortName)/\(longName)")
  }

  private func name(_ nameKind: NameInfoV0.KindV0) -> String? {
    (names ?? []).first(where: { $0.kind == nameKind })?.name
  }

  private func optionSpecRequiresValue(_ optionSpec: String) -> String {
    switch kind {
    case .option:
      return "\(optionSpec)="
    default:
      return optionSpec
    }
  }
}

extension ArgumentInfoV0.NameInfoV0 {
  fileprivate var asCompleteArgument: String {
    switch kind {
    case .long:
      return "-l '\(name.fishEscapeForSingleQuotedString())'"
    case .short:
      return "-s '\(name.fishEscapeForSingleQuotedString())'"
    case .longWithSingleDash:
      return "-o '\(name.fishEscapeForSingleQuotedString())'"
    }
  }
}

extension String {
  fileprivate func fishEscapeForSingleQuotedString(
    iterationCount: UInt64 = 1
  ) -> Self {
    iterationCount == 0
      ? self
      : self
        .replacing("\\", with: "\\\\")
        .replacing("'", with: "\\'")
        .fishEscapeForSingleQuotedString(iterationCount: iterationCount - 1)
  }
}

private var separator: String { " " }

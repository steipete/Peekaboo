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
  var zshCompletionScript: String {
    command.zshCompletionScript
  }
}

extension CommandInfoV0 {
  fileprivate var zshCompletionScript: String {
    // swift-format-ignore: NeverForceUnwrap
    // Preconditions:
    // - first must be non-empty for a zsh completion script to be of use.
    // - first is guaranteed non-empty in the one place where this computed var is used.
    """
    #compdef \(commandName)

    \(completeFunctionName)() {
        local -ar non_empty_completions=("${@:#(|:*)}")
        local -ar empty_completions=("${(M)@:#(|:*)}")
        _describe -V '' non_empty_completions -- empty_completions -P $'\\'\\''
    }

    \(customCompleteFunctionName)() {
        local -a completions
        completions=("${(@f)"$("${command_name}" "${@}" "${command_line[@]}")"}")
        if [[ "${#completions[@]}" -gt 1 ]]; then
            \(completeFunctionName) "${completions[@]:0:-1}"
        fi
    }

    \(cursorIndexInCurrentWordFunctionName)() {
        if [[ -z "${QIPREFIX}${IPREFIX}${PREFIX}" ]]; then
            printf 0
        else
            printf %s "${#${(z)LBUFFER}[-1]}"
        fi
    }

    \(completionFunctions)\
    \(completionFunctionName)
    """
  }

  private var completionFunctions: String {
    let functionName = completionFunctionName

    let argumentSpecsAndSetupScripts = (arguments ?? []).compactMap {
      argumentSpecAndSetupScript($0)
    }
    var argumentSpecs = argumentSpecsAndSetupScripts.map(\.argumentSpec)
    let setupScripts = argumentSpecsAndSetupScripts.compactMap(\.setupScript)

    let subcommands = (subcommands ?? []).filter(\.shouldDisplay)

    let subcommandHandler: String
    if subcommands.isEmpty {
      subcommandHandler = ""
    } else {
      argumentSpecs.append("'(-): :->command'")
      argumentSpecs.append("'(-)*:: :->arg'")

      subcommandHandler = """
            case "${state}" in
            command)
                local -ar subcommands=(
        \(
          subcommands.map { """
                        '\($0.commandName.zshEscapeForSingleQuotedDescribeCompletion()):\($0.abstract?.shellEscapeForSingleQuotedString() ?? "")'
            """
          }
          .joined(separator: "\n")
        )
                )
                _describe -V subcommand subcommands
                ;;
            arg)
                case "${words[1]}" in
                \(subcommands.map(\.commandName).joined(separator: "|")))
                    "\(functionName)_${words[1]}"
                    ;;
                esac
                ;;
            esac

        """
    }

    return """
      \(functionName)() {
      \((superCommands ?? []).isEmpty
        ? """
              emulate -RL zsh -G
              setopt extendedglob nullglob numericglobsort
              unsetopt aliases banghist

              local -xr \(Platform.Environment.Key.shellName.rawValue)=zsh
              local -x \(Platform.Environment.Key.shellVersion.rawValue)
              \(Platform.Environment.Key.shellVersion.rawValue)="$(builtin emulate zsh -c 'printf %s "${ZSH_VERSION}"')"
              local -r \(Platform.Environment.Key.shellVersion.rawValue)

              local context state state_descr line
              local -A opt_args

              local -r command_name="${words[1]}"
              local -ar command_line=("${words[@]}")
              local -ir current_word_index="$((CURRENT - 1))"


          """
        : ""
      )\
          local -i ret=1
      \(setupScripts.map { "\($0)\n" }.joined().indentingEachLine(by: 4))\
          local -ar arg_specs=(
      \(argumentSpecs.joined(separator: "\n").indentingEachLine(by: 8))
          )
          _arguments -w -s -S : "${arg_specs[@]}" && ret=0
      \(subcommandHandler)
          return "${ret}"
      }

      \(subcommands.map(\.completionFunctions).joined())
      """
  }

  private func argumentSpecAndSetupScript(
    _ arg: ArgumentInfoV0
  ) -> (argumentSpec: String, setupScript: String?)? {
    guard arg.shouldDisplay else { return nil }

    let line: String
    let names = arg.names ?? []
    switch names.count {
    case 0:
      line = arg.isRepeating ? "*" : ""
    case 1:
      // swift-format-ignore: NeverForceUnwrap
      // Preconditions: names has exactly one element.
      line = """
        \(arg.isRepeatingOption ? "*" : "")\(names.first!.commonCompletionSynopsisString().zshEscapeForSingleQuotedOptionSpec())\(arg.completionAbstract)
        """
    default:
      let synopses = names.map {
        $0.commonCompletionSynopsisString().zshEscapeForSingleQuotedOptionSpec()
      }
      line = """
        \(arg.isRepeatingOption ? "*" : "(\(synopses.joined(separator: " ")))")'\
        {\(synopses.joined(separator: ","))}\
        '\(arg.completionAbstract)
        """
    }

    switch arg.kind {
    case .option, .positional:
      let (argumentAction, setupScript) = argumentActionAndSetupScript(arg)
      return (
        "'\(line):\(arg.valueName?.zshEscapeForSingleQuotedOptionSpec() ?? ""):\(argumentAction)'",
        setupScript
      )
    case .flag:
      return ("'\(line)'", nil)
    }
  }

  /// Returns the zsh "action" for an argument completion string.
  private func argumentActionAndSetupScript(
    _ arg: ArgumentInfoV0
  ) -> (argumentAction: String, setupScript: String?) {
    switch arg.completionKind {
    case .none:
      return ("", nil)

    case .file(let extensions):
      return
        extensions.isEmpty
        ? ("_files", nil)
        : (
          "_files -g '\\''\(extensions.map { "*.\($0.shellEscapeForSingleQuotedString())" }.joined(separator: " "))'\\''",
          nil
        )

    case .directory:
      return ("_files -/", nil)

    case .list(let list):
      let variableName = variableName(arg)
      return (
        "{\(completeFunctionName) \"${\(variableName)[@]}\"}",
        "local -ar \(variableName)=(\(list.map { "'\($0.shellEscapeForSingleQuotedString())'" }.joined(separator: " ")))"
      )

    case .shellCommand(let command):
      return (
        "{local -a list;list=(${(f)\"$(\(command.shellEscapeForSingleQuotedString()))\"});_describe -V \"\" list}",
        nil
      )

    case .custom, .customAsync:
      return (
        "{\(customCompleteFunctionName) \(arg.commonCustomCompletionCall(command: self)) \"${current_word_index}\" \"$(\(cursorIndexInCurrentWordFunctionName))\"}",
        nil
      )

    case .customDeprecated:
      return (
        "{\(customCompleteFunctionName) \(arg.commonCustomCompletionCall(command: self))}",
        nil
      )
    }
  }

  private func variableName(_ arg: ArgumentInfoV0) -> String {
    guard let argName = arg.preferredName else {
      return "_\(arg.valueName?.shellEscapeForVariableName() ?? "")"
    }
    return
      "\(argName.kind == .long ? "___" : "__")\(argName.name.shellEscapeForVariableName())"
  }

  private var completeFunctionName: String {
    "\(completionFunctionPrefix)_complete"
  }

  private var customCompleteFunctionName: String {
    "\(completionFunctionPrefix)_custom_complete"
  }

  private var cursorIndexInCurrentWordFunctionName: String {
    "\(completionFunctionPrefix)_cursor_index_in_current_word"
  }
}

extension ArgumentInfoV0 {
  /// - returns: `true` if `self` is a flag or an option and can be tab-completed multiple times in one command line.
  ///   For example, `ssh` allows the `-L` option to be given multiple times, to establish multiple port forwardings.
  fileprivate var isRepeatingOption: Bool {
    guard
      [.flag, .option].contains(kind),
      isRepeating
    else { return false }

    switch parsingStrategy {
    case .default, .unconditional: return true
    default: return false
    }
  }

  fileprivate var completionAbstract: String {
    guard let abstract, !abstract.isEmpty else { return "" }
    return "[\(abstract.zshEscapeForSingleQuotedOptionSpec())]"
  }
}

extension String {
  fileprivate func zshEscapeForSingleQuotedDescribeCompletion() -> String {
    self
      .replacing("\\", with: "\\\\")
      .replacing(":", with: "\\:")
      .shellEscapeForSingleQuotedString()
  }
  fileprivate func zshEscapeForSingleQuotedOptionSpec() -> String {
    self
      .replacing("\\", with: "\\\\")
      .replacing(":", with: "\\:")
      .replacing("[", with: "\\[")
      .replacing("]", with: "\\]")
      .shellEscapeForSingleQuotedString()
  }
}

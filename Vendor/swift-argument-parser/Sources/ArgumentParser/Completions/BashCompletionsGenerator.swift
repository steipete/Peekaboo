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
  var bashCompletionScript: String {
    command.bashCompletionScript
  }
}

extension CommandInfoV0 {
  fileprivate var bashCompletionScript: String {
    """
    #!/bin/bash

    \(cursorIndexInCurrentWordFunctionName)() {
        local remaining="${COMP_LINE}"

        local word
        for word in "${COMP_WORDS[@]::COMP_CWORD}"; do
            remaining="${remaining##*([[:space:]])"${word}"*([[:space:]])}"
        done

        local -ir index="$((COMP_POINT - ${#COMP_LINE} + ${#remaining}))"
        if [[ "${index}" -le 0 ]]; then
            printf 0
        else
            printf %s "${index}"
        fi
    }

    # positional arguments:
    #
    # - 1: the current (sub)command's count of positional arguments
    #
    # required variables:
    #
    # - flags: the flags that the current (sub)command can accept
    # - options: the options that the current (sub)command can accept
    # - positional_number: value ignored
    # - unparsed_words: unparsed words from the current command line
    #
    # modified variables:
    #
    # - flags: remove flags for this (sub)command that are already on the command line
    # - options: remove options for this (sub)command that are already on the command line
    # - positional_number: set to the current positional number
    # - unparsed_words: remove all flags, options, and option values for this (sub)command
    \(offerFlagsOptionsFunctionName)() {
        local -ir positional_count="${1}"
        positional_number=0

        local was_flag_option_terminator_seen=false
        local is_parsing_option_value=false

        local -ar unparsed_word_indices=("${!unparsed_words[@]}")
        local -i word_index
        for word_index in "${unparsed_word_indices[@]}"; do
            if "${is_parsing_option_value}"; then
                # This word is an option value:
                # Reset marker for next word iff not currently the last word
                [[ "${word_index}" -ne "${unparsed_word_indices[${#unparsed_word_indices[@]} - 1]}" ]] && is_parsing_option_value=false
                unset "unparsed_words[${word_index}]"
                # Do not process this word as a flag or an option
                continue
            fi

            local word="${unparsed_words["${word_index}"]}"
            if ! "${was_flag_option_terminator_seen}"; then
                case "${word}" in
                --)
                    unset "unparsed_words[${word_index}]"
                    # by itself -- is a flag/option terminator, but if it is the last word, it is the start of a completion
                    if [[ "${word_index}" -ne "${unparsed_word_indices[${#unparsed_word_indices[@]} - 1]}" ]]; then
                        was_flag_option_terminator_seen=true
                    fi
                    continue
                    ;;
                -*)
                    # ${word} is a flag or an option
                    # If ${word} is an option, mark that the next word to be parsed is an option value
                    local option
                    for option in "${options[@]}"; do
                        [[ "${word}" = "${option}" ]] && is_parsing_option_value=true && break
                    done

                    # Remove ${word} from ${flags} or ${options} so it isn't offered again
                    local not_found=true
                    local -i index
                    for index in "${!flags[@]}"; do
                        if [[ "${flags[${index}]}" = "${word}" ]]; then
                            unset "flags[${index}]"
                            flags=("${flags[@]}")
                            not_found=false
                            break
                        fi
                    done
                    if "${not_found}"; then
                        for index in "${!options[@]}"; do
                            if [[ "${options[${index}]}" = "${word}" ]]; then
                                unset "options[${index}]"
                                options=("${options[@]}")
                                break
                            fi
                        done
                    fi
                    unset "unparsed_words[${word_index}]"
                    continue
                    ;;
                esac
            fi

            # ${word} is neither a flag, nor an option, nor an option value
            if [[ "${positional_number}" -lt "${positional_count}" ]]; then
                # ${word} is a positional
                ((positional_number++))
                unset "unparsed_words[${word_index}]"
            else
                if [[ -z "${word}" ]]; then
                    # Could be completing a flag, option, or subcommand
                    positional_number=-1
                else
                    # ${word} is a subcommand or invalid, so stop processing this (sub)command
                    positional_number=-2
                fi
                break
            fi
        done

        unparsed_words=("${unparsed_words[@]}")

        if\\
            ! "${was_flag_option_terminator_seen}"\\
            && ! "${is_parsing_option_value}"\\
            && [[ ("${cur}" = -* && "${positional_number}" -ge 0) || "${positional_number}" -eq -1 ]]
        then
            COMPREPLY+=($(compgen -W "${flags[*]} ${options[*]}" -- "${cur}"))
        fi
    }

    \(addCompletionsFunctionName)() {
        local completion
        while IFS='' read -r completion; do
            COMPREPLY+=("${completion}")
        done < <(IFS=$'\\n' compgen "${@}" -- "${cur}")
    }

    \(customCompleteFunctionName)() {
        if [[ -n "${cur}" || -z ${COMP_WORDS[${COMP_CWORD}]} || "${COMP_LINE:${COMP_POINT}:1}" != ' ' ]]; then
            local -ar words=("${COMP_WORDS[@]}")
        else
            local -ar words=("${COMP_WORDS[@]::${COMP_CWORD}}" '' "${COMP_WORDS[@]:${COMP_CWORD}}")
        fi

        "${COMP_WORDS[0]}" "${@}" "${words[@]}"
    }

    \(completionFunctions)\
    complete -o filenames -F \(completionFunctionName) \(commandName)
    """
  }

  /// Generates a Bash completion function.
  private var completionFunctions: String {
    let functionName = completionFunctionName

    let subcommands = (subcommands ?? []).filter(\.shouldDisplay)

    // Start building the resulting function code.
    var result = ""

    // Include initial setup iff the root command.
    let declareTopLevelArray: String
    if (superCommands ?? []).isEmpty {
      result += """
            trap "$(shopt -p);$(shopt -po)" RETURN
            shopt -s extglob
            set +o history +o posix

            local -xr \(Platform.Environment.Key.shellName.rawValue)=bash
            local -x \(Platform.Environment.Key.shellVersion.rawValue)
            \(Platform.Environment.Key.shellVersion.rawValue)="$(IFS='.';printf %s "${BASH_VERSINFO[*]}")"
            local -r \(Platform.Environment.Key.shellVersion.rawValue)

            local -r cur="${2}"
            local -r prev="${3}"

            local -i positional_number
            local -a unparsed_words=("${COMP_WORDS[@]:1:${COMP_CWORD}}")


        """

      declareTopLevelArray = "local -a "
    } else {
      declareTopLevelArray = ""
    }

    let positionalArguments = positionalArguments

    let flagCompletions = flagCompletions
    let optionCompletions = optionCompletions
    if !flagCompletions.isEmpty || !optionCompletions.isEmpty {
      result += """
            \(declareTopLevelArray)flags=(\(flagCompletions.joined(separator: " ")))
            \(declareTopLevelArray)options=(\(optionCompletions.joined(separator: " ")))
            \(offerFlagsOptionsFunctionName) \(positionalArguments.count)

        """
    }

    // Generate the case pattern-matching statements for option values.
    // If there aren't any, skip the case block altogether.
    let optionHandlers =
      (arguments ?? []).compactMap { arg in
        guard arg.kind != .flag else { return nil }
        let words = arg.completionWords
        guard !words.isEmpty else { return nil }
        return """
              \(arg.completionWords.map { "'\($0.shellEscapeForSingleQuotedString())'" }.joined(separator: "|")))
          \(valueCompletion(arg).indentingEachLine(by: 8))\
                  return
                  ;;
          """
      }
      .joined(separator: "\n")
    if !optionHandlers.isEmpty {
      result += """

            # Offer option value completions
            case "${prev}" in
        \(optionHandlers)
            esac

        """
    }

    let positionalCases =
      zip(1..., positionalArguments)
      .compactMap { position, arg in
        let completion = valueCompletion(arg)
        return completion.isEmpty
          ? nil
          : """
              \(position))
          \(completion.indentingEachLine(by: 8))\
                  return
                  ;;

          """
      }

    if !positionalCases.isEmpty {
      result += """

            # Offer positional completions
            case "${positional_number}" in
        \(positionalCases.joined())\
            esac

        """
    }

    if !subcommands.isEmpty {
      result += """

            # Offer subcommand / subcommand argument completions
            local -r subcommand="${unparsed_words[0]}"
            unset 'unparsed_words[0]'
            unparsed_words=("${unparsed_words[@]}")
            case "${subcommand}" in
            \(subcommands.map(\.commandName).joined(separator: "|")))
                # Offer subcommand argument completions
                "\(functionName)_${subcommand}"
                ;;
            *)
                # Offer subcommand completions
                COMPREPLY+=($(compgen -W '\(
                  subcommands.map { $0.commandName.shellEscapeForSingleQuotedString() }.joined(separator: " ")
                )' -- "${cur}"))
                ;;
            esac

        """
    }

    if result.isEmpty {
      result = "    :\n"
    }

    return """
      \(functionName)() {
      \(result)\
      }

      \(subcommands.map(\.completionFunctions).joined())
      """
  }

  /// Returns flag completions.
  private var flagCompletions: [String] {
    (arguments ?? []).flatMap {
      switch $0.kind {
      case .flag:
        return $0.completionWords
      default:
        return []
      }
    }
  }

  /// Returns option completions.
  private var optionCompletions: [String] {
    (arguments ?? []).flatMap {
      switch $0.kind {
      case .option:
        return $0.completionWords
      default:
        return []
      }
    }
  }

  /// Returns the completions that can follow the given argument's `--name`.
  private func valueCompletion(_ arg: ArgumentInfoV0) -> String {
    switch arg.completionKind {
    case .none:
      return ""

    case .file(let extensions) where extensions.isEmpty:
      return """
        \(addCompletionsFunctionName) -f

        """

    case .file(let extensions):
      let exts =
        extensions
        .map { $0.shellEscapeForSingleQuotedString() }.joined(separator: "|")
      return """
        \(addCompletionsFunctionName) -o plusdirs -fX '!*.@(\(exts))'

        """

    case .directory:
      return """
        \(addCompletionsFunctionName) -d

        """

    case .list(let list):
      return """
        \(addCompletionsFunctionName) -W\
         '\(list.map { $0.shellEscapeForSingleQuotedString() }.joined(separator: "'$'\\n''"))'

        """

    case .shellCommand(let command):
      return """
        \(addCompletionsFunctionName) -W "$(eval '\(command.shellEscapeForSingleQuotedString())')"

        """

    case .custom, .customAsync:
      // Generate a call back into the command to retrieve a completions list
      return """
        \(addCompletionsFunctionName) -W\
         "$(\(customCompleteFunctionName) \(arg.commonCustomCompletionCall(command: self))\
         "${COMP_CWORD}"\
         "$(\(cursorIndexInCurrentWordFunctionName))")"

        """

    case .customDeprecated:
      // Generate a call back into the command to retrieve a completions list
      return """
        \(addCompletionsFunctionName) -W\
         "$(\(customCompleteFunctionName) \(arg.commonCustomCompletionCall(command: self)))"

        """
    }
  }

  private var cursorIndexInCurrentWordFunctionName: String {
    "\(completionFunctionPrefix)_cursor_index_in_current_word"
  }

  private var offerFlagsOptionsFunctionName: String {
    "\(completionFunctionPrefix)_offer_flags_options"
  }

  private var addCompletionsFunctionName: String {
    "\(completionFunctionPrefix)_add_completions"
  }

  private var customCompleteFunctionName: String {
    "\(completionFunctionPrefix)_custom_complete"
  }
}

extension ArgumentInfoV0 {
  /// Returns the different completion names for this argument.
  fileprivate var completionWords: [String] {
    shouldDisplay
      ? (names ?? []).map { $0.commonCompletionSynopsisString() }
      : []
  }
}

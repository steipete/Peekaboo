import Foundation

/// Renders a zsh completion script using `compdef` plus dynamic helper
/// functions backed by the shared completion document.
struct ZshCompletionRenderer: ShellCompletionRendering {
    func render(document: CompletionScriptDocument) -> String {
        let lines = [
            "#compdef \(document.commandName)",
            "# Zsh completion for peekaboo",
            "# Generated from Commander descriptors via `peekaboo completions zsh`.",
            "# Install with:",
            "#   \(CompletionsCommand.Shell.zsh.installationSnippet)",
            "",
            "__peekaboo_zsh_subcommands() {",
            self.renderZshChoiceSwitch(document.pathsIncludingRoot, accessor: \.subcommands),
            "}",
            "",
            "__peekaboo_zsh_options() {",
            self.renderZshOptionSwitch(document: document),
            "}",
            "",
            "__peekaboo_zsh_argument_values() {",
            self.renderZshArgumentSwitch(document.pathsIncludingRoot),
            "}",
            "",
            "__peekaboo_zsh_option_values() {",
            self.renderZshOptionValueSwitch(document.pathsIncludingRoot),
            "}",
            "",
            "__peekaboo_zsh_has_subcommand() {",
            "    local path=\"$1\"",
            "    local candidate=\"$2\"",
            "    local line value description",
            "    while IFS=$'\\t' read -r value description; do",
            "        [[ \"$value\" == \"$candidate\" ]] && return 0",
            "    done < <(__peekaboo_zsh_subcommands \"$path\")",
            "    return 1",
            "}",
            "",
            "__peekaboo_zsh_compadd_with_help() {",
            "    local line value description",
            "    local -a values descriptions",
            "    while IFS=$'\\t' read -r value description; do",
            "        values+=(\"$value\")",
            "        descriptions+=(\"$description\")",
            "    done",
            "    if (( ${#values[@]} == 0 )); then",
            "        return 1",
            "    fi",
            "    compadd -Q -d descriptions -- \"${values[@]}\"",
            "}",
            "",
            "_peekaboo() {",
            "    local path=\"\"",
            "    local index=2",
            "    local token current_word previous_word",
            "    current_word=\"${words[CURRENT]}\"",
            "",
            "    while (( index < CURRENT )); do",
            "        token=\"${words[index]}\"",
            "        [[ \"$token\" == -* ]] && break",
            "        if __peekaboo_zsh_has_subcommand \"$path\" \"$token\"; then",
            "            path=\"${path:+$path }$token\"",
            "            (( index++ ))",
            "        else",
            "            break",
            "        fi",
            "    done",
            "",
            "    if (( CURRENT > 2 )); then",
            "        previous_word=\"${words[CURRENT - 1]}\"",
            "    fi",
            "",
            "    if __peekaboo_zsh_option_values \"$path\" \"$previous_word\" | __peekaboo_zsh_compadd_with_help; then",
            "        return",
            "    fi",
            "",
            "    if [[ \"$current_word\" == -* ]]; then",
            "        __peekaboo_zsh_options \"$path\" | __peekaboo_zsh_compadd_with_help",
            "        return",
            "    fi",
            "",
            "    if __peekaboo_zsh_subcommands \"$path\" | __peekaboo_zsh_compadd_with_help; then",
            "        return",
            "    fi",
            "",
            "    local argument_index=$(( CURRENT - index ))",
            "    __peekaboo_zsh_argument_values \"$path\" \"$argument_index\" | __peekaboo_zsh_compadd_with_help",
            "}",
            "",
            "compdef _peekaboo \(document.commandName)",
        ]

        return lines.joined(separator: "\n")
    }

    private func renderZshChoiceSwitch(
        _ paths: [CompletionPath],
        accessor: KeyPath<CompletionPath, [CompletionChoice]>
    ) -> String {
        var lines = ["    case \"$1\" in"]
        for path in paths {
            lines.append("        '\(self.caseLabel(path.key))')")
            for choice in path[keyPath: accessor] {
                lines
                    .append(
                        "            print -r -- $'\(self.zshEscaped(choice.value))\\t\(self.zshEscaped(choice.help ?? ""))'"
                    )
            }
            lines.append("            ;;")
        }
        lines.append(contentsOf: [
            "        *)",
            "            ;;",
            "    esac",
        ])
        return lines.joined(separator: "\n")
    }

    private func renderZshOptionSwitch(document: CompletionScriptDocument) -> String {
        var lines = ["    case \"$1\" in", "        '')"]
        for option in document.rootOptions {
            for name in option.names {
                lines.append("            print -r -- $'\(self.zshEscaped(name))\\t\(self.zshEscaped(option.help))'")
            }
        }
        lines.append("            ;;")
        for path in document.flattenedPaths {
            lines.append("        '\(self.caseLabel(path.key))')")
            for option in path.options {
                for name in option.names {
                    lines
                        .append("            print -r -- $'\(self.zshEscaped(name))\\t\(self.zshEscaped(option.help))'")
                }
            }
            lines.append("            ;;")
        }
        lines.append(contentsOf: [
            "        *)",
            "            ;;",
            "    esac",
        ])
        return lines.joined(separator: "\n")
    }

    private func renderZshArgumentSwitch(_ paths: [CompletionPath]) -> String {
        var lines = ["    case \"$1:$2\" in"]
        for path in paths {
            for (index, argument) in path.arguments.enumerated() where !argument.choices.isEmpty {
                lines.append("        '\(self.caseLabel(path.key)):\(index)')")
                for choice in argument.choices {
                    lines
                        .append(
                            "            print -r -- $'\(self.zshEscaped(choice.value))\\t\(self.zshEscaped(choice.help ?? ""))'"
                        )
                }
                lines.append("            ;;")
            }
        }
        lines.append(contentsOf: [
            "        *)",
            "            ;;",
            "    esac",
        ])
        return lines.joined(separator: "\n")
    }

    private func renderZshOptionValueSwitch(_ paths: [CompletionPath]) -> String {
        var lines = ["    case \"$1:$2\" in"]
        for path in paths {
            for option in path.options where !option.valueChoices.isEmpty {
                for name in option.names {
                    lines.append("        '\(self.caseLabel(path.key)):\(self.caseLabel(name))')")
                    for choice in option.valueChoices {
                        lines
                            .append(
                                "            print -r -- $'\(self.zshEscaped(choice.value))\\t\(self.zshEscaped(choice.help ?? ""))'"
                            )
                    }
                    lines.append("            ;;")
                }
            }
        }
        lines.append(contentsOf: [
            "        *)",
            "            ;;",
            "    esac",
        ])
        return lines.joined(separator: "\n")
    }

    private func caseLabel(_ label: String) -> String {
        label.replacingOccurrences(of: "'", with: "'\\''")
    }

    private func zshEscaped(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "'", with: "\\'")
            .replacingOccurrences(of: "\t", with: " ")
            .replacingOccurrences(of: "\n", with: " ")
    }
}

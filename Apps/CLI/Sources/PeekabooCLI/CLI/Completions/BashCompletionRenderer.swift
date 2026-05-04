import Foundation

/// Renders a self-contained bash completion script that queries shared
/// completion tables emitted from Swift metadata.
struct BashCompletionRenderer: ShellCompletionRendering {
    func render(document: CompletionScriptDocument) -> String {
        let lines = self.commonHeader(
            shell: "bash",
            install: CompletionsCommand.Shell.bash.installationSnippet
        ) + [
            "__peekaboo_bash_subcommands() {",
            self.renderBashChoiceSwitch(document.pathsIncludingRoot, accessor: \.subcommands),
            "}",
            "",
            "__peekaboo_bash_options() {",
            self.renderBashOptionSwitch(document: document),
            "}",
            "",
            "__peekaboo_bash_argument_values() {",
            self.renderBashArgumentSwitch(document.pathsIncludingRoot),
            "}",
            "",
            "__peekaboo_bash_option_values() {",
            self.renderBashOptionValueSwitch(document.pathsIncludingRoot),
            "}",
            "",
            "__peekaboo_bash_has_subcommand() {",
            "    local path=\"$1\"",
            "    local candidate=\"$2\"",
            "    while IFS=$'\\t' read -r value _; do",
            "        [[ \"$value\" == \"$candidate\" ]] && return 0",
            "    done < <(__peekaboo_bash_subcommands \"$path\")",
            "    return 1",
            "}",
            "",
            "__peekaboo_bash_complete() {",
            "    local cur=\"${COMP_WORDS[COMP_CWORD]}\"",
            "    local path=\"\"",
            "    local index=1",
            "    local previous=\"\"",
            "    local token",
            "    COMPREPLY=()",
            "",
            "    while (( index < COMP_CWORD )); do",
            "        token=\"${COMP_WORDS[index]}\"",
            "        [[ \"$token\" == -* ]] && break",
            "        if __peekaboo_bash_has_subcommand \"$path\" \"$token\"; then",
            "            path=\"${path:+$path }$token\"",
            "            (( index++ ))",
            "        else",
            "            break",
            "        fi",
            "    done",
            "",
            "    if (( COMP_CWORD > 0 )); then",
            "        previous=\"${COMP_WORDS[COMP_CWORD - 1]}\"",
            "    fi",
            "",
            "    local option_values",
            "    option_values=\"$(__peekaboo_bash_option_values \"$path\" \"$previous\" | cut -f1 | tr '\\n' ' ')\"",
            "    if [[ -n \"$option_values\" ]]; then",
            "        COMPREPLY=($(compgen -W \"$option_values\" -- \"$cur\"))",
            "        return",
            "    fi",
            "",
            "    if [[ \"$cur\" == -* ]]; then",
            "        COMPREPLY=($(compgen -W \"$(__peekaboo_bash_options \"$path\" | cut -f1 | tr '\\n' ' ')\" -- \"$cur\"))",
            "        return",
            "    fi",
            "",
            "    local subcommands",
            "    subcommands=\"$(__peekaboo_bash_subcommands \"$path\" | cut -f1 | tr '\\n' ' ')\"",
            "    if [[ -n \"$subcommands\" ]]; then",
            "        COMPREPLY=($(compgen -W \"$subcommands\" -- \"$cur\"))",
            "        return",
            "    fi",
            "",
            "    local argument_index=$(( COMP_CWORD - index ))",
            "    local values",
            "    values=\"$(__peekaboo_bash_argument_values \"$path\" \"$argument_index\" | cut -f1 | tr '\\n' ' ')\"",
            "    if [[ -n \"$values\" ]]; then",
            "        COMPREPLY=($(compgen -W \"$values\" -- \"$cur\"))",
            "    fi",
            "}",
            "",
            "complete -F __peekaboo_bash_complete \(document.commandName)",
        ]

        return lines.joined(separator: "\n")
    }

    private func renderBashChoiceSwitch(
        _ paths: [CompletionPath],
        accessor: KeyPath<CompletionPath, [CompletionChoice]>
    ) -> String {
        var lines = ["    case \"$1\" in"]
        lines.append(contentsOf: self.renderCases(paths: paths) { path in
            path[keyPath: accessor].map { choice in
                self.tabSeparated(choice.value, choice.help)
            }
        })
        lines.append(contentsOf: [
            "        *)",
            "            ;;",
            "    esac",
        ])
        return lines.joined(separator: "\n")
    }

    private func renderBashOptionSwitch(document: CompletionScriptDocument) -> String {
        var lines = ["    case \"$1\" in", "        '')"]
        lines.append(contentsOf: self.heredocLines(items: document.rootOptions.map { option in
            option.names.map { name in
                self.tabSeparated(name, option.help)
            }
        }.flatMap(\.self), indent: "            "))
        lines.append("            ;;")
        lines.append(contentsOf: self.renderCases(paths: document.flattenedPaths) { path in
            path.options.flatMap { option in
                option.names.map { name in
                    self.tabSeparated(name, option.help)
                }
            }
        })
        lines.append(contentsOf: [
            "        *)",
            "            ;;",
            "    esac",
        ])
        return lines.joined(separator: "\n")
    }

    private func renderBashArgumentSwitch(_ paths: [CompletionPath]) -> String {
        var lines = ["    case \"$1:$2\" in"]
        for path in paths {
            for (index, argument) in path.arguments.enumerated() where !argument.choices.isEmpty {
                lines.append("        '\(self.caseLabel(path.key)):\(index)')")
                lines.append(contentsOf: self.heredocLines(items: argument.choices.map {
                    self.tabSeparated($0.value, $0.help)
                }, indent: "            "))
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

    private func renderBashOptionValueSwitch(_ paths: [CompletionPath]) -> String {
        var lines = ["    case \"$1:$2\" in"]
        for path in paths {
            for option in path.options where !option.valueChoices.isEmpty {
                for name in option.names {
                    lines.append("        '\(self.caseLabel(path.key)):\(self.caseLabel(name))')")
                    lines.append(contentsOf: self.heredocLines(items: option.valueChoices.map {
                        self.tabSeparated($0.value, $0.help)
                    }, indent: "            "))
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

    private func renderCases(
        paths: [CompletionPath],
        content: (CompletionPath) -> [String]
    ) -> [String] {
        paths.map { path in
            let items = content(path)
            if items.isEmpty {
                return [
                    "        '\(self.caseLabel(path.key))')",
                    "            ;;",
                ]
            }
            return [
                "        '\(self.caseLabel(path.key))')",
            ] + self.heredocLines(items: items, indent: "            ") + [
                "            ;;",
            ]
        }.flatMap(\.self)
    }

    private func heredocLines(items: [String], indent: String) -> [String] {
        guard !items.isEmpty else { return [] }
        return [
            "\(indent)cat <<'EOF'",
        ] + items + [
            "EOF",
        ]
    }

    private func tabSeparated(_ value: String, _ help: String?) -> String {
        let tab = "\t"
        let description = (help ?? "").replacingOccurrences(of: "\t", with: " ").replacingOccurrences(
            of: "\n",
            with: " "
        )
        return "\(value)\(tab)\(description)"
    }

    private func caseLabel(_ label: String) -> String {
        label.replacingOccurrences(of: "'", with: "'\\''")
    }

    private func commonHeader(shell: String, install: String) -> [String] {
        [
            "# \(shell.capitalized) completion for peekaboo",
            "# Generated from Commander descriptors via `peekaboo completions \(shell)`.",
            "# Install with:",
            "#   \(install)",
            "",
        ]
    }
}

import Foundation

/// Renders a fish completion script using fish-native helper functions and a
/// single dynamic `complete -a` callback.
struct FishCompletionRenderer: ShellCompletionRendering {
    func render(document: CompletionScriptDocument) -> String {
        let lines = [
            "# Fish completion for peekaboo",
            "# Generated from Commander descriptors via `peekaboo completions fish`.",
            "# Install with:",
            "#   \(CompletionsCommand.Shell.fish.installationSnippet)",
            "",
            "function __peekaboo_fish_subcommands",
            self.renderFishChoiceSwitch(document.pathsIncludingRoot, accessor: \.subcommands),
            "end",
            "",
            "function __peekaboo_fish_options",
            self.renderFishOptionSwitch(document: document),
            "end",
            "",
            "function __peekaboo_fish_argument_values",
            self.renderFishArgumentSwitch(document.pathsIncludingRoot),
            "end",
            "",
            "function __peekaboo_fish_option_values",
            self.renderFishOptionValueSwitch(document.pathsIncludingRoot),
            "end",
            "",
            "function __peekaboo_fish_has_subcommand",
            "    set -l path $argv[1]",
            "    set -l candidate $argv[2]",
            "    for line in (__peekaboo_fish_subcommands \"$path\")",
            "        set -l parts (string split \\t -- $line)",
            "        if test (count $parts) -gt 0; and test \"$parts[1]\" = \"$candidate\"",
            "            return 0",
            "        end",
            "    end",
            "    return 1",
            "end",
            "",
            "function __peekaboo_fish_append_path",
            "    if test -n \"$argv[1]\"",
            "        printf '%s %s\\n' \"$argv[1]\" \"$argv[2]\"",
            "    else",
            "        printf '%s\\n' \"$argv[2]\"",
            "    end",
            "end",
            "",
            "function __peekaboo_fish_complete",
            "    set -l tokens (commandline -opc)",
            "    if test (count $tokens) -gt 0",
            "        set -e tokens[1]",
            "    end",
            "    set -l current (commandline -ct)",
            "    set -l path ''",
            "    set -l index 1",
            "    set -l previous ''",
            "    set -l token_count (count $tokens)",
            "",
            "    while test $index -le $token_count",
            "        set -l token $tokens[$index]",
            "        if string match -qr '^-' -- $token",
            "            break",
            "        end",
            "        if __peekaboo_fish_has_subcommand \"$path\" \"$token\"",
            "            set path (__peekaboo_fish_append_path \"$path\" \"$token\")",
            "            set index (math \"$index + 1\")",
            "        else",
            "            break",
            "        end",
            "    end",
            "",
            "    if test $token_count -gt 0",
            "        set previous $tokens[$token_count]",
            "    end",
            "",
            "    set -l option_values (__peekaboo_fish_option_values \"$path\" \"$previous\")",
            "    if test (count $option_values) -gt 0",
            "        printf '%s\\n' $option_values",
            "        return",
            "    end",
            "",
            "    if string match -qr '^-' -- $current",
            "        __peekaboo_fish_options \"$path\"",
            "        return",
            "    end",
            "",
            "    set -l subcommands (__peekaboo_fish_subcommands \"$path\")",
            "    if test (count $subcommands) -gt 0",
            "        printf '%s\\n' $subcommands",
            "        return",
            "    end",
            "",
            "    set -l argument_index (math \"$token_count - $index + 1\")",
            "    __peekaboo_fish_argument_values \"$path\" \"$argument_index\"",
            "end",
            "",
            "complete -c \(document.commandName) -f -a '(__peekaboo_fish_complete)'",
        ]

        return lines.joined(separator: "\n")
    }

    private func renderFishChoiceSwitch(
        _ paths: [CompletionPath],
        accessor: KeyPath<CompletionPath, [CompletionChoice]>
    ) -> String {
        var lines = ["    switch $argv[1]"]
        for path in paths {
            lines.append("        case '\(self.fishEscaped(path.key))'")
            for choice in path[keyPath: accessor] {
                lines
                    .append(
                        "            printf '%s\\t%s\\n' '\(self.fishEscaped(choice.value))' '\(self.fishEscaped(choice.help ?? ""))'"
                    )
            }
        }
        lines.append(contentsOf: [
            "        case '*'",
            "    end",
        ])
        return lines.joined(separator: "\n")
    }

    private func renderFishOptionSwitch(document: CompletionScriptDocument) -> String {
        var lines = ["    switch $argv[1]", "        case ''"]
        for option in document.rootOptions {
            for name in option.names {
                lines
                    .append(
                        "            printf '%s\\t%s\\n' '\(self.fishEscaped(name))' '\(self.fishEscaped(option.help))'"
                    )
            }
        }
        for path in document.flattenedPaths {
            lines.append("        case '\(self.fishEscaped(path.key))'")
            for option in path.options {
                for name in option.names {
                    lines
                        .append(
                            "            printf '%s\\t%s\\n' '\(self.fishEscaped(name))' '\(self.fishEscaped(option.help))'"
                        )
                }
            }
        }
        lines.append(contentsOf: [
            "        case '*'",
            "    end",
        ])
        return lines.joined(separator: "\n")
    }

    private func renderFishArgumentSwitch(_ paths: [CompletionPath]) -> String {
        var lines = ["    switch \"$argv[1]:$argv[2]\""]
        for path in paths {
            for (index, argument) in path.arguments.enumerated() where !argument.choices.isEmpty {
                lines.append("        case '\(self.fishEscaped(path.key)):\(index)'")
                for choice in argument.choices {
                    lines
                        .append(
                            "            printf '%s\\t%s\\n' '\(self.fishEscaped(choice.value))' '\(self.fishEscaped(choice.help ?? ""))'"
                        )
                }
            }
        }
        lines.append(contentsOf: [
            "        case '*'",
            "    end",
        ])
        return lines.joined(separator: "\n")
    }

    private func renderFishOptionValueSwitch(_ paths: [CompletionPath]) -> String {
        var lines = ["    switch \"$argv[1]:$argv[2]\""]
        for path in paths {
            for option in path.options where !option.valueChoices.isEmpty {
                for name in option.names {
                    lines.append("        case '\(self.fishEscaped(path.key)):\(self.fishEscaped(name))'")
                    for choice in option.valueChoices {
                        lines
                            .append(
                                "            printf '%s\\t%s\\n' '\(self.fishEscaped(choice.value))' '\(self.fishEscaped(choice.help ?? ""))'"
                            )
                    }
                }
            }
        }
        lines.append(contentsOf: [
            "        case '*'",
            "    end",
        ])
        return lines.joined(separator: "\n")
    }

    private func fishEscaped(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "'", with: "\\'")
            .replacingOccurrences(of: "\t", with: " ")
            .replacingOccurrences(of: "\n", with: " ")
    }
}

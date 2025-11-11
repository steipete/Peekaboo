import Commander
import Foundation
import PeekabooCore

@MainActor

struct LearnCommand {
    @RuntimeStorage private var runtime: CommandRuntime?

    private var resolvedRuntime: CommandRuntime {
        guard let runtime else {
            preconditionFailure("CommandRuntime must be configured before accessing runtime resources")
        }
        return runtime
    }

    private var logger: Logger { self.resolvedRuntime.logger }

    @MainActor
    mutating func run(using runtime: CommandRuntime) async throws {
        self.runtime = runtime
        let systemPrompt = AgentSystemPrompt.generate()
        let tools = ToolRegistry.allTools
        self.outputComprehensiveGuide(systemPrompt: systemPrompt, tools: tools)
    }

    private func outputComprehensiveGuide(systemPrompt: String, tools: [PeekabooToolDefinition]) {
        print("""
        # Peekaboo Comprehensive Guide

        This guide contains everything you need to know about using Peekaboo for macOS automation.

        ## System Instructions

        \(systemPrompt)

        ## Available Tools

        Peekaboo provides 30+ tools for macOS automation. Each tool is designed for a specific purpose and can be combined to create powerful workflows.
        """)

        let groupedTools = ToolRegistry.toolsByCategory()
        for category in ToolCategory.allCases {
            guard let categoryTools = groupedTools[category], !categoryTools.isEmpty else { continue }

            print("\n### \(category.icon) \(category.rawValue) Tools\n")
            for tool in categoryTools.sorted(by: { $0.name < $1.name }) {
                print("#### `\(tool.name)`\n")
                print("\(tool.abstract)\n")

                if let guidance = tool.agentGuidance {
                    print("**\(guidance)**\n")
                }

                if !tool.parameters.isEmpty {
                    print("**Parameters:**")
                    for param in tool.parameters where param.cliOptions?.argumentType != .argument {
                        var line = "- `\(param.name)` (\(param.type)"
                        if param.required {
                            line += ", **required**"
                        }
                        line += "): \(param.description)"
                        if let defaultValue = param.defaultValue {
                            line += " Default: `\(defaultValue)`"
                        }
                        print(line)

                        if let options = param.options {
                            print("  - Options: `\(options.joined(separator: "`, `"))`")
                        }
                    }
                    print()
                }

                if !tool.examples.isEmpty {
                    print("**Examples:**")
                    print("```json")
                    tool.examples.forEach { print($0) }
                    print("```")
                }
                print()
            }
        }

        print("""
        ## Usage Best Practices

        1. Always start with `see` to understand the UI before interacting.
        2. Click in the center of elements for reliable interactions.
        3. Verify each action before proceeding; use `see` again if needed.
        4. Manage windows with `list_windows` and `focus_window` before automation.
        5. Recover from errors by trying alternative interactions (menus, hotkeys).
        6. Common workflows:
           - Screenshot: `image` with `--app` or `--mode screen`.
           - Typing: `click` the field, then `type` the text.
           - Menus: `menu click --path ...`.
           - Keyboard shortcuts: `hotkey`.

        ## Quick Reference
        - **Vision**: see, screenshot, window_capture
        - **UI Automation**: click, type, scroll, hotkey, swipe, drag
        - **Window Management**: list_windows, focus_window, resize_window, list_spaces
        - **Applications**: list_apps, launch_app, quit_app
        - **Elements**: find_element, list_elements, focused
        - **Menu/Dialog**: menu_click, dialog_click, dialog_input
        - **System**: shell, done, need_info

        Remember: You are Peekaboo, an AI-powered screen automation assistant.
        Be confident, be helpful, and get things done!
        """)

        self.outputCommanderSummary()
    }

    @MainActor
    private func outputCommanderSummary() {
        print("\n## Commander Command Signatures\n")
        let summaries = CommanderRegistryBuilder.buildCommandSummaries()
            .sorted { $0.name < $1.name }

        for summary in summaries {
            print("### `peekaboo \(summary.name)`\n")
            if !summary.arguments.isEmpty {
                print("**Positional Arguments:**")
                for argument in summary.arguments {
                    let optionality = argument.isOptional ? "(optional)" : "(required)"
                    let description = argument.help ?? ""
                    print("- `\(argument.label)` \(optionality) \(description)")
                }
                print()
            }
            if !summary.options.isEmpty {
                print("**Options:**")
                for option in summary.options {
                    let names = option.names.map { "`\($0)`" }.joined(separator: ", ")
                    let description = option.help ?? "No description"
                    print("- \(names) – \(description)")
                }
                print()
            }
            if !summary.flags.isEmpty {
                print("**Flags:**")
                for flag in summary.flags {
                    let names = flag.names.map { "`\($0)`" }.joined(separator: ", ")
                    let description = flag.help ?? "No description"
                    print("- \(names) – \(description)")
                }
                print()
            }
        }
    }
}

@MainActor
extension LearnCommand: ParsableCommand {
    nonisolated(unsafe) static var configuration: CommandConfiguration {
        MainActorCommandConfiguration.describe {
            CommandConfiguration(
                commandName: "learn",
                abstract: "Display comprehensive usage guide for AI agents",
                discussion: """
                Outputs a complete guide to Peekaboo's automation capabilities in one go.
                Includes system instructions, tool definitions, and best practices so AI agents can load everything at once.
                """
            )
        }
    }
}

extension LearnCommand: AsyncRuntimeCommand {}

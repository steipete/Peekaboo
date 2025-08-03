import ArgumentParser
import Foundation
import PeekabooCore

// MARK: - Learn Command

/// Command to display comprehensive Peekaboo usage guide for AI agents
struct LearnCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "learn",
        abstract: "Display comprehensive usage guide for AI agents",
        discussion: """
        Outputs a complete guide to Peekaboo's automation capabilities in one go.
        This command is designed for AI agents to load all necessary context
        about Peekaboo's tools and usage patterns in a single operation.

        Usage:
          peekaboo learn

        The output includes:
        • System instructions for the AI agent
        • Complete list of all available tools
        • Detailed parameters and examples for each tool
        • Best practices and usage patterns
        """
    )

    func run() async throws {
        // Get the system prompt
        let systemPrompt = AgentSystemPrompt.generate()

        // Get all tools from the registry
        let tools = ToolRegistry.allTools

        // Output everything in one comprehensive guide
        self.outputComprehensiveGuide(systemPrompt: systemPrompt, tools: tools)
    }

    // MARK: - Comprehensive Output

    private func outputComprehensiveGuide(systemPrompt: String, tools: [UnifiedToolDefinition]) {
        print("""
        # Peekaboo Comprehensive Guide

        This guide contains everything you need to know about using Peekaboo for macOS automation.

        ## System Instructions

        \(systemPrompt)

        ## Available Tools

        Peekaboo provides 30+ tools for macOS automation. Each tool is designed for a specific purpose and can be combined to create powerful workflows.
        """)

        // Group tools by category
        let groupedTools = ToolRegistry.toolsByCategory()
        let categories = ToolCategory.allCases

        for category in categories {
            guard let categoryTools = groupedTools[category], !categoryTools.isEmpty else { continue }

            print("\n### \(category.icon) \(category.rawValue) Tools\n")

            for tool in categoryTools.sorted(by: { $0.name < $1.name }) {
                print("#### `\(tool.name)`")
                print("\n\(tool.abstract)\n")

                // Include agent guidance if available
                if let guidance = tool.agentGuidance {
                    print("**\(guidance)**\n")
                }

                if !tool.parameters.isEmpty {
                    print("**Parameters:**")
                    for param in tool.parameters {
                        // Skip CLI-only argument parameters for agent docs
                        if param.cliOptions?.argumentType == .argument {
                            continue
                        }

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
                    for example in tool.examples {
                        print(example)
                    }
                    print("```")
                }
                print()
            }
        }

        print("""
        ## Usage Best Practices

        ### 1. Always Start with 'see'
        Before any UI interaction, use the 'see' tool to understand the current state of the screen or application. This gives you accurate coordinates and element information.

        ### 2. Click in the Center
        When clicking on UI elements, always target the center of the element, not the edges or corners. This ensures reliable interaction.

        ### 3. Verify Actions
        After each action, verify it succeeded before proceeding. Use 'see' again if needed to confirm state changes.

        ### 4. Window Management
        - Use `list_windows` to find available windows
        - Use `focus_window` to bring windows to front before interaction
        - Use `launch_app` if the app isn't running

        ### 5. Error Recovery
        - If clicking fails, try menu items or keyboard shortcuts
        - If an element isn't found, refresh with 'see'
        - Check if windows are blocked by dialogs

        ### 6. Common Workflows
        - **Screenshot**: Use `screenshot` with app name or window title
        - **Type text**: First `click` the field, then `type` the text
        - **Menu items**: Use `menu_click` with full menu path
        - **Keyboard shortcuts**: Use `hotkey` with modifier keys

        ## Quick Reference

        - **Vision**: see, screenshot, window_capture
        - **UI Automation**: click, type, scroll, hotkey, swipe, drag
        - **Window Management**: list_windows, focus_window, resize_window, list_spaces
        - **Applications**: list_apps, launch_app, quit_app
        - **Elements**: find_element, list_elements, focused
        - **Menu/Dialog**: menu_click, dialog_click, dialog_input
        - **System**: shell, done, need_info

        ---

        Remember: You are Peekaboo, an AI-powered screen automation assistant.
        Be confident, be helpful, and get things done!
        """)
    }
}

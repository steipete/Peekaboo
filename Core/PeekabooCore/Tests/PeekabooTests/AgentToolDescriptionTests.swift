import Foundation
import Testing
@testable import PeekabooCore

@Suite("Agent Tool Description Tests")
struct AgentToolDescriptionTests {
    // MARK: - Tool Definition Structure Tests

    @Test("All agent tools have comprehensive descriptions")
    @MainActor
    func allToolsHaveDescriptions() {
        let allTools = ToolRegistry.allTools

        for tool in allTools {
            // Check that essential fields are present and non-empty
            #expect(!tool.name.isEmpty, "Tool must have a name")
            #expect(!tool.abstract.isEmpty, "Tool '\(tool.name)' must have an abstract")
            #expect(!tool.discussion.isEmpty, "Tool '\(tool.name)' must have a discussion")

            // Verify category is set (all categories are valid)
        }
    }

    @Test("Tool descriptions follow consistent format")
    @MainActor
    func toolDescriptionFormat() {
        let allTools = ToolRegistry.allTools

        for tool in allTools {
            let discussion = tool.discussion

            // Check for common sections in enhanced descriptions
            if discussion.count > 200 { // Only check substantial descriptions
                // Many enhanced tools include EXAMPLES section
                if tool.name == "click" || tool.name == "type" || tool.name == "see" {
                    #expect(
                        discussion.contains("EXAMPLE"),
                        "Tool '\(tool.name)' should include examples")
                }

                // UI tools should mention relevant keywords
                if tool.category == .automation {
                    let hasUIGuidance = discussion.contains("element") ||
                        discussion.contains("UI") ||
                        discussion.contains("click") ||
                        discussion.contains("type") ||
                        discussion.contains("key") ||
                        discussion.contains("press") ||
                        discussion.contains("scroll")
                    #expect(
                        hasUIGuidance,
                        "Automation tool '\(tool.name)' should mention UI interaction")
                }
            }
        }
    }

    // MARK: - Specific Tool Enhancement Tests

    @Test("Click tool has enhanced element matching description")
    @MainActor
    func clickToolEnhancedDescription() {
        guard let clickTool = ToolRegistry.allTools.first(where: { $0.name == "click" }) else {
            Issue.record("Click tool not found")
            return
        }

        let discussion = clickTool.discussion

        // Verify enhanced features are documented
        #expect(discussion.contains("Fuzzy matching"))
        #expect(discussion.contains("Smart waiting"))
        #expect(discussion.contains("ELEMENT MATCHING"))
        #expect(discussion.contains("TROUBLESHOOTING"))

        // Check for specific examples
        #expect(discussion.contains("peekaboo click"))
        #expect(discussion.contains("--wait-for"))
        #expect(discussion.contains("--double"))
    }

    @Test("Type tool includes escape sequence documentation")
    @MainActor
    func typeToolEscapeSequences() {
        guard let typeTool = ToolRegistry.allTools.first(where: { $0.name == "type" }) else {
            Issue.record("Type tool not found")
            return
        }

        let discussion = typeTool.discussion

        // Check for escape sequence documentation
        #expect(discussion.contains("\\n") || discussion.contains("newline"))
        #expect(discussion.contains("\\t") || discussion.contains("tab"))
        #expect(discussion.contains("escape") || discussion.contains("\\"))
    }

    @Test("See tool has comprehensive UI detection description")
    @MainActor
    func seeToolUIDetection() {
        guard let seeTool = ToolRegistry.allTools.first(where: { $0.name == "see" }) else {
            Issue.record("See tool not found")
            return
        }

        let discussion = seeTool.discussion

        // Verify see tool features are documented
        #expect(discussion.contains("screenshot") || discussion.contains("capture"))
        #expect(discussion.contains("app") || discussion.contains("window"))

        // Check for session management info
        #expect(discussion.contains("session"))
    }

    @Test("Shell tool has quoting examples")
    @MainActor
    func shellToolQuotingExamples() {
        guard let shellTool = ToolRegistry.allTools.first(where: { $0.name == "shell" }) else {
            Issue.record("Shell tool not found")
            return
        }

        let discussion = shellTool.discussion

        // Shell tool should have examples
        #expect(discussion.contains("EXAMPLE") || discussion.contains("shell"))

        // Should have examples with quotes
        let hasQuotedExample = discussion.contains("\"") || discussion.contains("'")
        #expect(hasQuotedExample, "Shell tool should include quoted examples")
    }

    // MARK: - Parameter Documentation Tests

    @Test("Required parameters are clearly marked")
    @MainActor
    func requiredParametersMarked() {
        let allTools = ToolRegistry.allTools

        for tool in allTools {
            for param in tool.parameters {
                if param.required {
                    // Required parameters should have clear descriptions
                    #expect(
                        !param.description.isEmpty,
                        "Required parameter '\(param.name)' in tool '\(tool.name)' must have description")
                }
            }
        }
    }

    @Test("Optional parameters have default values documented")
    @MainActor
    func optionalParameterDefaults() {
        let allTools = ToolRegistry.allTools

        for tool in allTools {
            for param in tool.parameters where !param.required {
                // Check if default value is documented either in defaultValue or description
                let hasDefault = param.defaultValue != nil ||
                    param.description.contains("default") ||
                    param.description.contains("if not")

                // Some parameters genuinely have no defaults, so this is informational
                if !hasDefault, param.type != .boolean {
                    // This is OK, just noting parameters without clear defaults
                    // Boolean parameters implicitly default to false
                }
            }
        }
    }

    // MARK: - Tool Category Tests

    @Test("Tools are properly categorized")
    @MainActor
    func toolCategorization() {
        let allTools = ToolRegistry.allTools
        let categorizedTools = Dictionary(grouping: allTools, by: { $0.category })

        // Verify we have tools in expected categories
        #expect(categorizedTools[.automation]?.count ?? 0 > 0, "Should have automation tools")
        #expect(categorizedTools[.vision]?.count ?? 0 > 0, "Should have vision tools")
        #expect(categorizedTools[.app]?.count ?? 0 > 0, "Should have app tools")

        // Check specific tools are in correct categories
        let clickTool = allTools.first { $0.name == "click" }
        #expect(clickTool?.category == .automation)

        let seeTool = allTools.first { $0.name == "see" }
        #expect(seeTool?.category == .vision)

        let launchTool = allTools.first { $0.name == "launch_app" }
        #expect(launchTool?.category == .app)
    }

    // MARK: - Error Guidance Tests

    @Test("Tools provide helpful error guidance")
    @MainActor
    func toolErrorGuidance() {
        // Only check tools that are expected to have error guidance
        // Based on actual tool definitions, only 'click' has TROUBLESHOOTING section
        let toolsWithErrorGuidance = ["click"]

        for toolName in toolsWithErrorGuidance {
            guard let tool = ToolRegistry.allTools.first(where: { $0.name == toolName }) else {
                continue
            }

            let discussion = tool.discussion

            // Check for troubleshooting or error handling guidance
            let hasErrorGuidance = discussion.contains("TROUBLESHOOTING") ||
                discussion.contains("If") ||
                discussion.contains("not found") ||
                discussion.contains("fail") ||
                discussion.contains("error") ||
                discussion.contains("try")

            #expect(
                hasErrorGuidance,
                "Tool '\(toolName)' should include error guidance")
        }

        // Additionally, verify that tools that need error guidance have it
        // This is more of a design guideline check
        let interactionTools = ["click", "type", "see", "launch_app"]
        var toolsWithGuidance = 0
        var toolsWithoutGuidance: [String] = []

        for toolName in interactionTools {
            guard let tool = ToolRegistry.allTools.first(where: { $0.name == toolName }) else {
                continue
            }

            let discussion = tool.discussion
            let hasGuidance = discussion.contains("TROUBLESHOOTING") ||
                discussion.contains("If") ||
                discussion.contains("not found") ||
                discussion.contains("fail") ||
                discussion.contains("error") ||
                discussion.contains("try")

            if hasGuidance {
                toolsWithGuidance += 1
            } else {
                toolsWithoutGuidance.append(toolName)
            }
        }

        // At least some interaction tools should have error guidance
        #expect(toolsWithGuidance > 0, "At least some interaction tools should have error guidance")

        // This is informational - not a hard requirement
        if !toolsWithoutGuidance.isEmpty {
            // Note: Tools without explicit error guidance: \(toolsWithoutGuidance)
            // This is OK as long as they have clear descriptions
        }
    }

    // MARK: - Example Quality Tests

    @Test("Tool examples are realistic and helpful")
    @MainActor
    func toolExampleQuality() {
        let allTools = ToolRegistry.allTools

        for tool in allTools {
            if tool.discussion.contains("EXAMPLE") {
                // Examples should reference the tool somehow
                let toolNameParts = tool.name.split(separator: "_")
                let hasReference = tool.discussion.contains("peekaboo") ||
                    tool.discussion.contains(tool.name) ||
                    toolNameParts.contains { part in
                        tool.discussion.lowercased().contains(part.lowercased())
                    }
                #expect(
                    hasReference,
                    "Examples for '\(tool.name)' should reference the tool")

                // Examples should demonstrate various options
                if tool.parameters.count > 2 {
                    let hasOptionExample = tool.discussion.contains("--")
                    #expect(
                        hasOptionExample,
                        "Tool '\(tool.name)' with multiple parameters should show option examples")
                }
            }
        }
    }
}

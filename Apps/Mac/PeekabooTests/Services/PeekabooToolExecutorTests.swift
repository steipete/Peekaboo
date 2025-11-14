import Foundation
import PeekabooCore
import Testing
@testable import Peekaboo

@Suite("ToolRegistry Tests", .tags(.tools, .unit))
@MainActor
struct ToolRegistryTests {
    @Test("All expected tools are registered")
    func allToolsAreRegistered() {
        let allTools = ToolRegistry.allTools()
        #expect(!allTools.isEmpty)

        let toolNames = Set(allTools.map(\.name))

        let expectedTools: Set<String> = [
            "see",
            "click",
            "type",
            "press",
            "scroll",
            "hotkey",
            "list_apps",
            "launch_app",
            "menu_click",
            "list_menus",
            "dialog_click",
            "dialog_input",
            "dock_launch",
            "list_dock",
            "shell",
            "done",
            "need_info",
        ]

        #expect(toolNames.isSuperset(of: expectedTools))
    }

    @Test("Tool definitions are valid")
    func toolDefinitionsAreValid() {
        let allTools = ToolRegistry.allTools()

        for tool in allTools {
            #expect(!tool.name.isEmpty)
            #expect(!tool.abstract.isEmpty)

            for param in tool.parameters {
                #expect(!param.name.isEmpty)
                #expect(!param.description.isEmpty)
            }
        }
    }

    @Test("Can retrieve a tool by name")
    func getToolByName() {
        let tool = ToolRegistry.tool(named: "see")
        #expect(tool != nil)
        #expect(tool?.name == "see")
    }

    @Test("Tools are grouped by category")
    func toolsAreGroupedByCategory() {
        let categorizedTools = ToolRegistry.toolsByCategory()
        #expect(!categorizedTools.isEmpty)
        #expect(categorizedTools[.vision] != nil)
        #expect(categorizedTools[.ui] != nil)
        #expect(categorizedTools[.application] != nil)
    }
}

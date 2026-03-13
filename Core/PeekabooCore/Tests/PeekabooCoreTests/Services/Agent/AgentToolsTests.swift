//
//  AgentToolsTests.swift
//  PeekabooCore
//

import Foundation
import Tachikoma
import Testing
@testable import PeekabooAgentRuntime
@testable import PeekabooAutomation
@testable import PeekabooCore
@testable import PeekabooVisualizer

struct AgentToolsTests {
    @Test
    @MainActor
    func `All agent tools are created`() {
        let agentService = PeekabooAgentService(
            services: PeekabooServiceProvider())

        let tools = agentService.createAgentTools()

        // Verify all expected tools are present
        let toolNames = tools.map(\.name)

        // Vision tools
        #expect(toolNames.contains("see"))
        #expect(toolNames.contains("screenshot"))
        #expect(toolNames.contains("window_capture"))

        // UI automation tools
        #expect(toolNames.contains("click"))
        #expect(toolNames.contains("type"))
        #expect(toolNames.contains("press"))
        #expect(toolNames.contains("scroll"))
        #expect(toolNames.contains("hotkey"))

        // Window management tools
        #expect(toolNames.contains("list_windows"))
        #expect(toolNames.contains("focus_window"))
        #expect(toolNames.contains("resize_window"))
        #expect(toolNames.contains("list_screens"))

        // Application tools
        #expect(toolNames.contains("list_apps"))
        #expect(toolNames.contains("launch_app"))

        // Element tools
        #expect(toolNames.contains("find_element"))
        #expect(toolNames.contains("list_elements"))
        #expect(toolNames.contains("focused"))

        // Menu tools
        #expect(toolNames.contains("menu_click"))
        #expect(toolNames.contains("list_menus"))

        // Dialog tools
        #expect(toolNames.contains("dialog_click"))
        #expect(toolNames.contains("dialog_input"))

        // Dock tools
        #expect(toolNames.contains("dock_launch"))
        #expect(toolNames.contains("list_dock"))

        // Shell tool
        #expect(toolNames.contains("shell"))

        // Completion tools
        #expect(toolNames.contains("done"))
        #expect(toolNames.contains("need_info"))
    }

    @Test
    @MainActor
    func `Click tool has correct parameters`() {
        let agentService = PeekabooAgentService(
            services: PeekabooServiceProvider())

        let clickTool = agentService.createClickTool()

        #expect(clickTool.name == "click")
        #expect(!clickTool.description.isEmpty)

        // Check parameters
        let params = clickTool.parameters.properties
        let paramNames = params.map(\.name)

        #expect(paramNames.contains("query"))
        #expect(paramNames.contains("app"))
        #expect(paramNames.contains("double"))
        #expect(paramNames.contains("right"))
    }

    @Test
    @MainActor
    func `Type tool has correct parameters`() {
        let agentService = PeekabooAgentService(
            services: PeekabooServiceProvider())

        let typeTool = agentService.createTypeTool()

        #expect(typeTool.name == "type")
        #expect(!typeTool.description.isEmpty)

        // Check parameters
        let params = typeTool.parameters.properties
        let paramNames = params.map(\.name)

        #expect(paramNames.contains("text"))
        #expect(paramNames.contains("field"))
        #expect(paramNames.contains("app"))
        #expect(paramNames.contains("clear"))
    }

    @Test
    @MainActor
    func `Shell tool has safety checks`() async {
        let agentService = PeekabooAgentService(
            services: PeekabooServiceProvider())

        let shellTool = agentService.createShellTool()

        // Try to execute a dangerous command
        let result = await shellTool.execute([
            "command": .string("rm -rf /"),
        ])

        // Should fail with safety error
        if case let .error(error) = result {
            #expect(error.contains("safety") || error.contains("dangerous"))
        } else {
            Issue.record("Shell tool should block dangerous commands")
        }
    }

    @Test
    @MainActor
    func `Dialog input tool supports field targeting`() {
        let agentService = PeekabooAgentService(
            services: PeekabooServiceProvider())

        let dialogTool = agentService.createDialogInputTool()

        #expect(dialogTool.name == "dialog_input")

        // Check that field parameter exists and is properly described
        let params = dialogTool.parameters.properties
        if let fieldParam = params.first(where: { $0.name == "field" }) {
            #expect(fieldParam.description.contains("label") || fieldParam.description.contains("placeholder"))
            #expect(!fieldParam.description.contains("not yet implemented"))
        } else {
            Issue.record("Dialog input tool should have field parameter")
        }
    }

    @Test
    @MainActor
    func `Completion tools work correctly`() async {
        let agentService = PeekabooAgentService(
            services: PeekabooServiceProvider())

        // Test done tool
        let doneTool = agentService.createDoneTool()
        let doneResult = await doneTool.execute([
            "summary": .string("Task completed successfully"),
        ])

        if case let .string(text) = doneResult {
            #expect(text.contains("\(AgentDisplayTokens.Status.success)"))
            #expect(text.contains("completed"))
        } else {
            Issue.record("Done tool should return success message")
        }

        // Test need_info tool
        let needInfoTool = agentService.createNeedInfoTool()
        let needInfoResult = await needInfoTool.execute([
            "question": .string("What is the target application?"),
            "context": .string("Multiple apps are running"),
        ])

        if case let .string(text) = needInfoResult {
            #expect(text.contains("\(AgentDisplayTokens.Status.info)"))
            #expect(text.contains("What is the target application"))
            #expect(text.contains("Multiple apps"))
        } else {
            Issue.record("Need info tool should return question")
        }
    }
}

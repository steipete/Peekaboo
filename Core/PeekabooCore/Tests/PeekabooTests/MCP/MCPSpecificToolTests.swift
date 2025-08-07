import Foundation
import MCP
import TachikomaMCP
import Testing
@testable import PeekabooCore

@Suite("MCP Specific Tool Tests")
struct MCPSpecificToolTests {
    // MARK: - See Tool Tests

    @Test("See tool schema includes annotation options")
    func seeToolSchema() {
        let tool = SeeTool()

        guard case let .object(schema) = tool.inputSchema,
              let properties = schema["properties"] as? Value,
              case let .object(props) = properties
        else {
            Issue.record("Expected object schema with properties")
            return
        }

        // Verify see tool properties
        #expect(props["annotate"] != nil)
        #expect(props["session"] != nil)
        #expect(props["app_target"] != nil)
        #expect(props["path"] != nil)

        // Check annotate default value
        if let annotateSchema = props["annotate"],
           case let .object(annotateDict) = annotateSchema
        {
            #expect(annotateDict["default"] as? Value == .bool(false))
        }
    }

    // MARK: - Dialog Tool Tests

    @Test("Dialog tool schema validation")
    func dialogToolSchema() {
        let tool = DialogTool()

        guard case let .object(schema) = tool.inputSchema,
              let properties = schema["properties"] as? Value,
              case let .object(props) = properties
        else {
            Issue.record("Expected object schema with properties")
            return
        }

        // Dialog tool should have action and optional parameters
        #expect(props["action"] != nil)
        #expect(props["button"] != nil)
        #expect(props["text"] != nil)
        #expect(props["field"] != nil)
        #expect(props["clear"] != nil)
        #expect(props["path"] != nil)
        #expect(props["select"] != nil)
        #expect(props["window"] != nil)
        #expect(props["name"] != nil)
        #expect(props["force"] != nil)
        #expect(props["index"] != nil)

        // Check action enum values
        if let actionSchema = props["action"],
           case let .object(actionDict) = actionSchema,
           let enumValue = actionDict["enum"] as? Value,
           case let .array(actions) = enumValue
        {
            #expect(actions.contains(.string("list")))
            #expect(actions.contains(.string("click")))
            #expect(actions.contains(.string("input")))
        }
    }

    // MARK: - Menu Tool Tests

    @Test("Menu tool schema includes path format")
    func menuToolSchema() {
        let tool = MenuTool()

        guard case let .object(schema) = tool.inputSchema,
              let properties = schema["properties"] as? Value,
              case let .object(props) = properties
        else {
            Issue.record("Expected object schema with properties")
            return
        }

        #expect(props["action"] != nil)
        #expect(props["path"] != nil)
        #expect(props["app"] != nil)

        // Verify path description includes format examples
        if let pathSchema = props["path"],
           case let .object(pathDict) = pathSchema,
           let description = pathDict["description"] as? Value,
           case let .string(desc) = description
        {
            #expect(desc.contains(">") || desc.contains("separator"))
        }
    }

    // MARK: - Space Tool Tests

    @Test("Space tool schema includes Mission Control actions")
    func spaceToolSchema() {
        let tool = SpaceTool()

        guard case let .object(schema) = tool.inputSchema,
              let properties = schema["properties"] as? Value,
              case let .object(props) = properties
        else {
            Issue.record("Expected object schema with properties")
            return
        }

        #expect(props["action"] != nil)
        #expect(props["to"] != nil)
        #expect(props["app"] != nil)
        #expect(props["window_title"] != nil)
        #expect(props["window_index"] != nil)
        #expect(props["to_current"] != nil)
        #expect(props["follow"] != nil)
        #expect(props["detailed"] != nil)

        // Check action types
        if let actionSchema = props["action"],
           case let .object(actionDict) = actionSchema,
           let enumValue = actionDict["enum"] as? Value,
           case let .array(actions) = enumValue
        {
            #expect(actions.contains(.string("list")))
            #expect(actions.contains(.string("switch")))
            #expect(actions.contains(.string("move-window")))
        }
    }

    // MARK: - Hotkey Tool Tests

    @Test("Hotkey tool schema includes modifier combinations")
    func hotkeyToolSchema() {
        let tool = HotkeyTool()

        guard case let .object(schema) = tool.inputSchema,
              let properties = schema["properties"] as? Value,
              case let .object(props) = properties
        else {
            Issue.record("Expected object schema with properties")
            return
        }

        #expect(props["keys"] != nil)
        #expect(props["hold_duration"] != nil)

        // Verify keys is required
        if let required = schema["required"] as? Value,
           case let .array(requiredArray) = required
        {
            #expect(requiredArray.contains(.string("keys")))
        }
    }

    // MARK: - Drag Tool Tests

    @Test("Drag tool schema includes coordinate support")
    func dragToolSchema() {
        let tool = DragTool()

        guard case let .object(schema) = tool.inputSchema,
              let properties = schema["properties"] as? Value,
              case let .object(props) = properties
        else {
            Issue.record("Expected object schema with properties")
            return
        }

        #expect(props["from"] != nil)
        #expect(props["to"] != nil)
        #expect(props["duration"] != nil)
        #expect(props["modifiers"] != nil)

        // Required fields
        if let required = schema["required"] as? Value,
           case let .array(requiredArray) = required
        {
            #expect(requiredArray.contains(.string("from")))
            #expect(requiredArray.contains(.string("to")))
        }
    }

    // MARK: - Window Tool Tests

    @Test("Window tool complex action schema")
    func windowToolSchema() {
        let tool = WindowTool()

        guard case let .object(schema) = tool.inputSchema,
              let properties = schema["properties"] as? Value,
              case let .object(props) = properties
        else {
            Issue.record("Expected object schema with properties")
            return
        }

        #expect(props["action"] != nil)
        #expect(props["app"] != nil)
        #expect(props["title"] != nil)
        #expect(props["index"] != nil)
        #expect(props["width"] != nil)
        #expect(props["height"] != nil)

        // Check action types include all window operations
        if let actionSchema = props["action"],
           case let .object(actionDict) = actionSchema,
           let enumValue = actionDict["enum"] as? Value,
           case let .array(actions) = enumValue
        {
            // Check that common actions are present
            #expect(actions.contains(.string("close")))
            #expect(actions.contains(.string("minimize")))
            #expect(actions.contains(.string("maximize")))
            #expect(actions.contains(.string("focus")))
        }
    }

    // MARK: - Move Tool Tests

    @Test("Move tool supports both coordinates and elements")
    func moveToolSchema() {
        let tool = MoveTool()

        guard case let .object(schema) = tool.inputSchema,
              let properties = schema["properties"] as? Value,
              case let .object(props) = properties
        else {
            Issue.record("Expected object schema with properties")
            return
        }

        #expect(props["to"] != nil)
        #expect(props["coordinates"] != nil)

        // Check description mentions coordinates
        if let toSchema = props["to"],
           case let .object(toDict) = toSchema,
           let description = toDict["description"] as? Value,
           case let .string(desc) = description
        {
            #expect(desc.contains("Coordinates") || desc.contains("x,y") || desc.contains("center"))
        }
    }

    // MARK: - Swipe Tool Tests

    @Test("Swipe tool direction validation")
    func swipeToolSchema() {
        let tool = SwipeTool()

        guard case let .object(schema) = tool.inputSchema,
              let properties = schema["properties"] as? Value,
              case let .object(props) = properties
        else {
            Issue.record("Expected object schema with properties")
            return
        }

        #expect(props["from"] != nil)
        #expect(props["to"] != nil)
        #expect(props["duration"] != nil)
        #expect(props["steps"] != nil)

        // Swipe tool has from/to required fields
        if let required = schema["required"] as? Value,
           case let .array(requiredArray) = required
        {
            #expect(requiredArray.contains(.string("from")))
            #expect(requiredArray.contains(.string("to")))
        }
    }

    // MARK: - Analyze Tool Tests

    @Test("Analyze tool supports multiple input formats")
    func analyzeToolSchema() {
        let tool = AnalyzeTool()

        guard case let .object(schema) = tool.inputSchema,
              let properties = schema["properties"] as? Value,
              case let .object(props) = properties
        else {
            Issue.record("Expected object schema with properties")
            return
        }

        #expect(props["image_path"] != nil)
        #expect(props["question"] != nil)
        #expect(props["provider_config"] != nil)

        // Verify required fields - only question is required
        if let required = schema["required"] as? Value,
           case let .array(requiredArray) = required
        {
            #expect(requiredArray.contains(.string("question")))
            #expect(requiredArray.count == 1) // Only question is required
        }
    }
}

@Suite("MCP Tool Description Tests")
struct MCPToolDescriptionTests {
    @Test("Tool descriptions include version and capabilities")
    func toolDescriptionsIncludeMetadata() {
        let tools: [MCPTool] = [
            ImageTool(),
            SeeTool(),
            ClickTool(),
            TypeTool(),
            MCPAgentTool(),
        ]

        for tool in tools {
            let description = tool.description

            // All tools should have non-empty descriptions
            #expect(!description.isEmpty)

            // Descriptions should be reasonably detailed
            #expect(description.count > 50)

            // Check for common patterns in descriptions
            #expect(
                description.contains("Peekaboo") ||
                    description.lowercased().contains("capture") ||
                    description.lowercased().contains("click") ||
                    description.lowercased().contains("type") ||
                    description.lowercased().contains("automat"))
        }
    }

    @Test("Tool names follow conventions")
    func toolNamingConventions() {
        let tools: [MCPTool] = [
            ImageTool(),
            AnalyzeTool(),
            ListTool(),
            PermissionsTool(),
            SleepTool(),
            SeeTool(),
            ClickTool(),
            TypeTool(),
            ScrollTool(),
            HotkeyTool(),
            SwipeTool(),
            DragTool(),
            MoveTool(),
            AppTool(),
            WindowTool(),
            MenuTool(),
            MCPAgentTool(),
            DockTool(),
            DialogTool(),
            SpaceTool(),
        ]

        for tool in tools {
            // Tool names should be lowercase
            #expect(tool.name == tool.name.lowercased())

            // Tool names should be single words or underscored
            #expect(!tool.name.contains(" "))
            #expect(!tool.name.contains("-"))

            // Tool names should be reasonable length
            #expect(tool.name.count > 2)
            #expect(tool.name.count < 20)
        }
    }
}

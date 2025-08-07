//
//  ToolDefinitions.swift
//  PeekabooCore
//

import Foundation

/// Vision tool definitions
@available(macOS 14.0, *)
public enum VisionToolDefinitions {
    public static let see = PeekabooToolDefinition(
        name: "see",
        commandName: "see",
        abstract: "Capture and analyze UI elements for automation",
        discussion: "Captures a screenshot and analyzes UI elements for automation. Returns UI element map with Peekaboo IDs.",
        category: .vision,
        parameters: [
            ParameterDefinition(
                name: "app",
                type: .string,
                description: "Application name to capture, or special values: 'menubar', 'frontmost'",
                required: false
            ),
            ParameterDefinition(
                name: "path",
                type: .string,
                description: "Path to save the screenshot",
                required: false
            ),
            ParameterDefinition(
                name: "annotate",
                type: .boolean,
                description: "Generate an annotated screenshot with interaction markers",
                required: false
            ),
            ParameterDefinition(
                name: "session",
                type: .string,
                description: "Session ID for UI automation state tracking",
                required: false
            ),
            ParameterDefinition(
                name: "jsonOutput",
                type: .boolean,
                description: "Output in JSON format",
                required: false
            )
        ],
        examples: [],
        agentGuidance: ""
    )
}

/// UI Automation tool definitions
@available(macOS 14.0, *)
public enum UIAutomationToolDefinitions {
    public static let click = PeekabooToolDefinition(
        name: "click",
        commandName: "click",
        abstract: "Click on UI elements or coordinates",
        discussion: "Clicks on UI elements or coordinates. Supports element queries, specific IDs from see command, or raw coordinates.",
        category: .ui,
        parameters: [
            ParameterDefinition(
                name: "query",
                type: .string,
                description: "Element text or query to click",
                required: false
            ),
            ParameterDefinition(
                name: "on",
                type: .string,
                description: "Element ID to click (e.g., B1, T2) from see command output",
                required: false
            ),
            ParameterDefinition(
                name: "coords",
                type: .string,
                description: "Click at specific coordinates in format 'x,y'",
                required: false
            ),
            ParameterDefinition(
                name: "double",
                type: .boolean,
                description: "Double-click instead of single click",
                required: false
            ),
            ParameterDefinition(
                name: "right",
                type: .boolean,
                description: "Right-click instead of left-click",
                required: false
            ),
            ParameterDefinition(
                name: "session",
                type: .string,
                description: "Session ID from see command",
                required: false
            ),
            ParameterDefinition(
                name: "waitFor",
                type: .number,
                description: "Maximum milliseconds to wait for element to become actionable",
                required: false
            ),
            ParameterDefinition(
                name: "spaceSwitch",
                type: .boolean,
                description: "Switch to target Space if needed",
                required: false
            ),
            ParameterDefinition(
                name: "bringToCurrentSpace",
                type: .boolean,
                description: "Bring window to current Space instead of switching",
                required: false
            ),
            ParameterDefinition(
                name: "autoFocus",
                type: .boolean,
                description: "Automatically focus application before clicking",
                required: false
            ),
            ParameterDefinition(
                name: "jsonOutput",
                type: .boolean,
                description: "Output in JSON format",
                required: false
            )
        ],
        examples: [],
        agentGuidance: ""
    )
}
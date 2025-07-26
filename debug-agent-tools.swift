#!/usr/bin/env swift

import Foundation
import PeekabooCore

// Enable debug logging
if let logPath = ProcessInfo.processInfo.environment["PEEKABOO_LOG_PATH"] {
    print("Logging to: \(logPath)")
}

// Check OpenAI API key
guard let apiKey = ProcessInfo.processInfo.environment["OPENAI_API_KEY"] else {
    print("ERROR: OPENAI_API_KEY not set")
    exit(1)
}

print("API Key found: \(apiKey.prefix(10))...")

// Initialize services
let services = PeekabooServices.shared

// Check if agent service is available
guard let agentService = services.agent as? PeekabooAgentService else {
    print("ERROR: Agent service not available")
    exit(1)
}

print("\n=== Creating Agent ===")

// Create agent and inspect tools
let agent = agentService.createAutomationAgent(modelName: "gpt-4o")
print("Agent created: \(agent.name)")
print("Tool count: \(agent.toolCount)")

// List all tools
print("\n=== Available Tools ===")
for tool in agent.tools {
    print("- \(tool.name): \(tool.description)")
}

// Check tool definitions
let toolDefs = agent.toolDefinitions
print("\n=== Tool Definitions (count: \(toolDefs.count)) ===")
for def in toolDefs {
    print("- \(def.function.name)")
    print("  Type: \(def.type)")
    print("  Parameters: \(def.function.parameters.properties.keys.joined(separator: ", "))")
}

// Try to encode tool definitions as JSON
print("\n=== Tool Definitions JSON ===")
do {
    let encoder = JSONEncoder()
    encoder.outputFormatting = .prettyPrinted
    let data = try encoder.encode(toolDefs)
    if let json = String(data: data, encoding: .utf8) {
        print(json.prefix(1000))
        print("...")
    }
} catch {
    print("ERROR encoding tools: \(error)")
}

// Create a simple task that requires tools
print("\n=== Testing Simple Tool Task ===")
let task = "Please list all running applications"

do {
    print("Executing task: \(task)")
    
    // Create a simple event delegate to see what's happening
    class DebugDelegate: AgentEventDelegate {
        func agentDidEmitEvent(_ event: AgentEvent) {
            switch event {
            case .started(let task):
                print("[EVENT] Started: \(task)")
            case .toolCallStarted(let name, let args):
                print("[EVENT] Tool call started: \(name)")
                print("        Args: \(args)")
            case .toolCallCompleted(let name, let result):
                print("[EVENT] Tool call completed: \(name)")
                print("        Result: \(result.prefix(200))...")
            case .assistantMessage(let content):
                print("[EVENT] Assistant: \(content)")
            case .error(let message):
                print("[EVENT] ERROR: \(message)")
            case .completed(let summary):
                print("[EVENT] Completed: \(summary)")
            }
        }
    }
    
    let delegate = DebugDelegate()
    let result = try await agentService.executeTask(
        task,
        modelName: "gpt-4o",
        eventDelegate: delegate
    )
    
    print("\n=== Result ===")
    print("Content: \(result.content)")
    print("Tool calls: \(result.toolCalls.count)")
    print("Session ID: \(result.sessionId)")
    
} catch {
    print("ERROR executing task: \(error)")
    if let nsError = error as NSError? {
        print("Domain: \(nsError.domain)")
        print("Code: \(nsError.code)")
        print("UserInfo: \(nsError.userInfo)")
    }
}
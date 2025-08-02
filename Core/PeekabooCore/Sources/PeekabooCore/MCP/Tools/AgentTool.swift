import Foundation
import MCP
import os.log

/// MCP tool for executing complex automation tasks using an AI agent
public struct AgentTool: MCPTool {
    private let logger = os.Logger(subsystem: "boo.peekaboo.mcp", category: "AgentTool")
    
    public let name = "agent"
    
    public var description: String {
        """
        Execute complex automation tasks using an AI agent powered by OpenAI's Assistants API.
        The agent can understand natural language instructions and break them down into specific 
        Peekaboo commands to accomplish complex workflows.

        Capabilities:
        - Natural Language Processing: Understands tasks described in plain English
        - Multi-step Automation: Breaks complex tasks into sequential steps
        - Visual Feedback: Can take screenshots to verify results
        - Context Awareness: Maintains session state across multiple actions
        - Error Recovery: Can adapt and retry when actions fail

        The agent has access to all Peekaboo automation tools including:
        - Screen capture and analysis
        - UI element interaction (click, type, scroll)
        - Application control (launch, quit, focus)
        - Window management (move, resize, close)
        - System interaction (hotkeys, shell commands)

        Example tasks:
        - "Open Safari and navigate to apple.com"
        - "Take a screenshot of the current window and save it to Desktop"
        - "Find the login button and click it, then type my credentials"
        - "Open TextEdit, write 'Hello World', and save the document"

        Requires OPENAI_API_KEY environment variable to be set.
        Peekaboo MCP 3.0.0-beta.2 using anthropic/claude-opus-4-20250514, ollama/llava:latest
        """
    }
    
    public var inputSchema: Value {
        SchemaBuilder.object(
            properties: [
                "task": SchemaBuilder.string(
                    description: "Natural language description of the task to perform (optional when listing sessions)"
                ),
                "model": SchemaBuilder.string(
                    description: "OpenAI model to use (e.g., gpt-4-turbo, gpt-4o). Call `list_models` first to see available presets and their descriptions. Choose based on task requirements (e.g., 'FastChat' for quick responses, 'DeepAnalysis' for complex reasoning). If omitted, auto-selects first mode-compatible preset."
                ),
                "quiet": SchemaBuilder.boolean(
                    description: "Quiet mode - only show final result",
                    default: false
                ),
                "verbose": SchemaBuilder.boolean(
                    description: "Enable verbose output with full JSON debug information",
                    default: false
                ),
                "dry_run": SchemaBuilder.boolean(
                    description: "Dry run - show planned steps without executing",
                    default: false
                ),
                "max_steps": SchemaBuilder.integer(
                    description: "Maximum number of steps the agent can take"
                ),
                "resume": SchemaBuilder.boolean(
                    description: "Resume the most recent session",
                    default: false
                ),
                "resumeSession": SchemaBuilder.string(
                    description: "Resume a specific session by ID"
                ),
                "listSessions": SchemaBuilder.boolean(
                    description: "List available sessions",
                    default: false
                ),
                "noCache": SchemaBuilder.boolean(
                    description: "Disable session caching (always create new session)",
                    default: false
                )
            ],
            required: []
        )
    }
    
    public init() {}
    
    @MainActor
    public func execute(arguments: ToolArguments) async throws -> ToolResponse {
        let input = try arguments.decode(AgentInput.self)
        
        logger.info("AgentTool executing with task: \(input.task ?? "none"), listSessions: \(input.listSessions)")
        
        // Handle listing sessions
        if input.listSessions {
            do {
                guard let agent = PeekabooServices.shared.agent as? PeekabooAgentService else {
                    return ToolResponse.error("Agent service not available")
                }
                let sessions = try await agent.listSessions()
                let sessionDescriptions = sessions.map { session in
                    let dateFormatter = DateFormatter()
                    dateFormatter.dateStyle = .medium
                    dateFormatter.timeStyle = .short
                    
                    return "ID: \(session.id)\nCreated: \(dateFormatter.string(from: session.createdAt))\nUpdated: \(dateFormatter.string(from: session.lastModified))\nMessage Count: \(session.messageCount)"
                }.joined(separator: "\n---\n")
                
                let sessionsArray = sessions.map { session in
                    let dateFormatter = ISO8601DateFormatter()
                    return Value.object([
                        "id": .string(session.id),
                        "createdAt": .string(dateFormatter.string(from: session.createdAt)),
                        "updatedAt": .string(dateFormatter.string(from: session.lastModified)),
                        "messageCount": .string(String(session.messageCount))
                    ])
                }
                
                let meta = Value.object([
                    "sessionCount": .string(String(sessions.count)),
                    "sessions": .array(sessionsArray)
                ])
                
                return ToolResponse.text(
                    "Available Sessions:\n\n\(sessionDescriptions)",
                    meta: meta
                )
            } catch {
                logger.error("Failed to list sessions: \(error.localizedDescription)")
                return ToolResponse.error("Failed to list sessions: \(error.localizedDescription)")
            }
        }
        
        // Require task for execution
        guard let task = input.task else {
            return ToolResponse.error("Missing required parameter: task")
        }
        
        do {
            guard let agent = PeekabooServices.shared.agent as? PeekabooAgentService else {
                return ToolResponse.error("Agent service not available")
            }
            
            let result: AgentExecutionResult
            
            // Handle resume scenarios
            if let resumeSessionId = input.resumeSession {
                // Resume specific session
                result = try await agent.resumeSession(
                    sessionId: resumeSessionId,
                    modelName: input.model ?? "claude-opus-4-20250514"
                )
            } else if input.resume {
                // Resume most recent session - get latest session and resume it
                let sessions = try await agent.listSessions()
                guard let latestSession = sessions.first else {
                    return ToolResponse.error("No sessions available to resume")
                }
                
                result = try await agent.resumeSession(
                    sessionId: latestSession.id,
                    modelName: input.model ?? "claude-opus-4-20250514"
                )
            } else {
                // Execute new task
                if input.dryRun {
                    // Use the dryRun version
                    result = try await agent.executeTask(
                        task,
                        dryRun: true,
                        eventDelegate: nil
                    )
                } else {
                    // Use the full-featured version with session and model
                    let sessionId = input.noCache ? nil : UUID().uuidString
                    result = try await agent.executeTask(
                        task,
                        sessionId: sessionId,
                        modelName: input.model ?? "claude-opus-4-20250514",
                        eventDelegate: nil
                    )
                }
            }
            
            // Format response based on verbosity level
            if input.quiet {
                return ToolResponse.text(result.content)
            } else if input.verbose {
                var metadata: [String: Value] = [:]
                if let sessionId = result.sessionId {
                    metadata["sessionId"] = .string(sessionId)
                }
                metadata["toolCallCount"] = .int(result.metadata.toolCallCount)
                metadata["modelName"] = .string(result.metadata.modelName)
                
                if let usage = result.usage {
                    metadata["usage"] = .object([
                        "promptTokens": .string(String(usage.promptTokens ?? 0)),
                        "completionTokens": .string(String(usage.completionTokens ?? 0)),
                        "totalTokens": .string(String(usage.totalTokens ?? 0))
                    ])
                }
                
                return ToolResponse.text(
                    result.content,
                    meta: .object(metadata)
                )
            } else {
                // Default output format
                var output = result.content
                
                if let sessionId = result.sessionId {
                    output += "\n🆔 Session: \(sessionId)"
                }
                
                if let usage = result.usage {
                    output += "\n📊 Tokens: \(usage.promptTokens ?? 0) in, \(usage.completionTokens ?? 0) out"
                }
                
                // Add more details if needed
                
                var meta: [String: Value] = [:]
                if let sessionId = result.sessionId {
                    meta["sessionId"] = .string(sessionId)
                }
                
                return ToolResponse.text(
                    output,
                    meta: meta.isEmpty ? nil : .object(meta)
                )
            }
            
        } catch {
            logger.error("Agent execution failed: \(error.localizedDescription)")
            return ToolResponse.error("Agent execution failed: \(error.localizedDescription)")
        }
    }
}

// MARK: - Supporting Types

struct AgentInput: Codable {
    let task: String?
    let model: String?
    let quiet: Bool
    let verbose: Bool
    let dryRun: Bool
    let maxSteps: Int?
    let resume: Bool
    let resumeSession: String?
    let listSessions: Bool
    let noCache: Bool
    
    enum CodingKeys: String, CodingKey {
        case task, model, quiet, verbose, resume, noCache
        case dryRun = "dry_run"
        case maxSteps = "max_steps"
        case resumeSession
        case listSessions
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        task = try container.decodeIfPresent(String.self, forKey: .task)
        model = try container.decodeIfPresent(String.self, forKey: .model)
        quiet = try container.decodeIfPresent(Bool.self, forKey: .quiet) ?? false
        verbose = try container.decodeIfPresent(Bool.self, forKey: .verbose) ?? false
        dryRun = try container.decodeIfPresent(Bool.self, forKey: .dryRun) ?? false
        maxSteps = try container.decodeIfPresent(Int.self, forKey: .maxSteps)
        resume = try container.decodeIfPresent(Bool.self, forKey: .resume) ?? false
        resumeSession = try container.decodeIfPresent(String.self, forKey: .resumeSession)
        listSessions = try container.decodeIfPresent(Bool.self, forKey: .listSessions) ?? false
        noCache = try container.decodeIfPresent(Bool.self, forKey: .noCache) ?? false
    }
}
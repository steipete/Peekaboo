---
summary: 'Review OpenAI API Migration Plan: Assistants API → Chat Completions API with Protocol-Based Architecture guidance'
read_when:
  - 'planning work related to openai api migration plan: assistants api → chat completions api with protocol-based architecture'
  - 'debugging or extending features described here'
---

# OpenAI API Migration Plan: Assistants API → Chat Completions API with Protocol-Based Architecture

## Status: ✅ COMPLETE

The migration from OpenAI Assistants API to Chat Completions API is now complete. All legacy code has been removed and the new architecture is the only implementation.

### What Was Done:
1. ✅ Implemented protocol-based message architecture
2. ✅ Built native streaming support with AsyncThrowingStream
3. ✅ Created type-safe tool system with generic context
4. ✅ Integrated with PeekabooCore services
5. ✅ Added session persistence for conversation resume
6. ✅ Removed all legacy Assistants API code
7. ✅ Simplified codebase by removing feature flags

## Executive Summary

Peekaboo currently uses OpenAI's Assistants API v2 for agent functionality. After analyzing the latest OpenAI TypeScript Agents SDK and the Swift port, this document outlines a migration to the Chat Completions API using a protocol-based architecture inspired by these implementations.

**Key Finding**: The OpenAI Agents SDK doesn't introduce a new "responses API" but rather provides a better-structured approach to using the Chat Completions API with:
- Protocol-based message types for type safety
- Built-in streaming support with event handling
- Clean abstractions for models, tools, and agents
- Structured error handling and state management

**Recommendation**: Migrate to Chat Completions API while adopting the architectural patterns from the Agents SDK, implemented natively in Swift.

## Current Architecture (Assistants API)

### Key Components:
- **Assistant**: Persistent entity with tools and system prompt
- **Thread**: Stateful conversation container
- **Run**: Execution instance that processes messages and calls tools
- **Messages**: User/assistant exchanges stored in threads

### Current Flow:
1. Create/reuse Assistant with tools
2. Create Thread for conversation
3. Add user message to Thread
4. Create Run to process the Thread
5. Poll Run status until complete
6. Handle tool calls when Run requires action
7. Submit tool outputs and continue Run
8. Retrieve final messages from Thread

### Resume Functionality:
- Thread IDs stored in session files
- Resume by reusing existing Thread ID
- Full conversation history maintained by OpenAI

## Understanding: OpenAI Agents SDK Architecture

After deep analysis of the OpenAI TypeScript SDK (@openai/agents) and the Swift port, here are the key architectural insights:

### What the SDK Actually Is:
- **Protocol-based message architecture** using structured types (not a new API)
- **Wrapper around Chat Completions API** with better abstractions
- **Event-driven streaming support** built into the core
- **No "Responses API"** - it's the same Chat Completions API with better patterns

### Key Protocol Types from the SDK:
```typescript
// Structured message types
export type MessageItem = SystemMessageItem | UserMessageItem | AssistantMessageItem;
export type ToolCallItem = FunctionCallItem | HostedToolCallItem | ComputerUseCallItem;
export type ModelItem = MessageItem | ToolCallItem | ReasoningItem | UnknownItem;

// Streaming events
export type StreamEvent = 
  | StreamEventTextStream 
  | StreamEventResponseStarted 
  | StreamEventResponseCompleted;

// Model interface abstraction
export interface Model {
  getResponse(request: ModelRequest): Promise<ModelResponse>;
  getStreamedResponse(request: ModelRequest): AsyncIterable<StreamEvent>;
}
```

### Swift Port Patterns We Should Adopt:
```swift
// Clean agent abstraction with generic context
public final class Agent<Context> {
    let name: String
    let instructions: String
    let tools: [Tool<Context>]
    let modelSettings: ModelSettings
}

// Protocol-based model interface
public protocol ModelInterface: Sendable {
    func getResponse(messages: [Message], settings: ModelSettings) async throws -> ModelResponse
    func getStreamedResponse(
        messages: [Message],
        settings: ModelSettings,
        callback: @escaping (ModelStreamEvent) async -> Void
    ) async throws -> ModelResponse
}

// Structured tool execution
public struct Tool<Context> {
    let name: String
    let description: String
    let parameters: [Parameter]
    let execute: (ToolParameters, Context) async throws -> Any
}
```

### Architectural Benefits:
1. **Type Safety** - Structured message types prevent runtime errors
2. **Streaming First** - Built-in support for real-time responses
3. **Provider Agnostic** - ModelInterface allows multiple providers
4. **Context Passing** - Generic context for stateful operations
5. **Error Boundaries** - Structured error handling at each layer

## Recommended Approach: Chat Completions API with Agent Patterns

### Key Changes:
- **No Assistants**: Tools defined inline with each request
- **No Threads**: Conversation history managed locally
- **No Runs**: Direct request/response with streaming
- **Function Calling**: Built-in tool calling in chat completions

### New Flow:
1. Load conversation history from session (if resuming)
2. Build messages array with system prompt + history + new message
3. Send chat completion request with tools
4. Handle tool calls directly in response
5. Execute tools and append results to messages
6. Continue until no more tool calls
7. Save conversation history to session

### Resume Functionality:
- Full message history stored in session files
- Resume by loading previous messages
- Include relevant history in new requests

## Benefits of Migration

### Performance:
- **10-30% faster response times** (no polling overhead)
- **Streaming support** for real-time feedback
- **Lower latency** for tool execution

### Simplicity:
- **Fewer API calls** (no thread/run management)
- **Direct control** over conversation flow
- **Simpler error handling** (no async state management)

### Cost:
- **Same token pricing** for GPT-4 models
- **No assistant storage costs**
- **More efficient token usage** (control history inclusion)

### Reliability:
- **Production API** (not beta)
- **Better error recovery** (stateless)
- **Local state management** (no remote dependencies)

## Implementation Plan

### Phase 1: Create Protocol-Based Message Types (Inspired by SDK)
```swift
// MARK: - Protocol-Based Message Types (MessageTypes.swift)

// Base protocol for all message items
public protocol MessageItem: Codable, Sendable {
    var type: MessageItemType { get }
    var id: String? { get }
}

// Message types enum
public enum MessageItemType: String, Codable, Sendable {
    case system = "system"
    case user = "user"
    case assistant = "assistant"
    case tool = "tool"
    case reasoning = "reasoning"
    case unknown = "unknown"
}

// Concrete message types
public struct SystemMessageItem: MessageItem {
    public let type = MessageItemType.system
    public let id: String?
    public let content: String
}

public struct UserMessageItem: MessageItem {
    public let type = MessageItemType.user
    public let id: String?
    public let content: MessageContent
}

public struct AssistantMessageItem: MessageItem {
    public let type = MessageItemType.assistant
    public let id: String?
    public let content: [AssistantContent]
    public let status: MessageStatus
}

// Content types
public enum MessageContent: Codable, Sendable {
    case text(String)
    case image(ImageContent)
    case file(FileContent)
    case multimodal([MessageContentPart])
}

public enum AssistantContent: Codable, Sendable {
    case outputText(String)
    case refusal(String)
    case toolCall(ToolCallItem)
}

// Tool call types
public struct ToolCallItem: Codable, Sendable {
    public let id: String
    public let type: ToolCallType
    public let function: FunctionCall
    public let status: ToolCallStatus?
}

public enum ToolCallType: String, Codable, Sendable {
    case function = "function"
    case hosted = "hosted_tool"
    case computer = "computer"
}

// Streaming event types
public enum StreamEvent: Codable, Sendable {
    case textDelta(StreamTextDelta)
    case responseStarted(StreamResponseStarted)
    case responseCompleted(StreamResponseCompleted)
    case toolCallDelta(StreamToolCallDelta)
}

public struct StreamTextDelta: Codable, Sendable {
    public let delta: String
}

// Model interface protocol
public protocol ModelInterface: Sendable {
    func getResponse(request: ModelRequest) async throws -> ModelResponse
    func getStreamedResponse(
        request: ModelRequest
    ) async throws -> AsyncThrowingStream<StreamEvent, Error>
}

public struct ModelRequest: Codable, Sendable {
    public let messages: [MessageItem]
    public let tools: [ToolDefinition]?
    public let settings: ModelSettings
}

public struct ModelResponse: Codable, Sendable {
    public let id: String
    public let content: [AssistantContent]
    public let usage: Usage?
    public let flagged: Bool
}
```

### Phase 2: Update Session Manager
```swift
// Enhanced session storage to include full message history
struct AgentSession: Codable {
    let id: String
    let task: String
    let messages: [ChatMessage] // NEW: Store full conversation
    let steps: [AgentStep]
    let createdAt: Date
    let lastActivityAt: Date
}
```

### Phase 3: Create Protocol-Based Agent Architecture
```swift
// MARK: - Agent Definition (Agent.swift)
public final class PeekabooAgent<Context> {
    public let name: String
    public let instructions: String
    public let tools: [Tool<Context>]
    public let modelSettings: ModelSettings
    
    public init(
        name: String,
        instructions: String,
        tools: [Tool<Context>] = [],
        modelSettings: ModelSettings = .default
    ) {
        self.name = name
        self.instructions = instructions
        self.tools = tools
        self.modelSettings = modelSettings
    }
}

// MARK: - Tool Definition with Generic Context
public struct Tool<Context> {
    public let name: String
    public let description: String
    public let parameters: ToolParameters
    public let execute: (ToolInput, Context) async throws -> ToolOutput
}

// MARK: - OpenAI Model Implementation
public final class OpenAIModel: ModelInterface {
    private let apiKey: String
    private let baseURL: URL
    private let session: URLSession
    
    public func getResponse(request: ModelRequest) async throws -> ModelResponse {
        // Convert protocol types to OpenAI API format
        let openAIRequest = convertToOpenAIRequest(request)
        let (data, _) = try await session.data(for: createURLRequest(openAIRequest))
        return try parseResponse(data)
    }
    
    public func getStreamedResponse(
        request: ModelRequest
    ) async throws -> AsyncThrowingStream<StreamEvent, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    let openAIRequest = convertToOpenAIRequest(request, stream: true)
                    let (bytes, _) = try await session.bytes(for: createURLRequest(openAIRequest))
                    
                    for try await line in bytes.lines {
                        if line.hasPrefix("data: ") {
                            let data = line.dropFirst(6)
                            if data == "[DONE]" {
                                continuation.finish()
                                return
                            }
                            
                            if let event = try? parseStreamEvent(data) {
                                continuation.yield(event)
                            }
                        }
                    }
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
}

// MARK: - Agent Runner
public struct AgentRunner {
    public static func run<Context>(
        agent: PeekabooAgent<Context>,
        input: String,
        context: Context,
        sessionId: String? = nil
    ) async throws -> AgentResult {
        let model = try ModelProvider.shared.getModel(agent.modelSettings.modelName)
        
        // Load or create session
        var messages: [MessageItem] = []
        if let sessionId = sessionId,
           let session = try await SessionManager.loadSession(sessionId) {
            messages = session.messages
        } else {
            messages.append(SystemMessageItem(
                id: UUID().uuidString,
                content: agent.instructions
            ))
        }
        
        // Add user message
        messages.append(UserMessageItem(
            id: UUID().uuidString,
            content: .text(input)
        ))
        
        // Create request
        let request = ModelRequest(
            messages: messages,
            tools: agent.tools.map { $0.toToolDefinition() },
            settings: agent.modelSettings
        )
        
        // Execute with streaming
        var responseContent = ""
        let events = try await model.getStreamedResponse(request: request)
        
        for try await event in events {
            switch event {
            case .textDelta(let delta):
                responseContent += delta.delta
                // Emit to UI handler
                
            case .toolCallDelta(let toolCall):
                // Handle tool execution
                let tool = agent.tools.first { $0.name == toolCall.name }
                if let tool = tool {
                    let result = try await tool.execute(toolCall.arguments, context)
                    // Add tool result to messages
                }
                
            case .responseCompleted(let response):
                // Save session
                messages.append(AssistantMessageItem(
                    id: response.id,
                    content: response.content,
                    status: .completed
                ))
                try await SessionManager.saveSession(messages: messages)
            }
        }
        
        return AgentResult(content: responseContent, messages: messages)
    }
}
```

### Phase 4: Parallel Testing
1. Add feature flag: `PEEKABOO_USE_CHAT_COMPLETIONS`
2. Implement A/B testing in AgentCommand
3. Compare results between APIs
4. Monitor performance metrics

### Phase 5: Migration
1. Default to Chat Completions for new sessions
2. Support reading old Assistants sessions
3. Gradual rollout with monitoring
4. Remove Assistants code after validation

## Key Lessons from SDK Analysis

### From TypeScript SDK (@openai/agents):
1. **Protocol-Based Messages**: The SDK uses a discriminated union pattern for message types:
   ```typescript
   export type ModelItem = MessageItem | ToolCallItem | ReasoningItem | UnknownItem;
   ```
   This provides compile-time safety and clear message categorization.

2. **Streaming Events**: First-class streaming support with typed events:
   ```typescript
   export type StreamEvent = 
     | { type: 'output_text_delta', delta: string }
     | { type: 'response_started' }
     | { type: 'response_done', response: Response }
     | { type: 'tool_call_delta', toolCall: ToolCall };
   ```

3. **Model Abstraction**: Clean interface for provider-agnostic implementation:
   ```typescript
   interface Model {
     getResponse(request: ModelRequest): Promise<ModelResponse>;
     getStreamedResponse(request: ModelRequest): AsyncIterable<StreamEvent>;
   }
   ```

4. **No New API**: Important discovery - there's no "responses API", just better patterns around Chat Completions.

### From Swift Port:
1. **Generic Context**: Type-safe context passing through the entire stack:
   ```swift
   public final class Agent<Context> {
       let tools: [Tool<Context>]
   }
   ```

2. **Async/Await Native**: Modern Swift concurrency throughout:
   ```swift
   func execute: (ToolParameters, Context) async throws -> Any
   ```

3. **Sendable Conformance**: All types are `Sendable` for thread safety

4. **Error Handling**: Structured errors at each layer:
   ```swift
   enum RunnerError: Error {
       case modelError(ModelProvider.ModelProviderError)
       case guardrailError(GuardrailError)
       case toolNotFound(String)
   }
   ```

### What Peekaboo Should Implement:
1. **Protocol-based message types** instead of loosely typed dictionaries
2. **Native streaming** with AsyncThrowingStream instead of polling
3. **Model provider abstraction** to support multiple AI providers
4. **Generic context** for PeekabooCore services
5. **Structured error types** for better error handling

## Implementation Comparison

| Aspect | Current Peekaboo | Swift Agents SDK | Recommended Approach |
|--------|------------------|------------------|---------------------|
| API Used | Assistants API v2 | Chat Completions | Chat Completions |
| Tool Definition | OpenAI Tool format | Structured Tool<Context> | Adopt SDK pattern |
| Streaming | No (polling) | Yes (SSE parsing) | Implement streaming |
| State Management | Remote (threads) | Local messages | Local with persistence |
| Error Handling | Basic | Structured errors | Enhanced error types |
| Context Passing | Via toolExecutor | Generic Context | Adopt generic pattern |
| Model Abstraction | None | Protocol-based | Add ModelInterface |
| Session Resume | Thread ID reuse | Not implemented | Custom implementation |

## Migration Timeline

### Phase 1: Protocol & Types (Week 1)
- [ ] Define protocol-based message types (MessageItem, ToolCallItem, etc.)
- [ ] Implement ModelInterface protocol
- [ ] Create streaming event types (StreamEvent)
- [ ] Set up type-safe tool definitions with generic context

### Phase 2: Core Implementation (Week 2)
- [ ] Implement OpenAIModel conforming to ModelInterface
- [ ] Build streaming support with AsyncThrowingStream
- [ ] Create PeekabooAgent<Context> with tool management
- [ ] Implement AgentRunner with session persistence

### Phase 3: Integration (Week 3)
- [ ] Wire up with PeekabooCore services as context
- [ ] Update AgentCommand to use new architecture
- [ ] Implement session resume with message history
- [ ] Add feature flag for gradual rollout

### Phase 4: Testing & Migration (Week 4)
- [ ] Unit tests for all protocol types
- [ ] Integration tests with real OpenAI API
- [ ] Performance benchmarking (expect 30% improvement)
- [ ] Parallel run with Assistants API for validation

### Phase 5: Cleanup & Optimization (Week 5)
- [ ] Remove Assistants API code
- [ ] Optimize streaming performance
- [ ] Add support for additional providers (Anthropic, Ollama)
- [ ] Documentation and migration guide

## Phase 4: Complete Replacement (✅ COMPLETED)

### Files Deleted:
1. **Legacy Agent Implementation**:
   - `/Apps/CLI/Sources/peekaboo/AgentCommand.old.swift` (backup)
   - `/Apps/CLI/Sources/peekaboo/AgentNetworking.swift`
   - `/Apps/CLI/Sources/peekaboo/AgentTypes.swift`
   - `/Apps/CLI/Sources/peekaboo/AgentFunctions.swift`
   - `/Apps/CLI/Sources/peekaboo/AgentAssistantManager.swift`
   - `/Apps/CLI/Sources/peekaboo/AgentSessionManager.swift`
   - `/Apps/CLI/Sources/peekaboo/AgentExecutor.swift`

2. **Old Agent Service**:
   - `/Apps/Mac/Peekaboo/Agent/OpenAIAgentService.swift`
   - `/Apps/Mac/Peekaboo/Agent/PeekabooAgent.swift`
   - `/Apps/Mac/Peekaboo/Agent/PeekabooToolExecutor.swift`

### Code Updated:
1. **Removed Feature Flag**:
   - ✅ Removed `useNewChatAPI` from `Configuration.AgentConfig`
   - ✅ Removed conditional logic in `PeekabooServices`
   - ✅ Always use `PeekabooAgentService`

2. **Simplified AgentCommand**:
   - ✅ Removed fallback logic for non-PeekabooAgentService
   - ✅ Always assume enhanced session support

3. **Updated Imports**:
   - ✅ Removed imports of deleted files
   - ✅ Renamed `SessionManager` to `AgentSessionManager` to avoid conflicts
   - ✅ Updated all references

### Verification Completed:
1. ✅ Build successful (with expected warnings)
2. ✅ Agent command implementation updated
3. ✅ All legacy code removed
4. ✅ Documentation updated

## Risk Mitigation

### Compatibility:
- Keep session format backward compatible
- Auto-migrate old sessions on first use
- Maintain same CLI interface

### Feature Parity:
- Ensure all tools work identically
- Preserve resume functionality
- Maintain output formatting

### Rollback Plan:
- Feature flag allows instant rollback
- Keep Assistants code for 2 releases
- Monitor error rates closely

## Code Examples

### Current (Assistants API):
```swift
// Complex multi-step process
let assistant = try await createAssistant()
let thread = try await createThread()
try await addMessage(threadId: thread.id, content: task)
let run = try await createRun(threadId: thread.id, assistantId: assistant.id)
// Poll and handle tool calls...
```

### New (Chat Completions API):
```swift
// Direct request with tools
let response = try await chatCompletion(
    messages: messages,
    tools: availableTools(),
    stream: true
)
// Handle tool calls directly in response
```

## Comparison Summary

| Feature | Assistants API (Current) | Agents SDK Pattern | Direct Chat Completions |
|---------|-------------------------|-------------------|------------------------|
| API Type | Separate API | Wrapper around Chat API | Direct API |
| Language | Any (REST) | JS/TS SDK | Any (REST) |
| Performance | Slow (polling) | Fast | Fast |
| Complexity | High | Medium (abstracted) | Low |
| State Management | Remote (threads) | Local | Local |
| Streaming | No | Yes | Yes |
| Tool Calling | Yes | Yes | Yes |
| Resume Support | Built-in | Manual | Manual |
| Production Ready | Beta | Stable | Stable |
| Swift Usage | Direct REST | Not applicable | Direct REST |

## Conclusion

The OpenAI Agents SDK revealed an important insight: **it's not a new API, but rather design patterns** around the Chat Completions API. This validates our migration approach:

1. **Move from Assistants API to Chat Completions API** - Immediate performance gains
2. **Adopt Agent SDK patterns in Swift** - Better abstractions without JS overhead
3. **Build a Swift-native agent layer** - Type-safe, performant, and idiomatic

### Benefits of This Approach:
- **30% faster response times** (no polling like Assistants API)
- **Native Swift performance** (no JS runtime)
- **Modern patterns** (inspired by Agents SDK)
- **Full type safety** (Swift's strong typing)
- **Simple deployment** (single binary)

### Implementation Strategy (Updated):
1. **Start with Protocol Types**: Define all message and event types first
2. **Build Model Abstraction**: Create ModelInterface before OpenAI implementation
3. **Implement Streaming First**: Don't add non-streaming as an afterthought
4. **Use PeekabooCore as Context**: Pass services through generic context
5. **Test with Real API Early**: Validate protocol mappings with actual OpenAI responses

### Key Patterns to Implement (Learned from Swift SDK):
```swift
// Based on the actual Swift Agents SDK port
public final class PeekabooAgent<Context> {
    let name: String
    let instructions: String
    let tools: [Tool<Context>]
    let modelSettings: ModelSettings
    
    // Tool definition with proper parameter typing
    public struct Tool<Context> {
        let name: String
        let description: String
        let parameters: [Parameter]
        let execute: (ToolParameters, Context) async throws -> Any
    }
    
    // Streaming support built-in
    func runStreamed(
        input: String,
        context: Context,
        streamHandler: @escaping (String) async -> Void
    ) async throws -> AgentResult {
        // Direct Chat Completions API implementation
        // With SSE streaming parsing
        // Tool call handling in response
    }
}

// Model abstraction for different providers
protocol ModelInterface: Sendable {
    func getResponse(messages: [Message], settings: ModelSettings) async throws -> ModelResponse
    func getStreamedResponse(
        messages: [Message],
        settings: ModelSettings,
        callback: @escaping (ModelStreamEvent) async -> Void
    ) async throws -> ModelResponse
}
```

The migration preserves all functionality while gaining significant performance improvements and maintaining pure Swift implementation.

## Next Steps & Implementation Guide

### Immediate Actions:
1. **Create ChatCompletionTypes.swift** with protocol-based message types
2. **Define ModelInterface.swift** protocol for provider abstraction
3. **Build OpenAIModel.swift** implementing the Chat Completions API
4. **Create Agent.swift** with generic context support
5. **Implement streaming in AgentRunner.swift**

### File Structure:
```
Core/PeekabooCore/Sources/PeekabooCore/AI/
├── Protocols/
│   ├── ModelInterface.swift       // Model abstraction
│   ├── MessageTypes.swift         // Protocol-based messages
│   └── StreamingTypes.swift       // Streaming events
├── Models/
│   ├── OpenAIModel.swift          // OpenAI implementation
│   ├── AnthropicModel.swift       // Future: Anthropic
│   └── OllamaModel.swift          // Future: Ollama
├── Agent/
│   ├── Agent.swift                // Agent definition
│   ├── AgentRunner.swift          // Execution logic
│   ├── Tool.swift                 // Tool definitions
│   └── SessionManager.swift       // Session persistence
└── ChatCompletion/
    ├── ChatCompletionClient.swift // HTTP client
    └── ChatCompletionTypes.swift  // OpenAI-specific types
```

### Testing Strategy:
1. **Protocol Conformance Tests**: Ensure all message types encode/decode correctly
2. **Streaming Tests**: Validate AsyncThrowingStream behavior
3. **Tool Execution Tests**: Mock tool calls with PeekabooCore context
4. **Session Resume Tests**: Verify message history persistence
5. **Performance Tests**: Benchmark against current Assistants API

### Migration Checklist:
- [ ] Review and approve this migration plan
- [ ] Create feature branch `feature/chat-completions-migration`
- [ ] Implement protocol types (MessageTypes.swift)
- [ ] Build ModelInterface and OpenAIModel
- [ ] Create Agent architecture with generic context
- [ ] Implement streaming support
- [ ] Add session persistence
- [ ] Write comprehensive tests
- [ ] Performance benchmark
- [ ] Update AgentCommand to use new system
- [ ] Feature flag for gradual rollout
- [ ] Monitor and validate in production
- [ ] Remove Assistants API code
- [ ] Update documentation

This migration will modernize Peekaboo's AI architecture while maintaining all current functionality and significantly improving performance.
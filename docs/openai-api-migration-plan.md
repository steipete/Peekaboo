# OpenAI API Migration Plan: Assistants API → Modern Alternatives

## Executive Summary

Peekaboo currently uses OpenAI's Assistants API v2 for agent functionality. This document evaluates two migration paths:
1. **Chat Completions API** - The traditional REST API with tool calling
2. **OpenAI Agents SDK** - A new TypeScript/JavaScript SDK that provides a higher-level abstraction

After analysis, the **Chat Completions API remains the better choice for Peekaboo** due to native Swift support, better performance, and alignment with the existing architecture.

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

## Understanding: OpenAI Agents SDK

The OpenAI Agents SDK (@openai/agents) is **not a new API** but rather a TypeScript/JavaScript SDK that wraps the Chat Completions API (and the newer Responses API). It provides high-level abstractions for building agents.

### What the SDK Actually Is:
- **A convenience wrapper** around Chat Completions/Responses API
- **TypeScript/JavaScript library** with nice abstractions
- **Uses the same underlying APIs** we'd use directly from Swift

### Key Patterns from the SDK We Can Adopt:
1. **Agent abstraction** - Encapsulate instructions, tools, and behavior
2. **Streaming with events** - Better UX with real-time updates
3. **Tool management** - Cleaner tool definition and execution
4. **State management** - Conversation history and session handling
5. **Error handling** - Structured error types for tool/guardrail failures

### Example SDK Usage:
```typescript
// The SDK provides nice abstractions...
const agent = new Agent({
  name: 'Assistant',
  instructions: 'You are a helpful assistant',
  tools: [getWeatherTool]
});

// ...but under the hood, it's just calling Chat Completions API
const result = await run(agent, 'What is the weather?');
```

### Why We Should Implement Similar Patterns in Swift:
1. **Native performance** - No JS runtime overhead
2. **Type safety** - Full Swift type checking
3. **Direct integration** - No language barriers
4. **Same capabilities** - We can implement all the same patterns
5. **Better for macOS** - Native Swift is ideal for system integration

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

### Phase 1: Create New Chat Completions Types
```swift
// New types needed in ChatCompletionTypes.swift
public struct ChatCompletionRequest: Codable, Sendable {
    public let model: String
    public let messages: [ChatMessage]
    public let tools: [Tool]?
    public let toolChoice: ToolChoice?
    public let temperature: Double?
    public let maxTokens: Int?
    public let stream: Bool?
}

public struct ChatMessage: Codable, Sendable {
    public let role: MessageRole
    public let content: String?
    public let toolCalls: [ChatToolCall]?
    public let toolCallId: String? // For tool responses
}

public enum MessageRole: String, Codable, Sendable {
    case system, user, assistant, tool
}

public struct ChatCompletionResponse: Codable, Sendable {
    public let id: String
    public let choices: [Choice]
    public let usage: Usage?
    
    public struct Choice: Codable, Sendable {
        public let message: ChatMessage
        public let finishReason: String?
    }
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

### Phase 3: Create ChatCompletionsAgent
```swift
// New implementation alongside existing OpenAIAgent
public actor ChatCompletionsAgent {
    func executeTask(_ task: String, sessionId: String?) async throws -> AgentResult {
        // Load session if resuming
        let session = sessionId != nil ? await loadSession(sessionId!) : nil
        
        // Build messages array
        var messages = session?.messages ?? [systemMessage()]
        messages.append(ChatMessage(role: "user", content: task))
        
        // Execute with tool calling loop
        let result = try await executeWithTools(messages: &messages)
        
        // Save session
        await saveSession(messages: messages)
        
        return result
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

## Migration Timeline

### Week 1-2: Implementation
- [ ] Create new types and ChatCompletionsAgent
- [ ] Update session storage for messages
- [ ] Implement streaming support

### Week 3: Testing
- [ ] Unit tests for new implementation
- [ ] Integration tests with real OpenAI API
- [ ] Performance benchmarking

### Week 4: Rollout
- [ ] Feature flag deployment
- [ ] Monitor error rates and performance
- [ ] Gradual increase in usage

### Week 5: Cleanup
- [ ] Remove Assistants API code
- [ ] Update documentation
- [ ] Final performance validation

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

### Implementation Strategy:
1. **Phase 1**: Direct migration to Chat Completions API
2. **Phase 2**: Add Agent abstraction layer in Swift
3. **Phase 3**: Implement streaming and event handling
4. **Phase 4**: Enhanced error handling and state management

### Key Patterns to Implement:
```swift
// Swift version inspired by Agents SDK patterns
public class SwiftAgent {
    let name: String
    let instructions: String
    let tools: [Tool]
    
    func run(_ input: String, stream: Bool = false) async throws -> AgentResult {
        // Direct Chat Completions API call
        // With streaming support
        // And proper state management
    }
}
```

The migration preserves all functionality while gaining significant performance improvements and maintaining pure Swift implementation.
---
summary: 'Configure Peekaboo to use local Ollama models (llama3, llava, Ultrathink) and track the remaining implementation work.'
read_when:
  - 'running Peekaboo with local models'
  - 'debugging or extending the Ollama provider'
---

# Ollama Ultrathink Integration Plan for Peekaboo

## Overview

This document outlines the plan for completing Ollama support in Peekaboo and adding the Ultrathink model. Currently, Ollama has basic provider infrastructure but lacks full implementation, particularly for the agent command and streaming responses.

## Quick Start (Local Only)

For privacy-focused automation runs you can aim Peekaboo at a local Ollama daemon:

```bash
# Install and start Ollama
brew install ollama
ollama serve

# Grab recommended models
ollama pull llama3.3      # ✅ Supports tool calling
ollama pull llava:latest  # Vision-only (no tools)

# Point Peekaboo at the server
PEEKABOO_AI_PROVIDERS="ollama/llama3.3" peekaboo agent "Click the Submit button"
PEEKABOO_AI_PROVIDERS="ollama/llava:latest" peekaboo image --analyze "Describe this UI"

# Persist in config (optional)
peekaboo config set aiProviders.providers "ollama/llama3.3"
peekaboo config set aiProviders.ollamaBaseUrl "http://localhost:11434"
```

### Recommended Models

- **Automation (tool calling):** `llama3.3` (best) or `llama3.2`. These understand tool metadata and can drive GUI automation.
- **Vision-only:** `llava:latest`, `bakllava` – use for `image --analyze`, but they cannot execute tools.
- **Ultrathink / other heavy models:** follow the implementation plan below to ensure streaming + tool calling support before enabling by default.

**Environment variables**

- `PEEKABOO_AI_PROVIDERS="ollama/<model>`" – enables Ollama providers globally.
- `PEEKABOO_OLLAMA_BASE_URL` – override the default `http://localhost:11434` when your daemon runs on another host.

> Note: The CLI only accepts models that advertise tool support when you run `peekaboo agent`. If a model is vision-only you can still use `peekaboo image --analyze` via the same provider string.

## Current State

### Existing Implementation
- ✅ `OllamaProvider.swift` with basic structure
- ✅ Server availability checks
- ✅ Model listing capability
- ❌ Image analysis not implemented (throws error)
- ❌ No agent/chat support
- ❌ No streaming support
- ❌ No tool calling support

### Model Support
Currently supports models like `llava:latest` for image analysis (though not implemented). Need to add support for text-generation models like Ultrathink.

## Ollama API Overview

Ollama provides a REST API with two main approaches:
- **Native API**: Base URL `http://localhost:11434`
  - Chat endpoint: `/api/chat` (primary for conversations)
  - Generate endpoint: `/api/generate` (for simple completions)
  - Streaming: JSON objects (not SSE), streaming enabled by default
  - Tool calling: Supported via `tools` parameter (model-dependent)
- **OpenAI Compatibility**: `/v1/chat/completions`
  - Full OpenAI Chat Completions API compatibility
  - Easier integration with existing OpenAI tooling

## Implementation Plan

### Phase 1: Complete Core Provider (1-2 days)

1. **Move OllamaProvider to Core**
   - Move from `Apps/CLI/Sources/peekaboo/AIProviders/` to `Core/PeekabooCore/Sources/PeekabooCore/AI/Ollama/`
   - Align with OpenAI/Anthropic structure

2. **Create Ollama Types**
   - Location: `Core/PeekabooCore/Sources/PeekabooCore/AI/Ollama/OllamaTypes.swift`
   ```swift
   struct OllamaChatRequest
   struct OllamaChatResponse
   struct OllamaMessage
   struct OllamaToolCall
   struct OllamaStreamChunk
   ```

3. **Implement Basic Chat**
   - Update `OllamaProvider` to implement full `AIProvider` protocol
   - Add chat completion support
   - Handle authentication (none required for local)

### Phase 2: Create OllamaModel (2-3 days)

1. **Create OllamaModel.swift**
   - Location: `Core/PeekabooCore/Sources/PeekabooCore/AI/Models/OllamaModel.swift`
   - Implement `ModelInterface` protocol
   - Message conversion logic
   - System prompt handling

2. **Message Format Conversion**
   ```swift
   // Peekaboo → Ollama
   SystemMessageItem → messages[].content with role "system"
   UserMessageItem → messages[].content with role "user"
   AssistantMessageItem → messages[].content with role "assistant"
   ToolMessageItem → Not directly supported, convert to user message
   ```

3. **Image Support**
   - Convert base64 images to Ollama format
   - Support multimodal models (llava, bakllava)
   - Handle text-only models gracefully

### Phase 3: Streaming Implementation (1-2 days)

**Critical**: Ollama uses newline-delimited JSON streaming, NOT Server-Sent Events (SSE)!

1. **JSON Streaming Parser**
   - Parse newline-delimited JSON objects
   - Handle partial chunks and buffering
   - Robust error recovery for malformed JSON
   - Convert to Peekaboo's `StreamEvent` types

2. **Stream Integration**
   ```swift
   func getStreamedResponse(messages: [MessageItem], tools: [ToolDefinition]?) -> AsyncThrowingStream<StreamEvent, Error> {
       AsyncThrowingStream { continuation in
           Task {
               do {
                   let url = baseURL.appendingPathComponent("api/chat")
                   var request = URLRequest(url: url)
                   request.httpMethod = "POST"
                   request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                   
                   let body = OllamaChatRequest(
                       model: model,
                       messages: convertMessages(messages),
                       tools: convertTools(tools),
                       stream: true
                   )
                   request.httpBody = try JSONEncoder().encode(body)
                   
                   let (bytes, _) = try await URLSession.shared.bytes(for: request)
                   let parser = OllamaStreamParser()
                   
                   for try await line in bytes.lines {
                       let events = parser.parse(data: line.data(using: .utf8)!)
                       for event in events {
                           continuation.yield(mapToStreamEvent(event))
                       }
                   }
                   
                   continuation.finish()
               } catch {
                   continuation.finish(throwing: error)
               }
           }
       }
   }
   ```

3. **Event Mapping**
   ```swift
   // Ollama streaming events → Peekaboo StreamEvents
   - message.content deltas → .contentDelta(String)
   - tool_calls → .toolCall(ToolCall)
   - done: true → .finished
   - error responses → .error(Error)
   ```

4. **Streaming States**
   - Content streaming (text generation)
   - Tool call streaming (function invocations)
   - Mixed content/tool streaming
   - Completion with statistics

### Phase 4: Tool Calling Support (2 days)

**Update (2025)**: Ollama now has official tool calling support with streaming capabilities!

1. **Tool Definition Conversion**
   - Convert `ToolDefinition` to Ollama function format
   - Handle parameter schemas
   - Support required/optional parameters
   - Use improved parser that understands tool call structure

2. **Tool Execution Flow**
   - Parse tool calls from responses
   - Format tool results
   - Handle multi-turn conversations
   - Support streaming with tool calls

3. **Supported Models**
   Models with verified tool calling support (as of 2025):
   - **Llama 3.1** (8b, 70b, 405b) - Primary recommendation
   - **Mistral Nemo** - Reliable for tools
   - **Firefunction v2** - Optimized for function calling
   - **Command-R+** - Good tool support
   - **Qwen models** - Varying support by version
   - **DeepSeek-R1** - New reasoning model with tool support
   
   **Important**: Tool calling support is model-dependent. Not all Ollama models support tools. Always check model capabilities before assuming tool support.

4. **Implementation Tips**
   - Use context window of 32k+ for better tool calling performance
   - New streaming parser handles tool calls without blocking
   - Python library v0.4+ supports direct function passing

### Phase 5: Model Registration (1 day)

1. **Register Ollama Models**
   ```swift
   // In ModelProvider.swift
   registerOllamaModels()
   ```

2. **Model Definitions**
   ```swift
   // Text generation models with tool calling (verified 2025)
   - ollama/llama3.1:8b ✅ Tool calling
   - ollama/llama3.1:70b ✅ Tool calling
   - ollama/llama3.1:405b ✅ Tool calling
   - ollama/mistral-nemo ✅ Tool calling
   - ollama/firefunction-v2 ✅ Tool calling (optimized)
   - ollama/command-r-plus ✅ Tool calling
   - ollama/deepseek-r1 ✅ Tool calling (reasoning model)
   
   // Text generation models (limited/no tool support)
   - ollama/ultrathink ❓ TBD when released
   - ollama/llama3.2 ❌ No official tool support
   - ollama/qwen2.5 ⚠️ Variable by version
   - ollama/phi3 ❌ No tool calling
   - ollama/mistral:7b ❌ Use mistral-nemo for tools
   
   // Multimodal models (no tool support)
   - ollama/llava:latest ❌ Vision only
   - ollama/bakllava ❌ Vision only
   - ollama/llava-llama3 ❌ Vision only
   ```

3. **Dynamic Model Discovery**
   - Query `/api/tags` for available models
   - Cache model list
   - Refresh periodically

### Phase 6: Ultrathink-Specific Features (1-2 days)

1. **Model Characteristics**
   - Extended context window support
   - Reasoning traces (if supported)
   - Performance optimizations

2. **Special Parameters**
   ```swift
   struct UltrathinkOptions {
       var temperature: Double = 0.7
       var num_predict: Int = 4096
       var num_ctx: Int = 32768  // Extended context
       var reasoning_mode: String? = "detailed"
   }
   ```

3. **Reasoning Support**
   - Check if Ultrathink supports reasoning traces
   - Implement similar to GPT-5 reasoning summaries
   - Display thinking indicators

### Phase 7: Testing & Integration (2 days)

1. **Unit Tests**
   - Test message conversion
   - Mock Ollama responses
   - Error scenarios

2. **Integration Tests**
   - Test with local Ollama instance
   - Verify streaming
   - Tool calling scenarios

3. **Performance Testing**
   - Benchmark vs OpenAI/Anthropic
   - Memory usage with large contexts
   - Streaming latency

## Technical Implementation Details

### Streaming Parser Implementation

```swift
class OllamaStreamParser {
    private var buffer = ""
    
    func parse(data: Data) -> [OllamaStreamEvent] {
        guard let text = String(data: data, encoding: .utf8) else { return [] }
        buffer += text
        
        var events: [OllamaStreamEvent] = []
        let lines = buffer.split(separator: "\n", omittingEmptySubsequences: false)
        
        // Keep incomplete line in buffer
        if !buffer.hasSuffix("\n") && !lines.isEmpty {
            buffer = String(lines.last!)
            for line in lines.dropLast() {
                if let event = parseJSONLine(String(line)) {
                    events.append(event)
                }
            }
        } else {
            buffer = ""
            for line in lines where !line.isEmpty {
                if let event = parseJSONLine(String(line)) {
                    events.append(event)
                }
            }
        }
        
        return events
    }
    
    private func parseJSONLine(_ line: String) -> OllamaStreamEvent? {
        guard let data = line.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        
        // Parse based on content
        if json["done"] as? Bool == true {
            return .completed(stats: parseStats(json))
        } else if let message = json["message"] as? [String: Any] {
            if let content = message["content"] as? String, !content.isEmpty {
                return .contentDelta(content)
            }
            if let toolCalls = message["tool_calls"] as? [[String: Any]] {
                return .toolCall(parseToolCalls(toolCalls))
            }
        }
        
        return nil
    }
}
```

### API Endpoints

```swift
// Chat completion
POST /api/chat
{
  "model": "llama3.1",
  "messages": [
    {"role": "system", "content": "You are a helpful assistant"},
    {"role": "user", "content": "Hello"}
  ],
  "stream": true,
  "tools": [...],
  "options": {
    "temperature": 0.7,
    "num_predict": 4096,
    "num_ctx": 32768
  },
  "keep_alive": "5m"
}

// Model listing
GET /api/tags

// Model info
GET /api/show/{modelname}
```

### Streaming Format

```swift
// Standard content streaming (newline-delimited JSON)
{"model":"llama3.1","created_at":"2025-01-26T12:00:00Z","message":{"role":"assistant","content":"Hello"},"done":false}
{"model":"llama3.1","created_at":"2025-01-26T12:00:01Z","message":{"role":"assistant","content":" there"},"done":false}
{"model":"llama3.1","created_at":"2025-01-26T12:00:02Z","message":{"role":"assistant","content":"!"},"done":false}
{"model":"llama3.1","created_at":"2025-01-26T12:00:03Z","done":true,"done_reason":"stop","total_duration":1234567890,"load_duration":123456,"prompt_eval_count":10,"prompt_eval_duration":123456,"eval_count":3,"eval_duration":234567}

// Streaming with tool calls
{"model":"llama3.1","created_at":"2025-01-26T12:00:00Z","message":{"role":"assistant","content":""},"done":false}
{"model":"llama3.1","created_at":"2025-01-26T12:00:01Z","message":{"role":"assistant","content":"","tool_calls":[{"function":{"name":"get_weather","arguments":{"city":"Toronto"}}}]},"done":false}
{"model":"llama3.1","created_at":"2025-01-26T12:00:02Z","done":true,"done_reason":"stop","total_duration":987654321}

// Mixed content and tool streaming
{"model":"llama3.1","created_at":"2025-01-26T12:00:00Z","message":{"role":"assistant","content":"Let me check the weather"},"done":false}
{"model":"llama3.1","created_at":"2025-01-26T12:00:01Z","message":{"role":"assistant","content":" for you.","tool_calls":[{"function":{"name":"get_weather","arguments":{"city":"Toronto"}}}]},"done":false}
{"model":"llama3.1","created_at":"2025-01-26T12:00:02Z","done":true}
```

### Tool Calling Format

```swift
// Request with tools
{
  "model": "llama3.1",
  "messages": [{"role": "user", "content": "What's the weather in Toronto?"}],
  "tools": [{
    "type": "function",
    "function": {
      "name": "get_current_weather",
      "description": "Get the current weather for a city",
      "parameters": {
        "type": "object",
        "properties": {
          "city": {
            "type": "string",
            "description": "The name of the city"
          }
        },
        "required": ["city"]
      }
    }
  }],
  "stream": true
}

// Response with tool call
{
  "model": "llama3.1",
  "message": {
    "role": "assistant",
    "content": "",
    "tool_calls": [{
      "function": {
        "name": "get_current_weather",
        "arguments": {
          "city": "Toronto"
        }
      }
    }]
  }
}
```

### Error Handling

```swift
enum OllamaError: Error {
    case serverNotRunning
    case modelNotFound(String)
    case modelNotLoaded(String)
    case contextLengthExceeded
    case streamingError(String)
    case malformedJSON(String)
    case connectionLost
    case toolCallFailed(String)
}

// Streaming error scenarios
extension OllamaStreamParser {
    func handleStreamingErrors(_ error: Error) -> StreamEvent {
        switch error {
        case URLError.networkConnectionLost:
            return .error(OllamaError.connectionLost)
        case let DecodingError.dataCorrupted(context):
            return .error(OllamaError.malformedJSON(context.debugDescription))
        default:
            return .error(OllamaError.streamingError(error.localizedDescription))
        }
    }
}

// Error recovery strategies
class OllamaStreamHandler {
    func recoverFromError(_ error: OllamaError) async throws {
        switch error {
        case .serverNotRunning:
            throw error // Can't recover, user must start Ollama
        case .modelNotFound(let model):
            // Suggest pulling the model
            print("Model '\(model)' not found. Run: ollama pull \(model)")
            throw error
        case .connectionLost:
            // Retry with exponential backoff
            try await Task.sleep(nanoseconds: 1_000_000_000)
            // Retry logic here
        case .malformedJSON:
            // Continue parsing, skip malformed line
            break
        default:
            throw error
        }
    }
}
```

### Conversation Context and Session Management

**Important**: Ollama is stateless - it does NOT maintain conversation history between API calls. You must manage context yourself.

```swift
// Managing conversation history
class OllamaConversationManager {
    private var messages: [OllamaMessage] = []
    
    func addUserMessage(_ content: String) {
        messages.append(OllamaMessage(role: "user", content: content))
    }
    
    func addAssistantMessage(_ content: String) {
        messages.append(OllamaMessage(role: "assistant", content: content))
    }
    
    func addSystemMessage(_ content: String) {
        // System messages should typically be first
        messages.insert(OllamaMessage(role: "system", content: content), at: 0)
    }
    
    func getChatRequest(newMessage: String) -> OllamaChatRequest {
        addUserMessage(newMessage)
        
        return OllamaChatRequest(
            model: model,
            messages: messages,  // Send full history
            stream: true,
            options: ["num_ctx": 32768]  // Ensure large context window
        )
    }
    
    func trimHistory(maxMessages: Int = 50) {
        // Keep system message + recent messages
        if messages.count > maxMessages {
            let systemMessages = messages.filter { $0.role == "system" }
            let recentMessages = Array(messages.suffix(maxMessages - systemMessages.count))
            messages = systemMessages + recentMessages
        }
    }
}
```

#### Key Differences from Cloud Providers

1. **No Session IDs**: Unlike OpenAI/Anthropic, Ollama has no session management
2. **Manual History**: You must send the complete conversation history with each request
3. **Context Limits**: Be mindful of model context windows (varies by model)
4. **Memory Usage**: Larger contexts use more VRAM/RAM

#### Context Parameter (Deprecated)

The old `/api/generate` endpoint used a `context` parameter (array of tokens) to maintain state:
```swift
// OLD WAY - DEPRECATED
{
  "model": "llama2",
  "prompt": "continue our conversation",
  "context": [1, 2, 3, ...]  // Token array from previous response
}
```

**Use `/api/chat` with full message history instead** for better compatibility and clearer conversation management.

#### Best Practices

1. **Persistent Storage**: Store conversations in a database for multi-session support
2. **Context Pruning**: Implement sliding window or importance-based pruning for long conversations
3. **System Prompts**: Include system messages at the start of each conversation
4. **Error Recovery**: Save conversation state periodically to recover from crashes

```swift
// Example: Peekaboo integration
extension OllamaModel {
    func continueConversation(sessionId: String, newMessage: String) async throws -> String {
        // Load conversation from storage
        let history = try await loadConversationHistory(sessionId)
        
        // Add new message
        history.append(MessageItem.user(newMessage))
        
        // Send full history to Ollama
        let response = try await getResponse(messages: history, tools: nil)
        
        // Save updated conversation
        history.append(MessageItem.assistant(response))
        try await saveConversationHistory(sessionId, history)
        
        return response
    }
}
```

## Configuration

### User Setup
```bash
# Install Ollama
curl -fsSL https://ollama.com/install.sh | sh

# Pull Ultrathink model (when available)
ollama pull ultrathink

# Pull recommended models with tool support
ollama pull llama3.1  # Primary recommendation for tools
ollama pull mistral-nemo  # Good tool support
ollama pull firefunction-v2  # Optimized for functions
ollama pull command-r-plus  # Alternative with tools

# Pull other models
ollama pull deepseek-r1  # Reasoning model
ollama pull llava:latest  # Multimodal (no tools)

# Verify models
ollama list
```

### Peekaboo Configuration
```bash
# Use Ollama models
./peekaboo agent "analyze this code" --model ollama/llama3.1
./peekaboo agent "analyze this code" --model ollama/ultrathink  # When available

# Set as default
PEEKABOO_AI_PROVIDERS="ollama/llama3.1" ./peekaboo agent "help me"

# Multiple providers
PEEKABOO_AI_PROVIDERS="ollama/llama3.1,openai/gpt-4.1" ./peekaboo agent "task"

# OpenAI compatibility mode (alternative approach)
OLLAMA_OPENAI_COMPAT=true ./peekaboo agent "task" --model ollama/llama3.1
```

### OpenAI Compatibility Mode

Ollama also provides OpenAI API compatibility at `http://localhost:11434/v1/chat/completions`. This allows using Ollama with tools expecting OpenAI's API format. Benefits:
- Use existing OpenAI client libraries
- Simplified integration
- Consistent API format across providers

## Key Differences from Cloud Providers

1. **Local Execution**: No API keys required
2. **Model Management**: Must pull models before use
3. **Performance**: Depends on local hardware
4. **Privacy**: All data stays local
5. **Availability**: No rate limits or quotas
6. **Cost**: Free after initial hardware investment

## Success Criteria

- [ ] Basic chat completions working
- [ ] Streaming responses functional
- [ ] Tool calling implemented for:
  - [ ] Llama 3.1 (primary tool-calling model)
  - [ ] Qwen 2.5, Mistral, DeepSeek-R1
  - [ ] Capability detection for unsupported models
- [ ] Image analysis working (llava, bakllava)
- [ ] All common Ollama models registered with capability flags
- [ ] Ultrathink model fully supported (when available)
- [ ] Performance acceptable for local execution
- [ ] Graceful handling of server unavailability
- [ ] Model-specific optimizations (32k+ context for tool calling)

## Timeline

- Phase 1-2: 3-5 days (Core implementation)
- Phase 3-4: 3-4 days (Streaming & tools)
- Phase 5-6: 2-3 days (Models & Ultrathink)
- Phase 7: 2 days (Testing)

**Total: 10-14 days**

## Risks & Mitigations

1. **Risk**: Ultrathink model not yet available
   - **Mitigation**: Implement generic Ollama support first, add Ultrathink when released

2. **Risk**: Tool calling compatibility varies by model
   - **Mitigation**: Implement capability detection and graceful degradation

3. **Risk**: Performance issues with large models
   - **Mitigation**: Add configuration for GPU acceleration, implement timeouts

4. **Risk**: Ollama API changes
   - **Mitigation**: Version detection, compatibility layer

## Verdict: Full Implementation is Ready to Proceed ✅

After thorough analysis, **YES** - we can fully implement Ollama with all features working:

### What Will Work:
1. **Basic Chat Completions** ✅ - Full conversation support via `/api/chat`
2. **Streaming** ✅ - Newline-delimited JSON streaming with proper parsing
3. **Tool Calling** ✅ - Supported by Llama 3.1, Mistral Nemo, and other models
4. **Session Management** ✅ - Already generic via AgentSessionManager
5. **Agent Integration** ✅ - AgentRunner works with any ModelInterface
6. **Image Analysis** ✅ - For multimodal models (llava, bakllava)
7. **Error Handling** ✅ - Comprehensive error recovery strategies

### Key Implementation Notes:
- **Session persistence** is already provider-agnostic through AgentSessionManager
- **Conversation context** managed by sending full message history (Ollama is stateless)
- **Tool calling** requires model support (Llama 3.1 recommended)
- **Streaming** uses URLSession.bytes with line-by-line JSON parsing
- **No changes needed** to AgentRunner or session infrastructure

### Implementation Priority:
1. **Phase 1-2**: Core OllamaModel implementation (3-5 days)
2. **Phase 3**: Streaming support (1-2 days)
3. **Phase 4**: Tool calling (2 days)
4. **Phase 5-7**: Model registration & testing (4-5 days)

**Total: 10-14 days for complete implementation**

## Next Steps

1. Begin Phase 1: Move OllamaProvider to Core and create OllamaModel
2. Implement ModelInterface protocol conformance
3. Add streaming support with proper JSON parsing
4. Test with Llama 3.1 for tool calling verification
5. Add Ultrathink support when model becomes available

## References

### Official Documentation
- [Ollama Tool Support Blog](https://ollama.com/blog/tool-support)
- [Streaming with Tool Calling](https://ollama.com/blog/streaming-tool)
- [Python Library v0.4 with Functions](https://ollama.com/blog/functions-as-tools)
- [Models with Tool Support](https://ollama.com/search?c=tools)

### Implementation Examples
- IBM's [Ollama Tool Calling Tutorial](https://www.ibm.com/think/tutorials/local-tool-calling-ollama-granite)
- [Function Calling with Gemma3](https://medium.com/google-cloud/function-calling-with-gemma3-using-ollama-120194577fa6)

### Key Insights
1. Tool calling officially supported as of 2025
2. Streaming now works with tool calls (improved parser)
3. 32k+ context window recommended for better tool performance
4. Models page has dedicated "Tools" category
5. Python SDK v0.4+ allows direct function passing

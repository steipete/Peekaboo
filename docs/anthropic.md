# Anthropic SDK Integration Plan for Peekaboo

## Overview

This document outlines the plan for adding Anthropic Claude support to Peekaboo, enabling users to leverage Claude models alongside existing OpenAI models.

## SDK Options Analysis

### 1. Community Swift SDKs

**AnthropicSwiftSDK** (https://github.com/fumito-ito/AnthropicSwiftSDK)
- ✅ Pure Swift implementation
- ✅ Async/await support
- ✅ Tool/function calling via macros
- ❌ External dependency
- ❌ May lag behind API updates

**SwiftAnthropic** (https://github.com/jamesrochabrun/SwiftAnthropic)
- ✅ Comprehensive API coverage
- ✅ Well-documented
- ✅ Multi-platform support
- ❌ External dependency
- ❌ Different architectural patterns than Peekaboo

### 2. Official TypeScript SDK

**anthropic-sdk-typescript** (https://github.com/anthropics/anthropic-sdk-typescript)
- ✅ Official support
- ✅ Always up-to-date
- ❌ Requires Node.js bridge
- ❌ Performance overhead
- ❌ Complexity of cross-language integration

### 3. Custom Implementation (Recommended)

Build a native Swift implementation following Peekaboo's existing patterns.

**Advantages:**
- ✅ Consistent with existing OpenAI implementation
- ✅ No external dependencies
- ✅ Full control over features and compatibility
- ✅ Optimized for Peekaboo's architecture
- ✅ Direct API calls without subprocess overhead

**Disadvantages:**
- ❌ More initial development work
- ❌ Need to maintain API compatibility

## Recommendation: Custom Swift Implementation

Based on Peekaboo's philosophy of "No Backwards Compatibility" and preference for clean, modern code without dependencies, I recommend building a custom Anthropic implementation.

## Implementation Plan

The plan leverages Peekaboo's existing protocol-based architecture, as demonstrated in the recent OpenAI API migration. This ensures the Anthropic integration will be a natural extension of the current system.

### Phase 1: Core Components (2-3 days)

1. **Create Anthropic-specific types**
   - Location: `Core/PeekabooCore/Sources/PeekabooCore/AI/Anthropic/AnthropicTypes.swift`
   - Request/response structures
   - Message format types
   - Tool/function definitions
   - Error types

2. **Create AnthropicModel.swift**
   - Location: `Core/PeekabooCore/Sources/PeekabooCore/AI/Models/AnthropicModel.swift`
   - Implement `ModelInterface` protocol (matching OpenAIModel pattern)
   - Basic message creation
   - Authentication handling
   - Error handling

3. **API Integration**
   - Endpoint: `https://api.anthropic.com/v1/messages`
   - Headers: `x-api-key`, `anthropic-version`
   - Request/response parsing

### Phase 2: Streaming Support (1-2 days)

1. **SSE Parser**
   - Handle server-sent events
   - Parse streaming chunks
   - Convert to Peekaboo's `StreamEvent` types

2. **Streaming Integration**
   - Implement `getStreamedResponse`
   - Handle partial content blocks
   - Tool streaming support

### Phase 3: Tool/Function Calling (1-2 days)

1. **Tool Conversion**
   - Map `ToolDefinition` to Anthropic format
   - Handle `tool_use` content blocks
   - Process `tool_result` responses

2. **Tool Streaming**
   - Stream tool calls
   - Handle partial JSON in tool arguments

### Phase 4: Integration (1 day)

1. **Model Registration**
   ```swift
   // In ModelProvider.swift
   registerAnthropicModels()
   ```

2. **Credential Management**
   - Add `ANTHROPIC_API_KEY` support
   - Update configuration system

3. **Model Configuration**
   - Register Claude models:
     - claude-3-opus-latest
     - claude-3-sonnet-20240229
     - claude-3-haiku-20240307
     - claude-3-5-sonnet-latest
     - claude-sonnet-4-20250514

### Phase 5: Testing & Polish (1-2 days)

1. **Testing**
   - Unit tests using Swift Testing framework
   - Integration tests
   - Error scenario testing

2. **Documentation**
   - Update CLAUDE.md
   - Add usage examples
   - API documentation

## Technical Details

### Message Conversion

```swift
// Peekaboo → Anthropic
SystemMessageItem → system parameter
UserMessageItem → messages[].content
AssistantMessageItem → messages[].content
ToolMessageItem → tool_result content block
```

### Authentication

```swift
var request = URLRequest(url: url)
request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
```

### Key Differences from OpenAI

1. **Message Format**: Anthropic uses a different message structure with content blocks
2. **System Prompt**: Separate parameter, not a message
3. **Tool Format**: Different schema for tool definitions
4. **Streaming**: Different event types and format
5. **Error Handling**: Different error response structure

## Success Criteria

- [ ] Basic message generation working
- [ ] Streaming responses functional
- [ ] Tool calling implemented
- [ ] All Claude models registered
- [ ] Tests passing
- [ ] Performance on par with OpenAI implementation

## Timeline

Estimated total: 7-10 days for complete implementation

## Next Steps

1. Review and approve this plan
2. Create branch for Anthropic integration
3. Begin Phase 1 implementation
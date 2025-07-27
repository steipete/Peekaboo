# AI Integration Layer

This directory contains the AI abstraction layer that enables Peekaboo to work with multiple AI providers through a unified interface.

## Architecture Overview

```
AI/
├── Core/           # Common interfaces and types
├── Providers/      # Provider-specific implementations
└── Agent/          # Agent framework for automation
```

## Core Abstractions

### ModelInterface Protocol
The heart of the AI layer - defines the contract all AI models must implement:
- `complete()` - Single completion
- `stream()` - Streaming responses
- `completeWithTools()` - Tool-enabled completions

### Message Types
Unified message format supporting:
- Text content
- Image content (base64)
- Tool calls and results
- System instructions

### Streaming
Consistent streaming interface across all providers with:
- Token-by-token streaming
- Tool call streaming
- Error handling during streams

## Supported Providers

### OpenAI
- **Models**: gpt-4.1, gpt-4o, o3, o4
- **Features**: Dual API support (Chat/Responses), reasoning models
- **Special**: o3/o4 models use reasoning parameters

### Anthropic
- **Models**: Claude 3, 3.5, 4 series
- **Features**: Native SDK implementation, extended thinking modes
- **Special**: System prompts as separate parameter

### Grok (xAI)
- **Models**: grok-4, grok-2 series
- **Features**: OpenAI-compatible API
- **Special**: Parameter filtering for compatibility

### Ollama
- **Models**: llama3.3 (recommended), various local models
- **Features**: Local model support, tool calling varies by model
- **Special**: Extended timeouts for model loading

## Agent Framework

The agent framework builds on top of the AI providers to enable:
- Multi-step task automation
- Tool usage for UI interaction
- Session management and resumption
- Streaming execution with events

### Key Components
- **Agent** - Core agent definition with tools and instructions
- **AgentRunner** - Execution engine for running agents
- **Tool** - Abstraction for agent capabilities
- **AgentSessionManager** - Conversation persistence

## Usage Examples

### Direct Model Usage
```swift
let provider = ModelProvider.shared
let model = try provider.createModel(named: "gpt-4.1")

let response = try await model.complete(
    messages: [Message(role: .user, content: "Hello!")],
    temperature: 0.7
)
```

### Agent Usage
```swift
let agent = PeekabooAgent<MyContext>(
    name: "Assistant",
    instructions: "You are a helpful assistant",
    tools: [myTool1, myTool2],
    modelSettings: ModelSettings(modelName: "claude-opus-4")
)

let result = try await AgentRunner.run(
    agent: agent,
    input: "Complete this task",
    context: myContext
)
```

## Adding a New Provider

1. Create a new directory under `Providers/YourProvider/`
2. Implement the `ModelInterface` protocol
3. Add provider-specific types if needed
4. Update `ModelProvider` to recognize your provider
5. Add tests for your implementation

## Configuration

Providers are configured through:
- Environment variables (e.g., `OPENAI_API_KEY`)
- Credentials file (`~/.peekaboo/credentials`)
- Direct configuration in code

## Best Practices

- Always handle both streaming and non-streaming modes
- Implement proper error handling with typed errors
- Support cancellation for long-running operations
- Log API calls for debugging (without exposing keys)
- Implement retry logic for transient failures
- Respect rate limits and implement backoff
# Changelog

All notable changes to the Tachikoma project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2025-02-02

### Added

#### Core Framework
- Initial release of Tachikoma AI integration library
- Unified `ModelInterface` protocol for all AI providers
- Comprehensive message type system with multimodal support
- Real-time streaming response handling with `AsyncThrowingStream`
- Type-safe tool calling system with generic context support
- Actor-based provider registry with intelligent caching
- Swift 6 strict concurrency compliance throughout

#### Provider Support
- **OpenAI Provider**: Complete integration with dual API support
  - Chat Completions API for standard models (GPT-4o, GPT-4.1)
  - Responses API for reasoning models (o3, o4 series)
  - Automatic API selection based on model capabilities
  - Parameter filtering for reasoning models
  - Full streaming support for both APIs
  - Reasoning summary handling for thinking models

- **Anthropic Provider**: Native Claude API integration
  - Support for Claude 4 (Opus, Sonnet) with thinking modes
  - Claude 3.5/3.7 series compatibility
  - Content block handling for multimodal inputs
  - System prompt separation
  - Server-Sent Events streaming
  - Extended reasoning capabilities

- **Grok Provider**: xAI integration with OpenAI compatibility
  - Grok 4, Grok 3, Grok 2 series support
  - Vision model capabilities
  - Parameter filtering for Grok 3/4 models
  - Standard streaming implementation
  - OpenAI-compatible Chat Completions API

- **Ollama Provider**: Local model inference support
  - Support for Llama 3.3 (recommended), Mistral, CodeLlama
  - Vision models (llava, bakllava) without tool calling
  - Configurable endpoints for self-hosted deployments
  - Extended timeouts for local model loading
  - Tool calling detection for compatible models

#### Message System
- **Unified Message Types**: Support for system, user, assistant, tool, and reasoning messages
- **Content Types**: Text, images (URL/base64), multimodal, files, audio with transcripts
- **Assistant Content**: Text output, refusals, tool calls with proper typing
- **Image Support**: High/low detail levels, multiple formats, base64 encoding
- **Audio Support**: Transcript extraction, duration metadata

#### Streaming System
- **Event-Based Architecture**: Comprehensive streaming event types
- **Real-Time Processing**: Incremental text deltas, tool call construction
- **Memory Efficiency**: Constant memory usage regardless of response size
- **Error Handling**: Structured error events with recovery information
- **Provider Abstraction**: Unified events across different provider formats

#### Tool Calling
- **Generic Tool System**: Type-safe tool execution with context support
- **Parameter Validation**: JSON Schema-based parameter validation
- **Async Execution**: Non-blocking tool execution with proper error handling
- **Tool Definitions**: Provider-agnostic tool definition format
- **Context Management**: Type-safe context passing to tool functions

#### Error Handling
- **Comprehensive Error Types**: Structured error hierarchy with recovery guidance
- **Provider-Specific Errors**: Tailored error handling for each provider
- **Retry Logic**: Built-in retry detection with exponential backoff support
- **Error Categories**: Client, authentication, network, and provider errors
- **Localized Descriptions**: User-friendly error messages with recovery suggestions

#### Configuration System
- **Environment Variables**: Support for standard API key environment variables
- **Provider Configuration**: Flexible configuration for custom endpoints
- **Model Registration**: Runtime model factory registration
- **Lenient Matching**: Intelligent model name resolution
- **Cache Management**: Configurable caching policies

### Technical Features

#### Swift 6 Compliance
- **Strict Concurrency**: Full Swift 6 strict concurrency mode compliance
- **Sendable Conformance**: All public types conform to Sendable protocol
- **Actor Safety**: Thread-safe operations with proper isolation
- **Memory Safety**: No data races or concurrency issues
- **Performance**: Optimized for concurrent execution

#### Performance Optimizations
- **Intelligent Caching**: Model instance caching with smart invalidation
- **Connection Pooling**: Efficient network connection management
- **Memory Management**: Minimal allocations and efficient garbage collection
- **Streaming Efficiency**: Incremental processing without accumulation
- **JSON Optimization**: Fast encoding/decoding without reflection

#### Type Safety
- **Compile-Time Verification**: Strong typing throughout the API
- **Generic Constraints**: Type-safe tool contexts and parameters
- **Enum-Based Design**: Exhaustive pattern matching for robustness
- **Protocol-Oriented**: Clean abstractions with concrete implementations

### Documentation
- Comprehensive README with quick start guide
- Detailed architecture documentation
- API reference documentation
- Code examples for common usage patterns
- Migration guide from PeekabooCore
- Performance optimization guidelines

### Testing
- Unit tests for all core components
- Integration tests for provider functionality
- Mock providers for testing scenarios
- Performance benchmarks
- Concurrency safety tests

### Platform Support
- macOS 14.0+
- iOS 17.0+
- watchOS 10.0+
- tvOS 17.0+
- Swift 6.0+
- Xcode 16.0+

## [Unreleased]

### Planned Features
- Enhanced caching with persistence and TTL
- Bidirectional streaming support
- Request batching for high-volume usage
- Advanced error recovery mechanisms
- Metrics collection and monitoring
- Distributed caching support

---

## Version History

- **v1.0.0**: Initial release extracted from PeekabooCore with Swift 6 compliance
- **v0.x.x**: Development versions (internal)

## Migration Notes

### From PeekabooCore
When migrating from PeekabooCore's AI system:

1. **Error Types**: Replace `PeekabooError` with `TachikomaError`
2. **Import Statements**: Update to `import Tachikoma`
3. **Model Creation**: Use `Tachikoma.shared.getModel()` instead of direct instantiation
4. **Streaming Events**: Update event handling for new event type hierarchy
5. **Message Types**: Adopt new unified message type system
6. **Tool Calling**: Update to generic tool system with context support

### Breaking Changes
This is the initial release, so no breaking changes from previous versions.

## Contributors

- **Extraction Lead**: AI Assistant
- **Original Code**: Peekaboo project contributors
- **Architecture Design**: Based on proven patterns from PeekabooCore
- **Swift 6 Migration**: Complete rewrite for strict concurrency compliance

## License

This project is licensed under the MIT License. See LICENSE file for details.
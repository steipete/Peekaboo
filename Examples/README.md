# 🎓 Tachikoma Examples

Welcome to the Tachikoma Examples package! This collection demonstrates the power and flexibility of Tachikoma's multi-provider AI integration system through practical, executable examples.

## 🌟 What Makes Tachikoma Special?

Unlike other AI libraries, Tachikoma provides:

- **🔄 Provider Agnostic**: Same code works with OpenAI, Anthropic, Ollama, Grok
- **🏗️ Dependency Injection**: Testable, configurable, no hidden singletons
- **🎯 Unified Interface**: Consistent API across all providers
- **⚙️ Smart Configuration**: Environment-based setup with automatic model detection

## 📦 Examples Overview

### 1. 🚀 TachikomaComparison - The Killer Demo
**The showcase example** - Compare AI providers side-by-side in real-time!

```bash
swift run TachikomaComparison "Explain quantum computing"
```

**What it demonstrates:**
- Multi-provider comparison with identical code
- Performance and cost analysis
- Side-by-side response visualization
- Interactive mode for continuous testing

**Sample Output:**
```
┌────────────────────────────────────────┐ ┌────────────────────────────────────────┐
│           🤖 OpenAI GPT-4.1            │ │        🧠 Anthropic Claude Opus 4      │
├────────────────────────────────────────┤ ├────────────────────────────────────────┤
│ Quantum computing harnesses quantum    │ │ Quantum computing represents a         │
│ mechanical phenomena like superposition│ │ revolutionary approach to computation  │
│ and entanglement to process information│ │ that leverages quantum mechanics...    │
│ ⏱️ 1.2s | 💰 $0.003 | 🔤 150 tokens     │ │ ⏱️ 0.8s | 💰 $0.004 | 🔤 145 tokens     │
└────────────────────────────────────────┘ └────────────────────────────────────────┘
```

### 2. 🎓 TachikomaBasics - Getting Started
**Perfect starting point** - Learn fundamental concepts step by step.

```bash
swift run TachikomaBasics "Hello, AI!"
swift run TachikomaBasics --provider openai "Write a haiku"
swift run TachikomaBasics --list-providers
```

**What it demonstrates:**
- Environment setup and configuration
- Basic request/response patterns
- Provider selection and fallbacks
- Error handling and debugging

### 3. ⚡ TachikomaStreaming - Real-time Responses
**Live streaming demo** - See responses appear in real-time.

```bash
swift run TachikomaStreaming "Tell me a story"
swift run TachikomaStreaming --race "Compare streaming speeds"
```

**What it demonstrates:**
- Real-time streaming from multiple providers
- Progress indicators and partial responses
- Streaming performance comparison
- Terminal-based live display

### 4. 🤖 TachikomaAgent - AI Agents & Tool Calling
**Agent patterns** - Build AI agents with custom tools and function calling.

```bash
swift run TachikomaAgent "What's the weather in San Francisco?"
swift run TachikomaAgent --tools weather,calculator "Calculate 15% tip for $67.50 meal"
```

**What it demonstrates:**
- Function/tool calling across providers
- Custom tool definitions (weather, calculator, file operations)
- Agent conversation patterns
- Tool response handling

### 5. 👁️ TachikomaMultimodal - Vision + Text
**Multimodal processing** - Combine text and images across providers.

```bash
swift run TachikomaMultimodal --image chart.png "Analyze this chart"
swift run TachikomaMultimodal --compare-vision "Which provider sees better?"
```

**What it demonstrates:**
- Image analysis with different providers
- Text + image combination prompts
- Vision capability comparison (Claude vs GPT-4V vs LLaVA)
- Practical image processing workflows

## 📘 Tachikoma API Basics

Before diving into the examples, here's how to use Tachikoma in your own Swift projects:

### Basic Setup

```swift
import Tachikoma

// 1. Create a model provider (auto-detects available providers)
let modelProvider = try AIConfiguration.fromEnvironment()

// 2. Get a specific model
let model = try modelProvider.getModel("gpt-4.1") // or "claude-opus-4-20250514", "llama3.3", etc.
```

### Simple Text Generation

```swift
// Create a basic request
let request = ModelRequest(
    messages: [Message.user(content: .text("Explain quantum computing"))],
    settings: ModelSettings(maxTokens: 300)
)

// Get response
let response = try await model.getResponse(request: request)

// Extract text
let text = response.content.compactMap { item in
    if case let .outputText(text) = item { return text }
    return nil
}.joined()

print(text)
```

### Multi-Provider Comparison

```swift
// Compare responses from multiple providers
let providers = ["gpt-4.1", "claude-opus-4-20250514", "llama3.3"]

for providerModel in providers {
    let model = try modelProvider.getModel(providerModel)
    let response = try await model.getResponse(request: request)
    print("🤖 \(providerModel): \(extractText(response))")
}
```

### Streaming Responses

```swift
// Stream responses in real-time
let stream = try await model.streamResponse(request: request)

for try await event in stream {
    switch event {
    case .delta(let delta):
        if case let .outputText(text) = delta {
            print(text, terminator: "") // Print as it arrives
        }
    case .done:
        print("\n✅ Complete!")
    case .error(let error):
        print("❌ Error: \(error)")
    }
}
```

### Function Calling (Agent Patterns)

```swift
// Define tools for the AI to use
let weatherTool = ToolDefinition(
    function: FunctionDefinition(
        name: "get_weather",
        description: "Get current weather for a location",
        parameters: ToolParameters.object(properties: [
            "location": .string(description: "City name")
        ], required: ["location"])
    )
)

// Create request with tools
let request = ModelRequest(
    messages: [Message.user(content: .text("What's the weather in Tokyo?"))],
    tools: [weatherTool],
    settings: ModelSettings(maxTokens: 500)
)

let response = try await model.getResponse(request: request)

// Handle tool calls
for content in response.content {
    if case let .toolCall(call) = content {
        print("🔧 AI wants to call: \(call.function.name)")
        print("📋 Arguments: \(call.function.arguments)")
        
        // Execute tool and send result back...
    }
}
```

### Multimodal (Vision + Text)

```swift
// Load image as base64
let imageData = Data(contentsOf: URL(fileURLWithPath: "chart.png"))
let base64Image = imageData.base64EncodedString()

// Create multimodal request
let request = ModelRequest(
    messages: [Message.user(content: .multimodal([
        MessageContentPart(type: "text", text: "Analyze this chart"),
        MessageContentPart(type: "image_url", 
                          imageUrl: ImageContent(base64: base64Image))
    ]))],
    settings: ModelSettings(maxTokens: 500)
)

let response = try await model.getResponse(request: request)
print("🔍 Analysis: \(extractText(response))")
```

### Error Handling

```swift
do {
    let response = try await model.getResponse(request: request)
    // Handle success
} catch AIError.rateLimitExceeded {
    print("⏳ Rate limit hit, waiting...")
} catch AIError.invalidAPIKey {
    print("🔑 Check your API key")
} catch {
    print("❌ Unexpected error: \(error)")
}
```

### Provider-Specific Features

```swift
// OpenAI-specific: Use reasoning models
let o3Model = try modelProvider.getModel("o3")
let request = ModelRequest(
    messages: [Message.user(content: .text("Solve this complex problem"))],
    settings: ModelSettings(
        maxTokens: 1000,
        reasoningEffort: .high // o3-specific parameter
    )
)

// Anthropic-specific: Use thinking mode
let claudeModel = try modelProvider.getModel("claude-opus-4-20250514-thinking")
// Thinking mode automatically enabled
```

### Configuration Options

```swift
// Custom configuration
let config = AIConfiguration(providers: [
    .openAI(apiKey: "sk-...", baseURL: "https://api.openai.com"),
    .anthropic(apiKey: "sk-ant-...", baseURL: "https://api.anthropic.com"),
    .ollama(baseURL: "http://localhost:11434")
])

let modelProvider = try AIModelProvider(configuration: config)
```

## 🚀 Quick Start

### 1. Prerequisites

```bash
# Ensure you have Swift 6.0+ installed
swift --version

# Clone the repository (if not already done)
cd /path/to/Peekaboo/Examples
```

### 2. Set Up API Keys

Configure at least one AI provider:

```bash
# OpenAI (recommended for getting started)
export OPENAI_API_KEY=sk-your-openai-key-here

# Anthropic Claude
export ANTHROPIC_API_KEY=sk-ant-your-anthropic-key-here

# xAI Grok
export X_AI_API_KEY=xai-your-grok-key-here

# Ollama (local, no API key needed)
ollama pull llama3.3
ollama pull llava
```

### 3. Build and Run

```bash
# Build all examples
swift build

# Run the killer demo
swift run TachikomaComparison "What is the future of AI?"

# Start with basics
swift run TachikomaBasics --list-providers
swift run TachikomaBasics "Hello, Tachikoma!"

# Try interactive mode
swift run TachikomaComparison --interactive
```

## 🛠️ Development Setup

### Building Individual Examples

```bash
# Build specific examples
swift build --target TachikomaComparison
swift build --target TachikomaBasics
swift build --target TachikomaStreaming
swift build --target TachikomaAgent
swift build --target TachikomaMultimodal

# Run with custom arguments
swift run TachikomaComparison --providers openai,anthropic --verbose "Your question"
```

### Running Tests

```bash
# Run all example tests
swift test

# Run with verbose output
swift test --verbose
```

### Local Development

```bash
# Make examples executable
chmod +x .build/debug/TachikomaComparison
chmod +x .build/debug/TachikomaBasics

# Create convenient aliases
alias tc='.build/debug/TachikomaComparison'
alias tb='.build/debug/TachikomaBasics'
alias ts='.build/debug/TachikomaStreaming'
alias ta='.build/debug/TachikomaAgent'
alias tm='.build/debug/TachikomaMultimodal'
```

## 🎯 Usage Patterns

### Environment Configuration

```bash
# Option 1: Environment variables
export OPENAI_API_KEY=sk-...
export ANTHROPIC_API_KEY=sk-ant-...

# Option 2: Credentials file
mkdir -p ~/.tachikoma
echo "OPENAI_API_KEY=sk-..." >> ~/.tachikoma/credentials
echo "ANTHROPIC_API_KEY=sk-ant-..." >> ~/.tachikoma/credentials
```

### Provider Selection

```bash
# Auto-detect (recommended)
swift run TachikomaComparison "Your question"

# Specific providers
swift run TachikomaComparison --providers openai,anthropic "Your question"
swift run TachikomaBasics --provider ollama "Your question"

# Interactive exploration
swift run TachikomaComparison --interactive
```

### Advanced Usage

```bash
# Verbose output for debugging
swift run TachikomaBasics --verbose "Debug this request"

# Custom formatting
swift run TachikomaComparison --column-width 80 --max-length 1000 "Long question"

# Tool-enabled agents
swift run TachikomaAgent --tools weather,calculator,file_reader "Complex task"
```

## 📊 Performance Metrics

All examples automatically measure and display performance metrics after each run:

### Basic Examples (TachikomaBasics)
- **Response Time**: How fast each provider responds
- **Token Usage**: Estimated tokens consumed  
- **Cost Estimation**: Approximate cost per request
- **Model Information**: Which specific model was used

```
⏱️ Duration: 2.45s | 🔤 Tokens: ~67 | 🤖 Model: gpt-4.1
💰 Estimated cost: $0.0034
```

### Comparison Examples (TachikomaComparison)
- **Side-by-side comparison** of multiple providers
- **Performance ranking** with fastest/slowest identification
- **Cost analysis** across providers

```
📊 Summary Statistics:
⚡ Fastest: OpenAI gpt-4.1 (1.14s)
🐌 Slowest: Ollama llama3.3 (26.46s)
💰 Cheapest: Ollama llama3.3 (Free)
💸 Most Expensive: Anthropic claude-opus-4 ($0.0045)
```

### Streaming Examples (TachikomaStreaming)
- **Real-time streaming metrics** with live updates
- **Time to first token** measurement
- **Streaming rate** in tokens/second and characters/second

```
📊 Streaming Statistics:
⏱️ Total time: 13.05s | 🚀 Time to first token: 9.60s
📊 Streaming rate: 8.6 tokens/sec | ⚡ Character rate: 36 chars/sec
🔤 Total tokens: 112 | 📏 Response length: 469 characters
```

### Agent Examples (TachikomaAgent) - NEW!
- **Total execution time** for complex multi-step tasks
- **Function call tracking** showing tool usage
- **Performance assessment** (Fast/Good/Slow)

```
📊 Agent Performance Summary:
⏱️ Total time: 0.67s | 🔤 Tokens used: ~8 | 🔧 Function calls: 0
🚀 Performance: Fast
```

### Vision Examples (TachikomaMultimodal)
- **Image processing duration** for vision tasks
- **Analysis confidence** percentage
- **Word count** and response characteristics

```
⏱️ Duration: 22.51s | 🔤 Tokens: 301 | 📝 Words: 182 | 🎯 Confidence: 90%
```

## 🎨 Customization

### Adding New Providers

```swift
// In SharedExampleUtils/ExampleUtilities.swift
public static func providerEmoji(_ provider: String) -> String {
    switch provider.lowercased() {
    case "your-provider":
        return "🔥"
    // ... existing providers
    }
}
```

### Custom Tools for Agent Examples

```swift
// In TachikomaAgent source
let customTool = FunctionDeclaration(
    name: "your_tool",
    description: "What your tool does",
    parameters: .object(properties: [
        "param1": .string(description: "Parameter description")
    ])
)
```

### Styling Terminal Output

```swift
// Use SharedExampleUtils for consistent styling
TerminalOutput.print("Success!", color: .green)
TerminalOutput.header("Section Title")
TerminalOutput.separator("─", length: 50)
```

## 🐛 Troubleshooting

### Common Issues

**"No models available"**
```bash
# Check your API keys
swift run TachikomaBasics --list-providers

# Verify environment
echo $OPENAI_API_KEY
echo $ANTHROPIC_API_KEY
```

**Ollama connection issues**
```bash
# Ensure Ollama is running
ollama list
ollama serve

# Pull required models
ollama pull llama3.3
ollama pull llava
```

**Build errors**
```bash
# Clean and rebuild
swift package clean
swift build
```

### Debug Mode

```bash
# Enable verbose logging
swift run TachikomaBasics --verbose "Debug message"

# Check available providers
swift run TachikomaComparison --list-providers
```

## 🤝 Contributing

Want to add more examples or improve existing ones?

1. **Add new example**: Create a new target in `Package.swift`
2. **Extend utilities**: Add helpers to `SharedExampleUtils`
3. **Improve documentation**: Update this README
4. **Test thoroughly**: Ensure examples work with all providers

## 📚 Next Steps

After exploring these examples:

1. **Integrate Tachikoma** into your own Swift projects
2. **Experiment with providers** to find the best fit for your use case
3. **Build custom tools** for the agent examples
4. **Contribute back** improvements and new examples

## 🔗 Related Documentation

- [Tachikoma Main Documentation](../Tachikoma/README.md)
- [Architecture Overview](../ARCHITECTURE.md)
- [API Reference](../Tachikoma/docs/)

---

## 💡 Pro Tips

- **Start with TachikomaComparison** - it's the most impressive demo
- **Use `--interactive` mode** for experimentation
- **Try different providers** to see quality differences
- **Measure performance** with the built-in statistics
- **Read the source code** - examples are educational!

Happy coding with Tachikoma! 🎉
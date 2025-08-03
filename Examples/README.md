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

## 📊 Performance Comparison

The examples automatically measure and display:

- **Response Time**: How fast each provider responds
- **Token Usage**: Estimated tokens consumed
- **Cost Estimation**: Approximate cost per request
- **Response Quality**: Length and characteristics

Example output:
```
📊 Summary Statistics:
⚡ Fastest: Ollama llama3.3 (0.85s)
🐌 Slowest: OpenAI gpt-4.1 (2.34s)
💰 Cheapest: Ollama llama3.3 (Free)
💸 Most Expensive: Anthropic claude-opus-4 ($0.0045)
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
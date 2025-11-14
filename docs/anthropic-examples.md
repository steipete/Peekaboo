---
summary: 'Review Anthropic Claude Examples for Peekaboo guidance'
read_when:
  - 'planning work related to anthropic claude examples for peekaboo'
  - 'debugging or extending features described here'
---

# Anthropic Claude Examples for Peekaboo

## Basic Usage

### Using Claude with the Agent Command

```bash
# Use Claude 3 Opus for complex tasks
./peekaboo agent "Analyze the UI structure of Safari and create a detailed report" --model claude-3-opus-20240229

# Use Claude 3.5 Sonnet for balanced performance
./peekaboo agent "Click on the Submit button in the current window" --model claude-3-5-sonnet-latest

# Use Claude 3 Haiku for quick responses
./peekaboo agent "What windows are currently open?" --model claude-3-haiku-20240307
```

### Environment Variable Configuration

```bash
# Set Anthropic API key
export ANTHROPIC_API_KEY=sk-ant-...

# Use Claude as default AI provider
export PEEKABOO_AI_PROVIDERS="anthropic/claude-3-opus-latest"

# Run agent with default Claude model
./peekaboo agent "Take a screenshot of the desktop"
```

### Multiple Providers

```bash
# Configure multiple providers with Claude as primary
export PEEKABOO_AI_PROVIDERS="anthropic/claude-3-opus-latest,openai/gpt-4.1"

# The agent will use Claude first, fall back to OpenAI if needed
./peekaboo agent "Help me organize my desktop"
```

## Advanced Examples

### Image Analysis with Claude

```bash
# Capture and analyze a window
./peekaboo image --app Safari --path safari.png
./peekaboo agent "Analyze the screenshot at safari.png and describe the webpage content" --model claude-3-opus-latest
```

### Multi-step Automation

```bash
# Complex automation with Claude's superior context handling
./peekaboo agent "Open System Settings, navigate to Privacy & Security, take a screenshot of the current permissions, then close the window" --model claude-3-opus-20240229
```

### Session Continuation

```bash
# Start a session with Claude
./peekaboo agent "Let's work on organizing my desktop. First, show me all open windows" --model claude-3-5-sonnet-latest

# Continue the session
./peekaboo agent --resume "Now close all Finder windows except the one showing Documents"
```

## Model Selection Guide

### Claude 3 Opus (`claude-3-opus-20240229`)
- **Best for**: Complex reasoning, detailed analysis, creative tasks
- **Use when**: You need the highest quality output and can wait a bit longer

### Claude 3.5 Sonnet (`claude-3-5-sonnet-latest`)
- **Best for**: Balanced performance, general automation
- **Use when**: You want good results with reasonable speed

### Claude 3 Haiku (`claude-3-haiku-20240307`)
- **Best for**: Quick responses, simple tasks
- **Use when**: Speed is more important than complexity

### Claude 4 Sonnet (`claude-sonnet-4-20250514`)
- **Best for**: Latest capabilities, newest features
- **Use when**: You want to use the most recent Claude model

## Performance Tips

1. **Use appropriate models**: Don't use Opus for simple tasks
2. **Leverage sessions**: Claude maintains excellent context across conversations
3. **Be specific**: Claude responds well to detailed instructions

## Troubleshooting

### API Key Issues
```bash
# Verify API key is set
echo $ANTHROPIC_API_KEY

# Set API key via config
./peekaboo config set-credential ANTHROPIC_API_KEY sk-ant-...
```

### Model Not Found
```bash
# List available models
./peekaboo agent "Hello" --model claude-9000 2>&1 | grep -i error
# Will show available model names in error message
```

### Rate Limiting
Claude has different rate limits per model tier. If you hit limits:
- Switch to a different model temporarily
- Add delays between requests
- Use Haiku for high-volume tasks
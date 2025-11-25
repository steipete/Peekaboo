---
summary: 'Review Ollama Models Guide guidance'
read_when:
  - 'planning work related to ollama models guide'
  - 'debugging or extending features described here'
---

# Ollama Models Guide

This guide provides an overview of Ollama models that excel at specific tasks, particularly tool/function calling and vision capabilities.

## Models for Tool/Function Calling

### By VRAM Requirements

#### 64 GB+ VRAM
- **Llama 3 Groq Tool-Use 70B**
  - Most accurate JSON output
  - Handles multi-tool and nested calls
  - Huge context window
  - Best choice for complex automation tasks

#### 32 GB VRAM
- **Mixtral 8×7B Instruct**
  - Native tool-calling flag support
  - MoE (Mixture of Experts) architecture for speed
  - 46B active parameters providing near-GPT-3.5 quality
  - Good balance of performance and capability

#### 24 GB VRAM
- **Mistral Small 3.1 24B**
  - Explicit "low-latency function calling" in documentation
  - Fits on single RTX 4090 or Apple Silicon 32GB
  - Excellent for production deployments

#### <16 GB VRAM
- **Functionary-Small v3.1 (8B)**
  - Fine-tuned solely for JSON schema compliance
  - Great for rapid prototyping
  - Reliable structured output

#### Laptop-class (8-12 GB)
- **Phi-3 Mini / Gemma 3.1-3B**
  - Tiny models that respond in JSON with careful prompting
  - Good for IoT agents and edge devices
  - Requires more prompt engineering

## Vision Models (Image Chat/OCR/Diagram Q&A)

### By VRAM Requirements

#### 7-34B Options
- **LLaVA 1.6**
  - Big improvement in resolution (up to 672×672)
  - Much better OCR than v1.5
  - Simple CLI: `ollama run llava`
  - Recommended for general vision tasks

#### 24B
- **Mistral Small 3.1 Vision**
  - Same text skills as tool-calling version plus vision
  - Supports 128k tokens
  - Can process long PDF pages as images or text chunks
  - Best for document + vision hybrid tasks

#### 2B
- **Granite 3.2-Vision**
  - Specialized for documents: tables, charts, invoices
  - Works on machines with <8GB VRAM
  - Excellent for business document processing

#### 1.8B
- **Moondream 2**
  - Ridiculously small model
  - Runs on Raspberry Pi-class devices
  - Still captions everyday photos decently
  - Perfect for edge computing

#### 7B
- **BakLLaVA**
  - Mistral-based fork of LLaVA
  - Better reasoning than LLaVA-7B
  - Heavier than Moondream but more capable

## Usage in Peekaboo

### Recommended Models for Agent Tasks

1. **Best Overall**: `llama3.3` (or aliases: `llama`, `llama3`)
   - Excellent tool calling support
   - Good balance of speed and accuracy
   - Works well with Peekaboo's automation tools

2. **For Vision Tasks**: `llava` or `mistral-small:3.1-vision`
   - Note: Vision models typically don't support tool calling
   - Use for image analysis tasks only

3. **For Limited Resources**: `mistral-nemo` or `firefunction-v2`
   - Smaller models with tool support
   - Good for testing and development

### Example Usage

```bash
# Tool calling with llama3.3
PEEKABOO_AI_PROVIDERS="ollama/llama3.3" ./scripts/peekaboo-wait.sh agent "Click on the Apple menu"

# Vision analysis with llava
PEEKABOO_AI_PROVIDERS="ollama/llava" ./scripts/peekaboo-wait.sh analyze screenshot.png "What's in this image?"

# Using model shortcuts
PEEKABOO_AI_PROVIDERS="ollama/llama" ./scripts/peekaboo-wait.sh agent "Type hello world"
```

## Important Notes

1. **Tool Calling Support**: Not all models support tool/function calling. Check the model's capabilities before using with Peekaboo's agent command.

2. **First Run**: Models need to be downloaded on first use. This can take several minutes depending on model size and internet speed.

3. **Performance**: Local inference speed depends heavily on your hardware. GPU acceleration (NVIDIA CUDA or Apple Metal) significantly improves performance.

4. **Memory Usage**: Ensure you have sufficient VRAM/RAM for your chosen model. The VRAM requirements listed are minimums for reasonable performance.

5. **Context Length**: Larger models generally support longer context windows, important for complex automation tasks.

## Model Selection Tips

- **For automation/agent tasks**: Choose models with explicit tool calling support
- **For simple tasks**: Smaller models (8B-24B) are often sufficient
- **For complex reasoning**: Larger models (70B+) provide better accuracy
- **For vision tasks**: LLaVA 1.6 is a solid default choice
- **For edge devices**: Consider Moondream 2 or Phi-3 Mini

## Troubleshooting

If a model returns HTTP 400 errors when used with Peekaboo's agent command, it likely doesn't support tool calling. Switch to a model from the tool calling list above.
# O3 Reasoning Token Investigation

## Summary

Investigation into why OpenAI o3 model doesn't show "thinking tokens" (reasoning tokens) during streaming in the Peekaboo agent implementation.

## Key Findings

### 1. API Differences

**Chat Completions API** (`/v1/chat/completions`):
- Currently used by Peekaboo
- Does NOT stream reasoning content
- Only includes final reasoning token count in usage statistics
- Supported fields in streaming: `content`, `tool_calls`, `refusal`

**Responses API** (`/v1/responses/create`):
- New API specifically for reasoning models
- DOES stream reasoning content
- Uses different event types:
  - `response.reasoning_summary_text.added`
  - `response.reasoning_summary_text.delta`
  - `response.reasoning_summary_text.done`
- Field name: `reasoning_content` (with underscore)
- Parameter: uses `input` instead of `messages`

### 2. Current Implementation Status

✅ **Completed:**
- Added `reasoningContent` field to `OpenAIDelta` struct
- Added debug logging for o3 models to inspect streaming chunks
- Registered o3/o4 models in ModelProvider
- Added handling for reasoning deltas in stream processing
- Fixed Date encoding issue in session metadata

❌ **Not Implemented:**
- Responses API endpoint support
- Different request/response format for Responses API
- Proper reasoning streaming visualization

### 3. Debug Output Analysis

When running with `--verbose`, the debug output shows:
```
DEBUG: o3 chunk JSON: {...}
DEBUG: o3 delta fields: ["content", "refusal", "role"]
```

No `reasoning_content` field is present because the Chat Completions API doesn't include it.

## Recommendations

### Current Limitations
The Responses API requires session keys and is browser-only. It cannot be used with API keys in CLI tools. The error message confirms:
```
"Your request to POST /v1/responses/create must be made with a session key (that is, it can only be made from the browser)"
```

Therefore, CLI tools must use the Chat Completions API, which doesn't provide reasoning content during streaming.

### What Works Today
The current implementation using Chat Completions API is working correctly. Users can still see:
- Final response content
- Tool usage
- Completion token count (includes reasoning tokens)
- Reasoning happens internally but isn't visible during streaming

### Future Options

1. Add endpoint selection logic in `OpenAIModel.swift`:
   ```swift
   private func getEndpointForModel(_ modelName: String) -> String {
       if modelName.hasPrefix("o3") || modelName.hasPrefix("o4") {
           return "responses/create"  // For reasoning visibility
       }
       return "chat/completions"
   }
   ```

2. Implement `OpenAIResponsesRequest` conversion
3. Handle new streaming event types
4. Update UI to show reasoning progress

## Testing

To test o3 with the current implementation:
```bash
./peekaboo agent "Complex question here" --model o3 --verbose
```

The model will work but won't show reasoning during streaming. The reasoning tokens are still being used internally by the model and counted in the usage statistics.

## References

- [OpenAI Responses API Documentation](https://cookbook.openai.com/examples/responses_api/reasoning_items)
- [LangChain Implementation](https://github.com/langchain-ai/langchain/blob/master/libs/partners/openai/langchain_openai/chat_models/base.py)
- [Vercel AI SDK Implementation](https://github.com/vercel/ai/blob/main/packages/openai/src/openai-chat-language-model.ts)
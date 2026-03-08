---
summary: 'Connect Peekaboo to AWS Bedrock models via LiteLLM proxy'
read_when:
  - 'configuring AWS Bedrock as an AI provider'
  - 'using LiteLLM proxy with Peekaboo'
---

# AWS Bedrock via LiteLLM Proxy

Peekaboo has no built-in AWS Bedrock provider, but supports OpenAI-compatible custom providers. [LiteLLM](https://github.com/BerriAI/litellm) acts as a proxy that exposes Bedrock models through an OpenAI-compatible API, letting Peekaboo use Claude, Llama, Mistral, Titan, and other models hosted on Bedrock.

## Prerequisites

- AWS CLI configured with a profile that has `bedrock:InvokeModel` permission (`~/.aws/credentials`)
- Bedrock models enabled in your AWS account (request access via AWS Console > Bedrock > Model access)
- Docker or pip available for running LiteLLM

## Step 1: Install LiteLLM Proxy

With pip:

```bash
pip install 'litellm[proxy]'
```

Or Docker:

```bash
docker pull ghcr.io/berriai/litellm:main-latest
```

## Step 2: Create LiteLLM Config

Create `~/.peekaboo/litellm_config.yaml`:

```yaml
model_list:
  # Claude models
  - model_name: claude-3-5-sonnet
    litellm_params:
      model: bedrock/anthropic.claude-3-5-sonnet-20241022-v2:0
      aws_profile_name: default    # your AWS profile
      aws_region_name: us-east-1   # your Bedrock region

  - model_name: claude-3-haiku
    litellm_params:
      model: bedrock/anthropic.claude-3-haiku-20240307-v1:0
      aws_profile_name: default
      aws_region_name: us-east-1

  # Llama models
  - model_name: llama3-70b
    litellm_params:
      model: bedrock/meta.llama3-70b-instruct-v1:0
      aws_profile_name: default
      aws_region_name: us-east-1

  # Mistral models
  - model_name: mistral-large
    litellm_params:
      model: bedrock/mistral.mistral-large-2407-v1:0
      aws_profile_name: default
      aws_region_name: us-east-1
```

Adjust `model_name` (your alias), `model` (Bedrock model ID), `aws_profile_name`, and `aws_region_name` to match your setup.

## Step 3: Start LiteLLM Proxy

With pip:

```bash
litellm --config ~/.peekaboo/litellm_config.yaml --port 4000
```

With Docker:

```bash
docker run -d \
  -v ~/.aws:/root/.aws:ro \
  -v ~/.peekaboo/litellm_config.yaml:/app/config.yaml:ro \
  -p 4000:4000 \
  ghcr.io/berriai/litellm:main-latest \
  --config /app/config.yaml --port 4000
```

Verify the proxy is running:

```bash
curl http://localhost:4000/health
```

For persistent operation, consider running LiteLLM via `launchd` (macOS) or Docker with `--restart=always`.

## Step 4: Configure Peekaboo Provider

### Option A: CLI

```bash
peekaboo config add-provider \
  --id bedrock \
  --name "AWS Bedrock (via LiteLLM)" \
  --type openai \
  --url "http://localhost:4000/v1" \
  --api-key "sk-1234"
```

> LiteLLM does not require a real API key by default, but Peekaboo requires a non-empty `apiKey`. Use a placeholder value, or the actual master key if you configured one in LiteLLM.

### Option B: Edit config directly

Add to `~/.peekaboo/config.json`:

```json
{
  "customProviders": {
    "bedrock": {
      "name": "AWS Bedrock (via LiteLLM)",
      "description": "Bedrock models proxied through LiteLLM",
      "type": "openai",
      "options": {
        "baseURL": "http://localhost:4000/v1",
        "apiKey": "sk-1234"
      },
      "models": {
        "claude-3-5-sonnet": {
          "name": "Claude 3.5 Sonnet (Bedrock)",
          "maxTokens": 8192,
          "supportsTools": true,
          "supportsVision": true
        },
        "claude-3-haiku": {
          "name": "Claude 3 Haiku (Bedrock)",
          "maxTokens": 4096,
          "supportsTools": true,
          "supportsVision": true
        },
        "llama3-70b": {
          "name": "Llama 3 70B (Bedrock)",
          "maxTokens": 4096,
          "supportsTools": true,
          "supportsVision": false
        },
        "mistral-large": {
          "name": "Mistral Large (Bedrock)",
          "maxTokens": 8192,
          "supportsTools": true,
          "supportsVision": false
        }
      },
      "enabled": true
    }
  }
}
```

## Step 5: Verify

```bash
# Check LiteLLM exposes models
curl http://localhost:4000/v1/models

# Test Peekaboo provider connection
peekaboo config test-provider bedrock

# Discover available models
peekaboo config models-provider bedrock --refresh

# Run an agent task
peekaboo agent "take a screenshot" --model bedrock/claude-3-5-sonnet
```

## Notes

- **LiteLLM must stay running** for the provider to work. Use Docker `--restart=always` or a `launchd` plist for persistence.
- **`model_name`** in `litellm_config.yaml` is your custom alias; the `model` field is the actual Bedrock model ID.
- **Region matters**: Bedrock model availability varies by AWS region. Check the [Bedrock model access page](https://docs.aws.amazon.com/bedrock/latest/userguide/model-access.html).
- **Costs**: Bedrock usage is billed by AWS per token/request. LiteLLM itself is free.
- **Security**: The LiteLLM proxy listens on localhost by default. If you expose it on a network, configure a `master_key` in the LiteLLM config and use that as the `apiKey` in Peekaboo.

## Troubleshooting

| Symptom | Fix |
| --- | --- |
| `Connection refused` on port 4000 | LiteLLM not running — start it |
| `AccessDeniedException` from Bedrock | Check AWS profile has `bedrock:InvokeModel`; verify model access is enabled in console |
| `Model not found` in LiteLLM | Verify `model` field matches an actual Bedrock model ID for your region |
| Peekaboo says provider unreachable | Confirm `baseURL` ends with `/v1` and proxy health check passes |
| Slow first request | Bedrock cold-starts models on first invocation; subsequent calls are faster |

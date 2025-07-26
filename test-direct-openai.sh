#!/bin/bash

# Test OpenAI API directly with tools

# Get the API key
if [ -z "$OPENAI_API_KEY" ]; then
    echo "Error: OPENAI_API_KEY not set"
    exit 1
fi

echo "Testing OpenAI API with tools..."
echo

# Create a simple tool definition
TOOLS='[
  {
    "type": "function",
    "function": {
      "name": "list_apps",
      "description": "List all running applications",
      "parameters": {
        "type": "object",
        "properties": {},
        "required": []
      }
    }
  }
]'

# Create the request
REQUEST=$(cat <<EOF
{
  "model": "gpt-4o",
  "messages": [
    {
      "role": "system",
      "content": "You are a helpful assistant with access to tools."
    },
    {
      "role": "user",
      "content": "List all running applications"
    }
  ],
  "tools": $TOOLS,
  "temperature": 0.7
}
EOF
)

echo "Request:"
echo "$REQUEST" | jq .
echo

# Send the request
echo "Response:"
curl -s https://api.openai.com/v1/chat/completions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $OPENAI_API_KEY" \
  -d "$REQUEST" | jq .
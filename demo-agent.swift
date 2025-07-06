#!/usr/bin/env swift
// Simple demo showing the AI Agent concept

import Foundation

print("""
🤖 Peekaboo AI Agent Demo
========================

The Peekaboo AI Agent uses OpenAI's Assistants API to:

1. Understand natural language tasks like:
   - "Open TextEdit and write a poem"
   - "Take a screenshot of Safari"
   - "Click the login button"

2. Break them down into Peekaboo commands:
   - peekaboo see --app TextEdit
   - peekaboo click --on B1
   - peekaboo type "Hello World"

3. Execute them step by step with error handling

Example workflow for "Open TextEdit and write Hello":
""")

// Simulate the agent's thought process
let steps = [
    ("1. Check current screen state", "peekaboo see --mode frontmost"),
    ("2. Open TextEdit application", "peekaboo app launch TextEdit"),
    ("3. Wait for it to open", "peekaboo sleep 1000"),
    ("4. Capture TextEdit UI", "peekaboo see --app TextEdit"),
    ("5. Click in text area", "peekaboo click --on T1"),
    ("6. Type the text", "peekaboo type \"Hello\"")
]

for (description, command) in steps {
    print("\n\(description)")
    print("   → \(command)")
    Thread.sleep(forTimeInterval: 0.5)
}

print("""

To use the agent:

1. Set your OpenAI API key:
   export OPENAI_API_KEY="your-key"

2. Run natural language commands:
   peekaboo "Open Safari and search for weather"
   peekaboo agent "Take a screenshot of all windows"

The agent is perfect for:
- Complex multi-step automation
- Natural language control
- Error recovery and retries
- Visual verification of results

🎉 Happy automating!
""")
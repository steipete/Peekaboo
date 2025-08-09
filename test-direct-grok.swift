#!/usr/bin/env swift

import Foundation

let apiKey = ProcessInfo.processInfo.environment["X_AI_API_KEY"] ?? ProcessInfo.processInfo.environment["XAI_API_KEY"] ?? ""
guard !apiKey.isEmpty else {
    print("Error: X_AI_API_KEY or XAI_API_KEY not set")
    exit(1)
}

// Test with more tools to find the limit
let tools = (1...70).map { i in
    """
    {
        "type": "function",
        "function": {
            "name": "tool_\(i)",
            "description": "Tool number \(i) for testing",
            "parameters": {
                "type": "object",
                "properties": {
                    "input": {
                        "type": "string",
                        "description": "Input for tool \(i)"
                    }
                },
                "required": ["input"]
            }
        }
    }
    """
}

let toolsJson = "[" + tools.joined(separator: ",") + "]"

let body = """
{
    "model": "grok-3",
    "messages": [
        {"role": "user", "content": "Say hello"}
    ],
    "tools": \(toolsJson),
    "stream": true
}
"""

let url = URL(string: "https://api.x.ai/v1/chat/completions")!
var request = URLRequest(url: url)
request.httpMethod = "POST"
request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
request.setValue("application/json", forHTTPHeaderField: "Content-Type")
request.httpBody = body.data(using: .utf8)

print("🔵 Testing Grok-3 with 70 tools and streaming...")

let semaphore = DispatchSemaphore(value: 0)
var startTime = Date()

let task = URLSession.shared.dataTask(with: request) { data, response, error in
    let duration = Date().timeIntervalSince(startTime)
    print("Response received after \(String(format: "%.2f", duration))s")
    
    if let error = error {
        print("❌ Error: \(error)")
    } else if let httpResponse = response as? HTTPURLResponse {
        print("Response status: \(httpResponse.statusCode)")
        if let data = data {
            let responseText = String(data: data, encoding: .utf8) ?? ""
            print("Response (first 1000 chars): \(String(responseText.prefix(1000)))")
        }
    }
    semaphore.signal()
}

task.resume()

// Timeout after 30 seconds
if semaphore.wait(timeout: .now() + 30) == .timedOut {
    print("❌ Request timed out after 30 seconds")
    task.cancel()
    exit(1)
}
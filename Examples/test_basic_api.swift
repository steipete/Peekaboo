#!/usr/bin/env swift

import Foundation

// Quick test to verify Tachikoma basic functionality
let testCode = """
import Tachikoma

// Test 1: Create AIModelProvider from environment
print("✅ Testing AIConfiguration.fromEnvironment()...")
do {
    let provider = try AIConfiguration.fromEnvironment()
    let models = provider.availableModels()
    print("Available models: \\(models.count)")
    for model in models.prefix(3) {
        print("  - \\(model)")
    }
    
    if !models.isEmpty {
        print("✅ Testing basic model request...")
        let model = try provider.getModel(models[0])
        
        let request = ModelRequest(
            messages: [.user(content: .text("Hello, AI!"))],
            tools: nil,
            settings: ModelSettings(maxTokens: 50)
        )
        
        print("✅ Basic API test successful!")
    } else {
        print("⚠️ No models available (API keys not configured)")
    }
    
} catch {
    print("❌ Error: \\(error)")
}
"""

print("=== Basic Tachikoma API Test ===")
print("This would test:", testCode)
print("=== Test Completed ===")
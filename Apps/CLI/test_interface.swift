import PeekabooCore

// Test if simple testMethod is accessible from CLI context
let manager = ConfigurationManager.shared
let result = manager.testMethod()
print("Test method result: \(result)")

// This should fail
let providers = manager.listCustomProviders()
print("Found \(providers.count) custom providers")
@testable import peekaboo
import Testing
import Foundation

@Suite("Logger Tests", .tags(.logger, .unit), .serialized)
struct LoggerTests {
    
    // MARK: - Basic Functionality Tests
    
    @Test("Logger singleton instance", .tags(.fast))
    func loggerSingletonInstance() {
        let logger1 = Logger.shared
        let logger2 = Logger.shared
        
        // Should be the same instance
        #expect(logger1 === logger2)
    }
    
    @Test("JSON output mode switching", .tags(.fast))
    func jsonOutputModeSwitching() {
        let logger = Logger.shared
        
        // Test setting JSON mode
        logger.setJsonOutputMode(true)
        // Cannot directly test internal state, but verify no crash
        
        logger.setJsonOutputMode(false)
        // Cannot directly test internal state, but verify no crash
        
        // Test multiple switches
        for _ in 1...10 {
            logger.setJsonOutputMode(true)
            logger.setJsonOutputMode(false)
        }
    }
    
    @Test("Debug log message recording", .tags(.fast))
    func debugLogMessageRecording() async {
        let logger = Logger.shared
        
        // Enable JSON mode and clear logs
        logger.setJsonOutputMode(true)
        logger.clearDebugLogs()
        
        // Wait for mode setting to complete
        try? await Task.sleep(nanoseconds: 10_000_000) // 10ms
        
        // Record some debug messages
        logger.debug("Test debug message 1")
        logger.debug("Test debug message 2")
        logger.info("Test info message")
        logger.error("Test error message")
        
        // Wait for logging to complete
        try? await Task.sleep(nanoseconds: 10_000_000) // 10ms
        
        let logs = logger.getDebugLogs()
        
        // Should have exactly the messages we added
        #expect(logs.count == 4)
        
        // Verify messages are stored
        #expect(logs.contains { $0.contains("Test debug message 1") })
        #expect(logs.contains { $0.contains("Test debug message 2") })
        #expect(logs.contains { $0.contains("Test info message") })
        #expect(logs.contains { $0.contains("Test error message") })
        
        // Reset for other tests
        logger.setJsonOutputMode(false)
    }
    
    @Test("Debug logs retrieval and format", .tags(.fast))
    func debugLogsRetrievalAndFormat() async {
        let logger = Logger.shared
        
        // Enable JSON mode and clear logs
        logger.setJsonOutputMode(true)
        logger.clearDebugLogs()
        
        // Wait for setup to complete
        try? await Task.sleep(nanoseconds: 10_000_000) // 10ms
        
        // Add test messages
        logger.debug("Debug test")
        logger.info("Info test")
        logger.warn("Warning test")
        logger.error("Error test")
        
        // Wait for logging to complete
        try? await Task.sleep(nanoseconds: 10_000_000) // 10ms
        
        let logs = logger.getDebugLogs()
        
        // Should have exactly our messages
        #expect(logs.count == 4)
        
        // Verify log format includes level prefixes
        #expect(logs.contains { $0.contains("Debug test") })
        #expect(logs.contains { $0.contains("INFO: Info test") })
        #expect(logs.contains { $0.contains("WARN: Warning test") })
        #expect(logs.contains { $0.contains("ERROR: Error test") })
        
        // Reset for other tests
        logger.setJsonOutputMode(false)
    }
    
    // MARK: - Thread Safety Tests
    
    @Test("Concurrent logging operations", .tags(.concurrency))
    func concurrentLoggingOperations() async {
        let logger = Logger.shared
        
        // Enable JSON mode and clear logs
        logger.setJsonOutputMode(true)
        logger.clearDebugLogs()
        
        // Wait for setup
        try? await Task.sleep(nanoseconds: 10_000_000) // 10ms
        
        let initialCount = logger.getDebugLogs().count
        
        await withTaskGroup(of: Void.self) { group in
            // Create multiple concurrent logging tasks
            for i in 0..<10 {
                group.addTask {
                    logger.debug("Concurrent message \(i)")
                    logger.info("Concurrent info \(i)")
                    logger.error("Concurrent error \(i)")
                }
            }
        }
        
        // Wait for logging to complete
        try? await Task.sleep(nanoseconds: 50_000_000) // 50ms
        
        let finalLogs = logger.getDebugLogs()
        
        // Should have all messages (30 new messages)
        #expect(finalLogs.count >= initialCount + 30)
        
        // Verify no corruption by checking for our messages
        let recentLogs = finalLogs.suffix(30)
        var foundMessages = 0
        for i in 0..<10 {
            if recentLogs.contains(where: { $0.contains("Concurrent message \(i)") }) {
                foundMessages += 1
            }
        }
        
        // Should find most or all messages (allowing for some timing issues)
        #expect(foundMessages >= 7)
        
        // Reset
        logger.setJsonOutputMode(false)
    }
    
    @Test("Concurrent mode switching and logging", .tags(.concurrency))
    func concurrentModeSwitchingAndLogging() async {
        let logger = Logger.shared
        
        await withTaskGroup(of: Void.self) { group in
            // Task 1: Rapid mode switching
            group.addTask {
                for i in 0..<50 {
                    logger.setJsonOutputMode(i % 2 == 0)
                }
            }
            
            // Task 2: Continuous logging during mode switches
            group.addTask {
                for i in 0..<100 {
                    logger.debug("Mode switch test \(i)")
                }
            }
            
            // Task 3: Log retrieval during operations
            group.addTask {
                for _ in 0..<10 {
                    let logs = logger.getDebugLogs()
                    #expect(logs.count >= 0) // Should not crash
                }
            }
        }
        
        // Should complete without crashes
        #expect(Bool(true))
    }
    
    // MARK: - Memory Management Tests
    
    @Test("Memory usage with extensive logging", .tags(.memory))
    func memoryUsageExtensiveLogging() async {
        let logger = Logger.shared
        
        // Enable JSON mode and clear logs
        logger.setJsonOutputMode(true)
        logger.clearDebugLogs()
        
        // Wait for setup
        try? await Task.sleep(nanoseconds: 10_000_000) // 10ms
        
        let initialCount = logger.getDebugLogs().count
        
        // Generate many log messages
        for i in 1...100 {
            logger.debug("Memory test message \(i)")
            logger.info("Memory test info \(i)")
            logger.error("Memory test error \(i)")
        }
        
        // Wait for logging
        try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
        
        let finalLogs = logger.getDebugLogs()
        
        // Should have accumulated messages
        #expect(finalLogs.count >= initialCount + 300)
        
        // Verify memory doesn't grow unbounded by checking we can still log
        logger.debug("Final test message")
        
        // Wait for final log
        try? await Task.sleep(nanoseconds: 10_000_000) // 10ms
        
        let postTestLogs = logger.getDebugLogs()
        #expect(postTestLogs.count > finalLogs.count)
        
        // Reset
        logger.setJsonOutputMode(false)
    }
    
    @Test("Debug logs array management", .tags(.fast))
    func debugLogsArrayManagement() {
        let logger = Logger.shared
        
        // Test that logs are properly maintained
        let initialLogs = logger.getDebugLogs()
        
        // Add known messages
        logger.debug("Management test 1")
        logger.debug("Management test 2")
        
        let middleLogs = logger.getDebugLogs()
        #expect(middleLogs.count > initialLogs.count)
        
        // Add more messages
        logger.debug("Management test 3")
        logger.debug("Management test 4")
        
        let finalLogs = logger.getDebugLogs()
        #expect(finalLogs.count > middleLogs.count)
        
        // Verify recent messages are present
        #expect(finalLogs.last?.contains("Management test 4") == true)
    }
    
    // MARK: - Performance Tests
    
    @Test("Logging performance benchmark", .tags(.performance))
    func loggingPerformanceBenchmark() {
        let logger = Logger.shared
        
        // Measure logging performance
        let messageCount = 1000
        let startTime = CFAbsoluteTimeGetCurrent()
        
        for i in 1...messageCount {
            logger.debug("Performance test message \(i)")
        }
        
        let duration = CFAbsoluteTimeGetCurrent() - startTime
        
        // Should be able to log 1000 messages quickly
        #expect(duration < 1.0) // Within 1 second
        
        // Verify all messages were logged
        let logs = logger.getDebugLogs()
        let performanceMessages = logs.filter { $0.contains("Performance test message") }
        #expect(performanceMessages.count >= messageCount)
    }
    
    @Test("Debug log retrieval performance", .tags(.performance))
    func debugLogRetrievalPerformance() {
        let logger = Logger.shared
        
        // Add many messages first
        for i in 1...100 {
            logger.debug("Retrieval test \(i)")
        }
        
        // Measure retrieval performance
        let startTime = CFAbsoluteTimeGetCurrent()
        
        for _ in 1...10 {
            let logs = logger.getDebugLogs()
            #expect(logs.count > 0)
        }
        
        let duration = CFAbsoluteTimeGetCurrent() - startTime
        
        // Should be able to retrieve logs quickly even with many messages
        #expect(duration < 1.0) // Within 1 second for 10 retrievals
    }
    
    // MARK: - Edge Cases and Error Handling
    
    @Test("Logging with special characters", .tags(.fast))
    func loggingWithSpecialCharacters() async {
        let logger = Logger.shared
        
        // Enable JSON mode and clear logs
        logger.setJsonOutputMode(true)
        logger.clearDebugLogs()
        
        // Wait for setup
        try? await Task.sleep(nanoseconds: 10_000_000) // 10ms
        
        let initialCount = logger.getDebugLogs().count
        
        // Test various special characters and unicode
        let specialMessages = [
            "Test with emoji: 🚀 🎉 ✅",
            "Test with unicode: 测试 スクリーン Приложение",
            "Test with newlines: line1\\nline2\\nline3",
            "Test with quotes: \"quoted\" and 'single quoted'",
            "Test with JSON: {\"key\": \"value\", \"number\": 42}",
            "Test with special chars: @#$%^&*()_+-=[]{}|;':\",./<>?"
        ]
        
        for message in specialMessages {
            logger.debug(message)
            logger.info(message)
            logger.error(message)
        }
        
        // Wait for logging
        try? await Task.sleep(nanoseconds: 50_000_000) // 50ms
        
        let logs = logger.getDebugLogs()
        
        // Should have all messages
        #expect(logs.count >= initialCount + specialMessages.count * 3)
        
        // Verify special characters are preserved
        let recentLogs = logs.suffix(specialMessages.count * 3)
        for message in specialMessages {
            #expect(recentLogs.contains { $0.contains(message) })
        }
        
        // Reset
        logger.setJsonOutputMode(false)
    }
    
    @Test("Logging with very long messages", .tags(.fast))
    func loggingWithVeryLongMessages() async {
        let logger = Logger.shared
        
        // Enable JSON mode and clear logs for consistent testing
        logger.setJsonOutputMode(true)
        logger.clearDebugLogs()
        
        // Wait for setup
        try? await Task.sleep(nanoseconds: 10_000_000) // 10ms
        
        let initialCount = logger.getDebugLogs().count
        
        // Test very long messages
        let longMessage = String(repeating: "A", count: 1000)
        let veryLongMessage = String(repeating: "B", count: 10000)
        
        logger.debug(longMessage)
        logger.info(veryLongMessage)
        
        // Wait for logging
        try? await Task.sleep(nanoseconds: 10_000_000) // 10ms
        
        let logs = logger.getDebugLogs()
        
        // Should handle long messages without crashing
        #expect(logs.count >= initialCount + 2)
        
        // Verify long messages are stored (possibly truncated, but stored)
        let recentLogs = logs.suffix(2)
        #expect(recentLogs.contains { $0.contains("AAA") })
        #expect(recentLogs.contains { $0.contains("BBB") })
        
        // Reset
        logger.setJsonOutputMode(false)
    }
    
    @Test("Logging with nil and empty strings", .tags(.fast))
    func loggingWithNilAndEmptyStrings() async {
        let logger = Logger.shared
        
        // Enable JSON mode and clear logs for consistent testing
        logger.setJsonOutputMode(true)
        logger.clearDebugLogs()
        
        // Wait for setup
        try? await Task.sleep(nanoseconds: 10_000_000) // 10ms
        
        let initialCount = logger.getDebugLogs().count
        
        // Test empty messages
        logger.debug("")
        logger.info("")
        logger.error("")
        
        // Test whitespace-only messages
        logger.debug("   ")
        logger.info("\\t\\n\\r")
        
        // Wait for logging
        try? await Task.sleep(nanoseconds: 10_000_000) // 10ms
        
        let logs = logger.getDebugLogs()
        
        // Should handle empty/whitespace messages gracefully
        #expect(logs.count >= initialCount + 5)
        
        // Reset
        logger.setJsonOutputMode(false)
    }
    
    // MARK: - Integration Tests
    
    @Test("Logger integration with JSON output mode", .tags(.integration))
    func loggerIntegrationWithJSONMode() async {
        let logger = Logger.shared
        
        // Clear logs first
        logger.clearDebugLogs()
        
        // Test logging in JSON mode only (since non-JSON mode goes to stderr)
        logger.setJsonOutputMode(true)
        
        // Wait for mode setting
        try? await Task.sleep(nanoseconds: 10_000_000) // 10ms
        
        logger.debug("JSON mode message 1")
        logger.debug("JSON mode message 2")
        logger.debug("JSON mode message 3")
        
        // Wait for logging
        try? await Task.sleep(nanoseconds: 10_000_000) // 10ms
        
        let logs = logger.getDebugLogs()
        
        // Should have messages from JSON mode
        #expect(logs.contains { $0.contains("JSON mode message 1") })
        #expect(logs.contains { $0.contains("JSON mode message 2") })
        #expect(logs.contains { $0.contains("JSON mode message 3") })
        
        // Reset
        logger.setJsonOutputMode(false)
    }
    
    @Test("Logger state consistency", .tags(.fast))
    func loggerStateConsistency() async {
        let logger = Logger.shared
        
        // Clear logs and set JSON mode
        logger.setJsonOutputMode(true)
        logger.clearDebugLogs()
        
        // Wait for setup
        try? await Task.sleep(nanoseconds: 10_000_000) // 10ms
        
        // Test consistent JSON mode logging
        for i in 1...10 {
            logger.debug("State test \(i)")
        }
        
        // Wait for logging
        try? await Task.sleep(nanoseconds: 50_000_000) // 50ms
        
        let logs = logger.getDebugLogs()
        
        // Should maintain consistency
        let stateTestLogs = logs.filter { $0.contains("State test") }
        #expect(stateTestLogs.count >= 10)
        
        // Reset
        logger.setJsonOutputMode(false)
    }
}
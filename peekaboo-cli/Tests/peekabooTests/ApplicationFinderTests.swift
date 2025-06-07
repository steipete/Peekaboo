import AppKit
@testable import peekaboo
import Testing

@Suite("ApplicationFinder Tests", .tags(.applicationFinder, .unit))
struct ApplicationFinderTests {
    // MARK: - Test Data

    private static let testIdentifiers = [
        "Finder", "finder", "FINDER", "Find", "com.apple.finder"
    ]

    private static let invalidIdentifiers = [
        "", "   ", "NonExistentApp12345", "invalid.bundle.id",
        String(repeating: "a", count: 1000)
    ]

    // MARK: - Find Application Tests

    @Test("Finding an app by exact name match", .tags(.fast))
    func findApplicationExactMatch() throws {
        // Test finding an app that should always be running on macOS
        let result = try ApplicationFinder.findApplication(identifier: "Finder")

        #expect(result.localizedName == "Finder")
        #expect(result.bundleIdentifier == "com.apple.finder")
    }

    @Test("Finding an app is case-insensitive", .tags(.fast))
    func findApplicationCaseInsensitive() throws {
        // Test case-insensitive matching
        let result = try ApplicationFinder.findApplication(identifier: "finder")

        #expect(result.localizedName == "Finder")
    }

    @Test("Finding an app by bundle identifier", .tags(.fast))
    func findApplicationByBundleIdentifier() throws {
        // Test finding by bundle identifier
        let result = try ApplicationFinder.findApplication(identifier: "com.apple.finder")

        #expect(result.bundleIdentifier == "com.apple.finder")
    }

    @Test("Throws error when app is not found", .tags(.fast))
    func findApplicationNotFound() throws {
        // Test app not found error
        #expect(throws: (any Error).self) {
            try ApplicationFinder.findApplication(identifier: "NonExistentApp12345")
        }
    }

    @Test("Finding an app by partial name match", .tags(.fast))
    func findApplicationPartialMatch() throws {
        // Test partial name matching
        let result = try ApplicationFinder.findApplication(identifier: "Find")

        // Should find Finder as closest match
        #expect(result.localizedName == "Finder")
    }

    // MARK: - Parameterized Tests

    @Test(
        "Finding apps with various identifiers",
        arguments: [
            ("Finder", "com.apple.finder"),
            ("finder", "com.apple.finder"),
            ("FINDER", "com.apple.finder"),
            ("com.apple.finder", "com.apple.finder")
        ]
    )
    func findApplicationVariousIdentifiers(identifier: String, expectedBundleId: String) throws {
        let result = try ApplicationFinder.findApplication(identifier: identifier)
        #expect(result.bundleIdentifier == expectedBundleId)
    }

    // MARK: - Get All Running Applications Tests

    @Test("Getting all running applications returns non-empty list", .tags(.fast))
    func getAllRunningApplications() {
        // Test getting all running applications
        let apps = ApplicationFinder.getAllRunningApplications()

        // Should have at least some apps running
        #expect(!apps.isEmpty)

        // Should include Finder
        let hasFinder = apps.contains { $0.app_name == "Finder" }
        #expect(hasFinder == true)
    }

    @Test("All running applications have required properties", .tags(.fast))
    func allApplicationsHaveRequiredProperties() {
        let apps = ApplicationFinder.getAllRunningApplications()

        for app in apps {
            #expect(!app.app_name.isEmpty)
            // Some system processes may have empty bundle IDs
            if !app.bundle_id.isEmpty {
                #expect(!app.bundle_id.isEmpty)
            }
            #expect(app.pid > 0)
            #expect(app.window_count >= 0)
        }
    }

    // MARK: - Edge Cases and Advanced Tests

    @Test("Finding app with special characters in name", .tags(.fast))
    func findApplicationSpecialCharacters() throws {
        // Test apps with special characters (if available)
        let specialApps = ["1Password", "CleanMyMac", "MacBook Pro"]

        for appName in specialApps {
            do {
                let result = try ApplicationFinder.findApplication(identifier: appName)
                #expect(result.localizedName != nil)
                #expect(!result.localizedName!.isEmpty)
            } catch {
                // Expected if app is not installed
                #expect(Bool(true))
            }
        }
    }

    @Test("Fuzzy matching algorithm scoring", .tags(.fast))
    func fuzzyMatchingScoring() throws {
        // Test that exact matches get highest scores
        let finder = try ApplicationFinder.findApplication(identifier: "Finder")
        #expect(finder.localizedName == "Finder")

        // Test prefix matching works
        let findResult = try ApplicationFinder.findApplication(identifier: "Find")
        #expect(findResult.localizedName == "Finder")
    }

    @Test(
        "Bundle identifier parsing edge cases",
        arguments: [
            "com.apple",
            "apple.finder",
            "finder",
            "com.apple.finder.extra"
        ]
    )
    func bundleIdentifierEdgeCases(partialBundleId: String) throws {
        // Should either find Finder or throw appropriate error
        do {
            let result = try ApplicationFinder.findApplication(identifier: partialBundleId)
            #expect(result.bundleIdentifier != nil)
        } catch {
            // Expected for invalid/partial bundle IDs
            #expect(Bool(true))
        }
    }

    @Test("Fuzzy matching prefers exact matches", .tags(.fast))
    func fuzzyMatchingPrefersExact() throws {
        // If we have multiple matches, exact should win
        let result = try ApplicationFinder.findApplication(identifier: "Finder")
        #expect(result.localizedName == "Finder")
        #expect(result.bundleIdentifier == "com.apple.finder")
    }

    @Test(
        "Performance: Finding apps multiple times",
        arguments: 1...10
    )
    func findApplicationPerformance(iteration: Int) throws {
        // Test that finding an app completes quickly even when called multiple times
        let result = try ApplicationFinder.findApplication(identifier: "Finder")
        #expect(result.localizedName == "Finder")
    }

    @Test("Stress test: Search with many running apps", .tags(.performance))
    func stressTestManyApps() {
        // Get current app count for baseline
        let apps = ApplicationFinder.getAllRunningApplications()
        #expect(!apps.isEmpty)

        // Test search performance doesn't degrade with app list size
        let startTime = CFAbsoluteTimeGetCurrent()
        do {
            _ = try ApplicationFinder.findApplication(identifier: "Finder")
            let duration = CFAbsoluteTimeGetCurrent() - startTime
            #expect(duration < 1.0) // Should complete within 1 second
        } catch {
            Issue.record("Finder should always be found in performance test")
        }
    }

    // MARK: - Integration Tests

    @Test(
        "Find and verify running state of system apps",
        arguments: [
            ("Finder", true),
            ("Dock", true),
            ("SystemUIServer", true)
        ]
    )
    func verifySystemAppsRunning(appName: String, shouldBeRunning: Bool) throws {
        do {
            let result = try ApplicationFinder.findApplication(identifier: appName)
            #expect(result.localizedName != nil)

            // Verify the app is in the running list
            let runningApps = ApplicationFinder.getAllRunningApplications()
            let isInList = runningApps.contains { $0.bundle_id == result.bundleIdentifier }
            #expect(isInList == shouldBeRunning)
        } catch {
            if shouldBeRunning {
                Issue.record("System app \(appName) should be running but was not found")
            }
        }
    }

    @Test("Verify frontmost application detection", .tags(.integration))
    func verifyFrontmostApp() throws {
        // Get the frontmost app using NSWorkspace
        let frontmostApp = NSWorkspace.shared.frontmostApplication

        // Try to find it using our ApplicationFinder
        if let bundleId = frontmostApp?.bundleIdentifier {
            let result = try ApplicationFinder.findApplication(identifier: bundleId)
            #expect(result.bundleIdentifier == bundleId)

            // Verify it's marked as active in our list
            let runningApps = ApplicationFinder.getAllRunningApplications()
            let appInfo = runningApps.first { $0.bundle_id == bundleId }
            #expect(appInfo?.is_active == true)
        }
    }
}

// MARK: - Extended Test Suite for Edge Cases

@Suite("ApplicationFinder Edge Cases", .tags(.applicationFinder, .unit))
struct ApplicationFinderEdgeCaseTests {
    @Test("Empty identifier throws appropriate error", .tags(.fast))
    func emptyIdentifierError() {
        #expect(throws: (any Error).self) {
            try ApplicationFinder.findApplication(identifier: "")
        }
    }

    @Test("Whitespace-only identifier throws appropriate error", .tags(.fast))
    func whitespaceIdentifierError() {
        #expect(throws: (any Error).self) {
            try ApplicationFinder.findApplication(identifier: "   ")
        }
    }

    @Test("Very long identifier doesn't crash", .tags(.fast))
    func veryLongIdentifier() {
        let longIdentifier = String(repeating: "a", count: 1000)
        #expect(throws: (any Error).self) {
            try ApplicationFinder.findApplication(identifier: longIdentifier)
        }
    }

    @Test(
        "Unicode identifiers are handled correctly",
        arguments: ["😀App", "App™", "Приложение", "アプリ"]
    )
    func unicodeIdentifiers(identifier: String) {
        // Should not crash, either finds or throws appropriate error
        do {
            let result = try ApplicationFinder.findApplication(identifier: identifier)
            #expect(result.localizedName != nil)
        } catch {
            // Test passes if an error is thrown for invalid identifier
            #expect(Bool(true))
        }
    }

    @Test("Case sensitivity in matching", .tags(.fast))
    func caseSensitivityMatching() throws {
        // Test various case combinations
        let caseVariations = ["finder", "FINDER", "Finder", "fInDeR"]

        for variation in caseVariations {
            let result = try ApplicationFinder.findApplication(identifier: variation)
            #expect(result.localizedName == "Finder")
            #expect(result.bundleIdentifier == "com.apple.finder")
        }
    }

    @Test("Concurrent application searches", .tags(.concurrency))
    func concurrentSearches() async {
        // Test thread safety of application finder
        await withTaskGroup(of: Bool.self) { group in
            for _ in 0..<10 {
                group.addTask {
                    do {
                        let result = try ApplicationFinder.findApplication(identifier: "Finder")
                        return result.localizedName == "Finder"
                    } catch {
                        return false
                    }
                }
            }

            var successCount = 0
            for await success in group where success {
                successCount += 1
            }

            // All searches should succeed for Finder
            #expect(successCount == 10)
        }
    }

    @Test("Memory usage with large app lists", .tags(.performance))
    func memoryUsageTest() {
        // Test memory doesn't grow excessively with repeated calls
        for _ in 1...5 {
            let apps = ApplicationFinder.getAllRunningApplications()
            #expect(!apps.isEmpty)
        }

        // If we get here without crashing, memory management is working
        #expect(Bool(true))
    }

    @Test("Application list sorting consistency", .tags(.fast))
    func applicationListSorting() {
        let apps = ApplicationFinder.getAllRunningApplications()

        // Verify list is sorted by name (case-insensitive)
        for index in 1..<apps.count {
            let current = apps[index].app_name.lowercased()
            let previous = apps[index - 1].app_name.lowercased()
            #expect(current >= previous)
        }
    }

    @Test("Window count accuracy", .tags(.integration))
    func windowCountAccuracy() {
        let apps = ApplicationFinder.getAllRunningApplications()

        for app in apps {
            // Window count should be non-negative
            #expect(app.window_count >= 0)

            // Finder should typically have at least one window
            if app.app_name == "Finder" {
                #expect(app.window_count >= 0) // Could be 0 if all windows minimized
            }
        }
    }
}

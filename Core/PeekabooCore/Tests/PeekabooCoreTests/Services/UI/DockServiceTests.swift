//
//  DockServiceTests.swift
//  PeekabooCore
//

import CoreGraphics
import Foundation
import Testing
@testable import PeekabooCore
@testable import PeekabooAutomation
@testable import PeekabooAgentRuntime
@testable import PeekabooVisualizer

@Suite("Dock Service Tests")
struct DockServiceTests {
    @Test("List dock items")
    @MainActor
    func testListDockItems() async throws {
        let service = DockService()

        // List without separators
        let items = try await service.listDockItems(includeAll: false)

        // Should have at least Finder and Trash
        #expect(items.count >= 2)

        // Check for Finder
        let finderItem = items.first { $0.title.lowercased().contains("finder") }
        #expect(finderItem != nil)
        #expect(finderItem?.itemType == .application)
        #expect(finderItem?.isRunning == true) // Finder is always running

        // Check for Trash
        let trashItem = items.first { $0.title.lowercased().contains("trash") || $0.title.lowercased().contains("bin") }
        #expect(trashItem != nil)
        #expect(trashItem?.itemType == .trash)
    }

    @Test("List dock items with all")
    @MainActor
    func listDockItemsIncludeAll() async throws {
        let service = DockService()

        // List with separators
        let allItems = try await service.listDockItems(includeAll: true)
        let filteredItems = try await service.listDockItems(includeAll: false)

        // Should have more items when including all
        #expect(allItems.count >= filteredItems.count)

        // Check if we have any separators when including all
        let hasSeparators = allItems.contains { $0.itemType == .separator }
        // Note: This might be false if user has no separators configured
        _ = hasSeparators // Just checking, not asserting
    }

    @Test("Find dock item")
    @MainActor
    func testFindDockItem() async throws {
        let service = DockService()

        // Find Finder (should always exist)
        let finderItem = try await service.findDockItem(name: "Finder")
        #expect(finderItem.title.lowercased().contains("finder"))
        #expect(finderItem.itemType == .application)

        // Test case-insensitive search
        let finderLowercase = try await service.findDockItem(name: "finder")
        #expect(finderLowercase.title.lowercased().contains("finder"))

        // Test partial match
        let finderPartial = try await service.findDockItem(name: "Find")
        #expect(finderPartial.title.lowercased().contains("find"))
    }

    @Test("Find non-existent dock item")
    @MainActor
    func findNonExistentDockItem() async throws {
        let service = DockService()

        do {
            _ = try await service.findDockItem(name: "NonExistentApp12345")
            Issue.record("Should have thrown error for non-existent item")
        } catch {
            // Expected to throw
            #expect(error is PeekabooError)
        }
    }

    @Test("Check dock auto-hide state")
    @MainActor
    func dockAutoHideState() async throws {
        let service = DockService()

        // Get current state
        let initialState = await service.isDockAutoHidden()

        // Toggle state
        if initialState {
            try await service.showDock()
            let newState = await service.isDockAutoHidden()
            #expect(newState == false)

            // Restore original state
            try await service.hideDock()
        } else {
            try await service.hideDock()
            let newState = await service.isDockAutoHidden()
            #expect(newState == true)

            // Restore original state
            try await service.showDock()
        }

        // Verify restoration
        let finalState = await service.isDockAutoHidden()
        #expect(finalState == initialState)
    }

    @Test("Add and remove from dock")
    @MainActor
    func addAndRemoveFromDock() async throws {
        let service = DockService()

        // Use Calculator as test app (should exist on all Macs)
        let testAppPath = "/System/Applications/Calculator.app"

        // Check if Calculator exists
        guard FileManager.default.fileExists(atPath: testAppPath) else {
            throw Issue.record("Calculator app not found at expected path")
        }

        // Get initial dock items
        let initialItems = try await service.listDockItems(includeAll: false)
        let calculatorExists = initialItems.contains { $0.title.lowercased().contains("calculator") }

        if !calculatorExists {
            // Add Calculator to dock
            try await service.addToDock(path: testAppPath, persistent: true)

            // Wait for dock to update
            try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second

            // Verify it was added
            let newItems = try await service.listDockItems(includeAll: false)
            let addedItem = newItems.first { $0.title.lowercased().contains("calculator") }
            #expect(addedItem != nil)

            // Remove it
            try await service.removeFromDock(appName: "Calculator")

            // Wait for dock to update
            try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second

            // Verify it was removed
            let finalItems = try await service.listDockItems(includeAll: false)
            let removedItem = finalItems.first { $0.title.lowercased().contains("calculator") }
            #expect(removedItem == nil)
        } else {
            // Calculator already in dock, skip test
            Issue.record("Calculator already in dock, skipping add/remove test")
        }
    }

    @Test("Launch from dock")
    @MainActor
    func testLaunchFromDock() async throws {
        let service = DockService()

        // Find an app that's in the dock but not running
        let items = try await service.listDockItems(includeAll: false)

        // Find a non-running app (skip Finder as it's always running)
        guard let targetItem = items.first(where: { item in
            item.itemType == .application &&
                item.isRunning == false &&
                !item.title.lowercased().contains("finder")
        }) else {
            Issue.record("No non-running apps found in dock to test launch")
            return
        }

        // Launch the app
        try await service.launchFromDock(appName: targetItem.title)

        // Wait for launch
        try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds

        // Check if it's now running
        let updatedItems = try await service.listDockItems(includeAll: false)
        let launchedItem = updatedItems.first { $0.title == targetItem.title }

        // Note: isRunning might not update immediately, so we just check launch didn't error
        #expect(launchedItem != nil)
    }

    @Test("Right-click dock item")
    @MainActor
    func testRightClickDockItem() async throws {
        let service = DockService()

        // Right-click Finder (always available)
        // Just test that right-click doesn't throw an error
        try await service.rightClickDockItem(appName: "Finder", menuItem: nil)

        // Give time for any menu to dismiss
        try await Task.sleep(nanoseconds: 500_000_000) // 500ms

        // We can't easily test clicking menu items without side effects
        // so we just verify the right-click operation succeeded
        #expect(true) // If we got here, test passed
    }

    @Test("Dock item properties")
    @MainActor
    func dockItemProperties() async throws {
        let service = DockService()

        let items = try await service.listDockItems(includeAll: false)

        for item in items {
            // Check required properties
            #expect(item.index >= 0)
            #expect(!item.title.isEmpty || item.itemType == .separator)

            // Applications should have bundle identifiers
            if item.itemType == .application, item.title.lowercased().contains("finder") {
                #expect(item.bundleIdentifier == "com.apple.finder")
            }

            // Items should have valid positions (unless they're hidden)
            if let position = item.position {
                #expect(position.x >= 0)
                #expect(position.y >= 0)
            }

            // Items should have valid sizes (unless they're hidden)
            if let size = item.size {
                #expect(size.width > 0)
                #expect(size.height > 0)
            }
        }
    }
}

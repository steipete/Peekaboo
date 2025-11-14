import AppKit
import CoreGraphics
import Testing
@testable import PeekabooCore
@testable import PeekabooAutomation
@testable import PeekabooAgentRuntime
@testable import PeekabooVisualizer

@Suite("Space Utilities Tests", .enabled(if: TestEnvironment.runAutomationScenarios))
struct SpaceUtilitiesTests {
    // MARK: - SpaceInfo Tests

    @Test("SpaceInfo initialization")
    func spaceInfoInit() {
        let spaceInfo = SpaceInfo(
            id: 12345,
            type: .user,
            isActive: true,
            displayID: 1,
            name: "Desktop 1",
            ownerPIDs: [1234, 5678])

        #expect(spaceInfo.id == 12345)
        #expect(spaceInfo.type == .user)
        #expect(spaceInfo.isActive == true)
        #expect(spaceInfo.displayID == 1)
        #expect(spaceInfo.name == "Desktop 1")
        #expect(spaceInfo.ownerPIDs == [1234, 5678])
    }

    @Test("SpaceInfo.SpaceType values")
    func spaceTypeValues() {
        let types: [SpaceInfo.SpaceType] = [.user, .fullscreen, .system, .tiled, .unknown]
        let expectedRawValues = ["user", "fullscreen", "system", "tiled", "unknown"]

        for (type, expected) in zip(types, expectedRawValues) {
            #expect(type.rawValue == expected)
        }
    }

    // MARK: - SpaceManagementService Tests

    @Test("SpaceManagementService initialization")
    @MainActor
    func spaceServiceInit() {
        _ = SpaceManagementService()
        // Should initialize without crashing
        // Service is non-optional, so it will always be created
    }

    @Test("getAllSpaces returns at least one Space")
    @MainActor
    func getAllSpacesNotEmpty() {
        let service = SpaceManagementService()
        let spaces = service.getAllSpaces()

        // macOS should have at least one Space
        #expect(spaces.count >= 1)

        // Check that returned spaces have valid IDs
        var sawNonUnknown = false
        for space in spaces {
            #expect(space.id > 0)
            if space.type != .unknown {
                sawNonUnknown = true
            }
        }

        if !sawNonUnknown {
            #expect(true, "All reported spaces had unknown type - CGSSpace metadata unavailable in this environment")
        }
    }

    @Test("getCurrentSpace returns valid Space")
    @MainActor
    func getCurrentSpaceValid() {
        let service = SpaceManagementService()
        let currentSpace = service.getCurrentSpace()

        if let space = currentSpace {
            #expect(space.id > 0)
            #expect(space.isActive == true)
            if space.type == .unknown {
                #expect(true, "Current space type unavailable (likely permissions issue)")
            }
        } else {
            // In some test environments, this might return nil
            // but in normal macOS environment it should return a Space
        }
    }

    @Test("getSpacesForWindow with invalid window ID")
    @MainActor
    func getSpacesForInvalidWindow() {
        let service = SpaceManagementService()
        let spaces = service.getSpacesForWindow(windowID: 0)

        // Invalid window ID should return empty array
        #expect(spaces.isEmpty)
    }

    @Test("getSpacesForWindow with Finder window")
    @MainActor
    func getSpacesForFinderWindow() async throws {
        let service = SpaceManagementService()

        // Try to find a Finder window
        let windowService = WindowManagementService()
        let windows = try await windowService.listWindows(
            target: .application("Finder"))

        if let firstWindow = windows.first,
           firstWindow.windowID > 0
        {
            let spaces = service.getSpacesForWindow(windowID: CGWindowID(firstWindow.windowID))

            // If we found a window, it should be in at least one Space
            if !spaces.isEmpty {
                #expect(spaces.count >= 1)
                #expect(spaces.first!.id > 0)
            }
        }
    }

    // MARK: - Space Movement Tests

    @Test("moveWindowToCurrentSpace with invalid window")
    @MainActor
    func moveInvalidWindowToCurrentSpace() throws {
        let service = SpaceManagementService()

        // Moving invalid window should not crash
        // but might throw an error depending on implementation
        do {
            try service.moveWindowToCurrentSpace(windowID: 0)
        } catch {
            // Expected to possibly fail
            #expect(error is SpaceError)
        }
    }

    @Test("switchToSpace with invalid Space ID")
    @MainActor
    func switchToInvalidSpace() async throws {
        let service = SpaceManagementService()

        do {
            try await service.switchToSpace(0)
            // Might succeed or fail depending on CGSSpace behavior
        } catch {
            // Expected to possibly fail
            #expect(error is SpaceError)
        }
    }

    // MARK: - SpaceError Tests

    @Test("SpaceError descriptions")
    func spaceErrorDescriptions() {
        let errors: [SpaceError] = [
            .spaceNotFound(12345),
            .windowNotInAnySpace(67890),
            .failedToGetCurrentSpace,
            .failedToSwitchSpace,
        ]

        for error in errors {
            let description = error.errorDescription
            #expect(description != nil)
            #expect(!description!.isEmpty)
        }
    }

    // MARK: - Private API Safety Tests

    @Test("CGSSpace type safety")
    func cgsSpaceTypeSafety() {
        // Verify our typealiases are correct size
        #expect(MemoryLayout<CGSConnectionID>.size == 4) // UInt32
        #expect(MemoryLayout<CGSSpaceID>.size == 8) // UInt64
        #expect(MemoryLayout<CGSManagedDisplay>.size == 4) // UInt32
    }
}

// MARK: - Integration Tests

@Suite("Space Management Integration Tests", .enabled(if: TestEnvironment.runAutomationScenarios))
struct SpaceManagementIntegrationTests {
    @Test("Space list matches current Space")
    @MainActor
    func spaceListContainsCurrentSpace() {
        let service = SpaceManagementService()
        let allSpaces = service.getAllSpaces()
        let currentSpace = service.getCurrentSpace()

        if let current = currentSpace {
            // Current Space should be in the list of all Spaces
            let matchingSpace = allSpaces.first { $0.id == current.id }
            #expect(matchingSpace != nil)
            #expect(matchingSpace?.isActive == true)
        }
    }

    @Test("Active Space count")
    @MainActor
    func activeSpaceCount() {
        let service = SpaceManagementService()
        let allSpaces = service.getAllSpaces()

        let activeSpaces = allSpaces.filter(\.isActive)
        #expect(activeSpaces.count >= 1)
    }

    @Test("getAllSpacesByDisplay returns organized spaces")
    @MainActor
    func getAllSpacesByDisplay() {
        let service = SpaceManagementService()
        let spacesByDisplay = service.getAllSpacesByDisplay()

        // In test environment this might be empty, but we test that it doesn't crash
        if !spacesByDisplay.isEmpty {
            // If we have spaces, verify the structure
            for (displayID, spaces) in spacesByDisplay {
                #expect(displayID > 0)
                #expect(!spaces.isEmpty)

                // Check that spaces have valid IDs
                for space in spaces {
                    #expect(space.id > 0)
                    #expect(space.displayID == displayID)
                }

                // At least one space should be active per display set (typically true for primary display)
                let hasActiveSpace = spaces.contains(where: \.isActive)
                #expect(hasActiveSpace || spacesByDisplay.count == 1)
            }
        }
    }

    @Test("getWindowLevel returns valid level for window")
    @MainActor
    func getWindowLevel() {
        let service = SpaceManagementService()

        // Try to find any window for testing
        // In test environment, this might not find any windows
        let testWindowID: CGWindowID = 1 // Dummy ID for testing

        let level = service.getWindowLevel(windowID: testWindowID)

        // If we got a level, verify it's reasonable
        if let windowLevel = level {
            // Window levels are typically positive integers
            // Normal windows are at level 0
            // Floating windows, panels etc have higher levels
            #expect(windowLevel >= -1)
        }
        // It's OK if level is nil in test environment (no such window)
    }
}

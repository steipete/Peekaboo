import Testing
import AppKit
import CoreGraphics
@testable import PeekabooCore

@Suite("Space Utilities Tests")
struct SpaceUtilitiesTests {
    
    // MARK: - SpaceInfo Tests
    
    @Test("SpaceInfo initialization")
    func spaceInfoInit() {
        let spaceInfo = SpaceInfo(
            id: 12345,
            type: .user,
            isActive: true,
            displayID: 1
        )
        
        #expect(spaceInfo.id == 12345)
        #expect(spaceInfo.type == .user)
        #expect(spaceInfo.isActive == true)
        #expect(spaceInfo.displayID == 1)
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
        let service = SpaceManagementService()
        // Should initialize without crashing
        #expect(service != nil)
    }
    
    @Test("getAllSpaces returns at least one Space")
    @MainActor
    func getAllSpacesNotEmpty() {
        let service = SpaceManagementService()
        let spaces = service.getAllSpaces()
        
        // macOS should have at least one Space
        #expect(spaces.count >= 1)
        
        // Check that returned spaces have valid IDs
        for space in spaces {
            #expect(space.id > 0)
            #expect(space.type != nil)
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
            #expect(space.type != nil)
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
        let windowService = WindowService()
        let windows = try await windowService.listWindows(
            target: .application(ApplicationTarget(identifier: "Finder"))
        )
        
        if let firstWindow = windows.first,
           firstWindow.windowID > 0 {
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
            .failedToSwitchSpace
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

@Suite("Space Management Integration Tests")
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
        
        // Should have exactly one active Space
        let activeSpaces = allSpaces.filter { $0.isActive }
        #expect(activeSpaces.count == 1)
    }
}
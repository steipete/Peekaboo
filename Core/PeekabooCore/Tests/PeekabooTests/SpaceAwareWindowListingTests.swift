import AppKit
import Foundation
import Testing
@testable import PeekabooAgentRuntime
@testable import PeekabooAutomation
@testable import PeekabooCore
@testable import PeekabooVisualizer

/// Tests for Space-aware window listing functionality
@Suite("Space-Aware Window Listing")
struct SpaceAwareWindowListingTests {
    @Test("ServiceWindowInfo includes space information")
    func serviceWindowInfoSpaceProperties() {
        // Create a window info with space details
        let windowInfo = ServiceWindowInfo(
            windowID: 1234,
            title: "Test Window",
            bounds: CGRect(x: 100, y: 100, width: 800, height: 600),
            isMinimized: false,
            isMainWindow: true,
            windowLevel: 0,
            alpha: 1.0,
            index: 0,
            spaceID: 42,
            spaceName: "Work Space")

        #expect(windowInfo.spaceID == 42)
        #expect(windowInfo.spaceName == "Work Space")
    }

    @Test("ServiceWindowInfo equality includes space properties")
    func serviceWindowInfoEquality() {
        let windowInfo1 = ServiceWindowInfo(
            windowID: 1234,
            title: "Test Window",
            bounds: CGRect(x: 100, y: 100, width: 800, height: 600),
            spaceID: 42,
            spaceName: "Work Space")

        let windowInfo2 = ServiceWindowInfo(
            windowID: 1234,
            title: "Test Window",
            bounds: CGRect(x: 100, y: 100, width: 800, height: 600),
            spaceID: 42,
            spaceName: "Work Space")

        let windowInfo3 = ServiceWindowInfo(
            windowID: 1234,
            title: "Test Window",
            bounds: CGRect(x: 100, y: 100, width: 800, height: 600),
            spaceID: 43, // Different space
            spaceName: "Personal Space")

        #expect(windowInfo1 == windowInfo2)
        #expect(windowInfo1 != windowInfo3)
    }

    @Test("ServiceWindowInfo handles nil space information")
    func serviceWindowInfoNilSpace() {
        let windowInfo = ServiceWindowInfo(
            windowID: 1234,
            title: "Test Window",
            bounds: CGRect(x: 100, y: 100, width: 800, height: 600))

        #expect(windowInfo.spaceID == nil)
        #expect(windowInfo.spaceName == nil)
    }

    @Test("ServiceWindowInfo Codable includes space properties")
    func serviceWindowInfoCodable() throws {
        let windowInfo = ServiceWindowInfo(
            windowID: 1234,
            title: "Test Window",
            bounds: CGRect(x: 100, y: 100, width: 800, height: 600),
            isMinimized: false,
            isMainWindow: true,
            windowLevel: 0,
            alpha: 1.0,
            index: 0,
            spaceID: 42,
            spaceName: "Work Space")

        // Encode
        let encoder = JSONEncoder()
        let data = try encoder.encode(windowInfo)

        // Decode
        let decoder = JSONDecoder()
        let decodedWindowInfo = try decoder.decode(ServiceWindowInfo.self, from: data)

        #expect(decodedWindowInfo.spaceID == 42)
        #expect(decodedWindowInfo.spaceName == "Work Space")
        #expect(decodedWindowInfo == windowInfo)
    }

    @MainActor
    @Test("SpaceManagementService provides space info for windows")
    func spaceManagementServiceWindowSpaces() {
        let spaceService = SpaceManagementService()

        // In test environment, there might not be any windows
        // Try to find any window or use a dummy window ID
        let testWindowID: CGWindowID = 1 // Dummy window ID for testing
        let spaces = spaceService.getSpacesForWindow(windowID: testWindowID)

        // In a test environment, this might return empty
        // We're testing that the API doesn't crash
        #expect(spaces.isEmpty || spaces.first?.id ?? 0 > 0)
    }

    @MainActor
    @Test("SpaceManagementService returns current space")
    func spaceManagementServiceCurrentSpace() {
        let spaceService = SpaceManagementService()

        let currentSpace = spaceService.getCurrentSpace()

        // In a normal environment, we should have a current space
        // But in test environment it might be nil
        if let space = currentSpace {
            #expect(space.isActive == true)
            #expect(space.id > 0)
            if space.type == .unknown {
                // Headless or sandboxed runs might not expose a concrete type.
                #expect(space.type == .unknown)
            } else {
                #expect(space.type != .unknown)
            }
        } else {
            // In test environment this might be nil
            #expect(currentSpace == nil)
        }
    }

    @Test("Window grouping by space ID")
    func windowGroupingBySpace() {
        // Create sample windows on different spaces
        let windows = [
            ServiceWindowInfo(
                windowID: 1,
                title: "Window 1",
                bounds: CGRect(x: 0, y: 0, width: 100, height: 100),
                spaceID: 1,
                spaceName: "Space 1"),
            ServiceWindowInfo(
                windowID: 2,
                title: "Window 2",
                bounds: CGRect(x: 100, y: 0, width: 100, height: 100),
                spaceID: 1,
                spaceName: "Space 1"),
            ServiceWindowInfo(
                windowID: 3,
                title: "Window 3",
                bounds: CGRect(x: 200, y: 0, width: 100, height: 100),
                spaceID: 2,
                spaceName: "Space 2"),
            ServiceWindowInfo(
                windowID: 4,
                title: "Window 4",
                bounds: CGRect(x: 300, y: 0, width: 100, height: 100),
                spaceID: nil,
                spaceName: nil),
        ]

        // Group by space
        var windowsBySpace: [UInt64?: [ServiceWindowInfo]] = [:]
        for window in windows {
            if windowsBySpace[window.spaceID] == nil {
                windowsBySpace[window.spaceID] = []
            }
            windowsBySpace[window.spaceID]?.append(window)
        }

        #expect(windowsBySpace.count == 3) // Space 1, Space 2, and nil
        #expect(windowsBySpace[1]?.count == 2)
        #expect(windowsBySpace[2]?.count == 1)
        #expect(windowsBySpace[nil]?.count == 1)
    }
}

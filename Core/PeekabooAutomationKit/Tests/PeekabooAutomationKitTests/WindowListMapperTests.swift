import CoreGraphics
import XCTest

@testable import PeekabooAutomationKit

final class WindowListMapperTests: XCTestCase {
    func testMapsCGWindowTitleToSCWindowIndex() {
        let cgWindows = [
            CGWindowDescriptor(windowID: 100, ownerPID: 42, title: "Trimmy"),
            CGWindowDescriptor(windowID: 101, ownerPID: 42, title: "Other"),
        ]
        let scWindows = [
            SCWindowDescriptor(windowID: 999, ownerPID: 42, title: "Scratch"),
            SCWindowDescriptor(windowID: 100, ownerPID: 42, title: "Trimmy"),
        ]
        let snapshot = WindowListSnapshot(cgWindows: cgWindows, scWindows: scWindows)

        let index = WindowListMapper.scWindowIndex(
            for: 42,
            titleFragment: "trim",
            in: snapshot)

        XCTAssertEqual(index, 1)
    }

    func testMapsTitleFallbackWithinSCWindows() {
        let scWindows = [
            SCWindowDescriptor(windowID: 200, ownerPID: 7, title: "Notes"),
            SCWindowDescriptor(windowID: 201, ownerPID: 7, title: "Trimmy Settings"),
        ]

        let index = WindowListMapper.scWindowIndex(for: "settings", in: scWindows)

        XCTAssertEqual(index, 1)
    }

    func testMapsAXWindowIndexByWindowID() {
        let windows = [
            ServiceWindowInfo(
                windowID: 300,
                title: "First",
                bounds: .zero,
                isMinimized: false,
                isMainWindow: false,
                windowLevel: 0,
                alpha: 1.0,
                index: 0,
                spaceID: nil,
                spaceName: nil,
                screenIndex: nil,
                screenName: nil,
                isOffScreen: false,
                layer: 0,
                isOnScreen: true,
                sharingState: nil,
                isExcludedFromWindowsMenu: false),
            ServiceWindowInfo(
                windowID: 301,
                title: "Second",
                bounds: .zero,
                isMinimized: false,
                isMainWindow: true,
                windowLevel: 0,
                alpha: 1.0,
                index: 1,
                spaceID: nil,
                spaceName: nil,
                screenIndex: nil,
                screenName: nil,
                isOffScreen: false,
                layer: 0,
                isOnScreen: true,
                sharingState: nil,
                isExcludedFromWindowsMenu: false),
        ]

        let index = WindowListMapper.axWindowIndex(for: CGWindowID(301), in: windows)

        XCTAssertEqual(index, 1)
    }
}

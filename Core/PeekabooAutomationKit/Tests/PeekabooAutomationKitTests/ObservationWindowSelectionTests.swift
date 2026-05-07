import CoreGraphics
import XCTest
@testable import PeekabooAutomationKit

final class ObservationWindowSelectionTests: XCTestCase {
    func testCaptureCandidatesDropNonShareableWindows() {
        let windows = [
            Self.window(
                id: 1,
                title: "Overlay",
                bounds: CGRect(x: 0, y: 0, width: 400, height: 400),
                sharingState: .none),
            Self.window(
                id: 2,
                title: "Editor",
                bounds: CGRect(x: 0, y: 0, width: 1200, height: 900),
                sharingState: .readWrite),
        ]

        let filtered = ObservationTargetResolver.captureCandidates(from: windows)

        XCTAssertEqual(filtered.map(\.title), ["Editor"])
    }

    func testListFilteringKeepsMinimizedWindows() {
        let windows = [
            Self.window(
                id: 3,
                title: "Hidden",
                bounds: CGRect(x: 0, y: 0, width: 800, height: 600),
                isMinimized: true,
                isOnScreen: false),
            Self.window(
                id: 4,
                title: "Visible",
                bounds: CGRect(x: 0, y: 0, width: 800, height: 600),
                isOnScreen: true),
        ]

        let filtered = ObservationTargetResolver.filteredWindows(from: windows, mode: .list)

        XCTAssertEqual(filtered.count, 2)
    }

    func testCaptureCandidatesDeduplicateWindowIDs() {
        let first = Self.window(
            id: 10,
            title: "Document",
            bounds: CGRect(x: 0, y: 0, width: 800, height: 600),
            index: 0)
        let duplicate = Self.window(
            id: 10,
            title: "Document Copy",
            bounds: CGRect(x: 20, y: 20, width: 800, height: 600),
            index: 1)

        let filtered = ObservationTargetResolver.captureCandidates(from: [first, duplicate])

        XCTAssertEqual(filtered.map(\.index), [0])
    }

    private static func window(
        id: Int,
        title: String,
        bounds: CGRect,
        isMinimized: Bool = false,
        index: Int = 0,
        isOnScreen: Bool = true,
        sharingState: WindowSharingState = .readOnly) -> ServiceWindowInfo
    {
        ServiceWindowInfo(
            windowID: id,
            title: title,
            bounds: bounds,
            isMinimized: isMinimized,
            isMainWindow: false,
            windowLevel: 0,
            alpha: 1,
            index: index,
            layer: 0,
            isOnScreen: isOnScreen,
            sharingState: sharingState,
            isExcludedFromWindowsMenu: false)
    }
}

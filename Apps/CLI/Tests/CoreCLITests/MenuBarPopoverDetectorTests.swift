import CoreGraphics
import Foundation
import Testing
@testable import PeekabooCLI

@Suite("Menu bar popover detection")
struct MenuBarPopoverDetectorTests {
    @Test("accepts top-left coordinate popover near menu bar")
    func topLeftCoordinatePopover() {
        let screens = [MenuBarPopoverDetector.ScreenBounds(
            frame: CGRect(x: 0, y: 0, width: 1920, height: 1080),
            visibleFrame: CGRect(x: 0, y: 50, width: 1920, height: 1030)
        )]

        let windowList: [[String: Any]] = [
            makeWindowInfo(
                windowId: 42,
                ownerPID: 1234,
                ownerName: "Trimmy",
                bounds: CGRect(x: 100, y: 0, width: 220, height: 260),
                layer: 100
            ),
        ]

        let candidates = MenuBarPopoverDetector.candidates(
            windowList: windowList,
            screens: screens,
            ownerPID: 1234
        )

        #expect(candidates.count == 1)
        #expect(candidates.first?.windowId == 42)
    }

    @Test("accepts bottom-left coordinate popover near menu bar")
    func bottomLeftCoordinatePopover() {
        let screens = [MenuBarPopoverDetector.ScreenBounds(
            frame: CGRect(x: 0, y: 0, width: 1920, height: 1080),
            visibleFrame: CGRect(x: 0, y: 50, width: 1920, height: 1030)
        )]

        let windowList: [[String: Any]] = [
            makeWindowInfo(
                windowId: 7,
                ownerPID: 999,
                ownerName: "Control Center",
                bounds: CGRect(x: 1200, y: 900, width: 400, height: 200),
                layer: 100
            ),
        ]

        let candidates = MenuBarPopoverDetector.candidates(
            windowList: windowList,
            screens: screens,
            ownerPID: 999
        )

        #expect(candidates.count == 1)
        #expect(candidates.first?.windowId == 7)
    }

    @Test("rejects windows away from the menu bar")
    func rejectsNonMenuBarWindows() {
        let screens = [MenuBarPopoverDetector.ScreenBounds(
            frame: CGRect(x: 0, y: 0, width: 1920, height: 1080),
            visibleFrame: CGRect(x: 0, y: 50, width: 1920, height: 1030)
        )]

        let windowList: [[String: Any]] = [
            makeWindowInfo(
                windowId: 99,
                ownerPID: 555,
                ownerName: "Other",
                bounds: CGRect(x: 200, y: 300, width: 400, height: 200),
                layer: 100
            ),
        ]

        let candidates = MenuBarPopoverDetector.candidates(
            windowList: windowList,
            screens: screens,
            ownerPID: 555
        )

        #expect(candidates.isEmpty)
    }
}

private func makeWindowInfo(
    windowId: Int,
    ownerPID: pid_t,
    ownerName: String,
    bounds: CGRect,
    layer: Int
) -> [String: Any] {
    [
        kCGWindowNumber as String: windowId,
        kCGWindowOwnerPID as String: ownerPID,
        kCGWindowOwnerName as String: ownerName,
        kCGWindowLayer as String: layer,
        kCGWindowIsOnscreen as String: true,
        kCGWindowAlpha as String: CGFloat(1.0),
        kCGWindowBounds as String: [
            "X": bounds.origin.x,
            "Y": bounds.origin.y,
            "Width": bounds.size.width,
            "Height": bounds.size.height,
        ],
    ]
}

import CoreGraphics
import Testing
@testable import PeekabooCLI
@testable import PeekabooCore

@Suite("WindowFilteringHelper Tests", .serialized, .tags(.unit))
struct WindowFilteringHelperTests {
    @Test("Capture mode drops non-shareable windows")
    func captureModeSkipsNonShareable() {
        let windows = [
            ServiceWindowInfo(
                windowID: 1,
                title: "Overlay",
                bounds: CGRect(x: 0, y: 0, width: 400, height: 400),
                sharingState: .none
            ),
            ServiceWindowInfo(
                windowID: 2,
                title: "Editor",
                bounds: CGRect(x: 0, y: 0, width: 1200, height: 900),
                sharingState: .readWrite,
                index: 1
            ),
        ]

        let filtered = WindowFilterHelper.filter(
            windows: windows,
            appIdentifier: "TestApp",
            mode: .capture,
            logger: nil
        )

        #expect(filtered.count == 1)
        #expect(filtered.first?.title == "Editor")
    }

    @Test("List mode keeps minimized windows")
    func listModeKeepsMinimized() {
        let windows = [
            ServiceWindowInfo(
                windowID: 3,
                title: "Hidden",
                bounds: CGRect(x: 0, y: 0, width: 800, height: 600),
                isMinimized: true,
                isOnScreen: false
            ),
            ServiceWindowInfo(
                windowID: 4,
                title: "Visible",
                bounds: CGRect(x: 0, y: 0, width: 800, height: 600),
                isOnScreen: true,
                index: 1
            ),
        ]

        let filtered = WindowFilterHelper.filter(
            windows: windows,
            appIdentifier: "TestApp",
            mode: .list,
            logger: nil
        )

        #expect(filtered.count == 2)
    }
}

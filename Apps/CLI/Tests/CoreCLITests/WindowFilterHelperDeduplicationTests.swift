import Foundation
import PeekabooCore
import Testing
@testable import PeekabooCLI

@Suite("WindowFilterHelper deduplication")
struct WindowFilterHelperDeduplicationTests {
    @Test("filter removes duplicate window IDs while preserving order")
    func filterRemovesDuplicateWindowIDs() {
        let window1 = ServiceWindowInfo(
            windowID: 42,
            title: "First",
            bounds: CGRect(x: 0, y: 0, width: 500, height: 400),
            alpha: 1.0,
            index: 0,
            layer: 0,
            isOnScreen: true,
            isExcludedFromWindowsMenu: false)

        let window2 = ServiceWindowInfo(
            windowID: 42,
            title: "Duplicate",
            bounds: CGRect(x: 10, y: 10, width: 500, height: 400),
            alpha: 1.0,
            index: 1,
            layer: 0,
            isOnScreen: true,
            isExcludedFromWindowsMenu: false)

        let window3 = ServiceWindowInfo(
            windowID: 99,
            title: "Other",
            bounds: CGRect(x: 20, y: 20, width: 500, height: 400),
            alpha: 1.0,
            index: 2,
            layer: 0,
            isOnScreen: true,
            isExcludedFromWindowsMenu: false)

        let filtered = WindowFilterHelper.filter(
            windows: [window1, window2, window3],
            appIdentifier: "Playground",
            mode: .list,
            logger: nil)

        #expect(filtered.count == 2)
        #expect(filtered[0].windowID == 42)
        #expect(filtered[0].title == "First")
        #expect(filtered[1].windowID == 99)
    }
}


import CoreGraphics
import Testing
@testable import PeekabooAutomationKit

@MainActor
struct WindowListIndexNormalizationTests {
    @Test
    func `normalizeWindowIndices keeps order and makes indices contiguous`() {
        let windows = [
            ServiceWindowInfo(
                windowID: 111,
                title: "First",
                bounds: .zero,
                isMinimized: false,
                isMainWindow: false,
                windowLevel: 0,
                alpha: 1.0,
                index: 5,
                spaceID: nil,
                spaceName: nil,
                screenIndex: nil,
                screenName: nil,
                layer: 0,
                isOnScreen: true,
                sharingState: nil,
                isExcludedFromWindowsMenu: false),
            ServiceWindowInfo(
                windowID: 222,
                title: "Second",
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
                layer: 0,
                isOnScreen: true,
                sharingState: nil,
                isExcludedFromWindowsMenu: false),
        ]

        let normalized = ApplicationService.normalizeWindowIndices(windows)

        #expect(normalized.map(\.windowID) == [111, 222])
        #expect(normalized.map(\.title) == ["First", "Second"])
        #expect(normalized.map(\.index) == [0, 1])
    }

    @Test
    func `normalizeWindowIndices handles empty input`() {
        #expect(ApplicationService.normalizeWindowIndices([]).isEmpty)
    }
}

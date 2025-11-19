import AppKit
import Testing
@testable import PeekabooAutomation

@Suite("MouseLocationUtilities Tests")
@MainActor
struct MouseLocationUtilitiesTests {
    @Test("Falls back to frontmost app when locator is nil")
    func fallbackToFrontmost() async throws {
        var frontmostCalls = 0
        MouseLocationUtilities.setAppProvidersForTesting(
            appProvider: { nil },
            frontmostProvider: {
                frontmostCalls += 1
                return NSWorkspace.shared.frontmostApplication
            })
        defer { MouseLocationUtilities.resetAppProvidersForTesting() }

        let app = MouseLocationUtilities.findApplicationAtMouseLocation()
        #expect(app != nil)
        #expect(frontmostCalls == 1)
    }
}

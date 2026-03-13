import AppKit
import Testing
@testable import PeekabooAutomationKit

@MainActor
struct MouseLocationUtilitiesTests {
    @Test
    func `Falls back to frontmost app when locator is nil`() {
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

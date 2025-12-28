import Foundation
import PeekabooCore
import Testing
@testable import PeekabooCLI

@Suite("Menu bar focus verification")
struct MenuBarFocusVerificationTests {
    @Test("matches by PID")
    func matchesByPID() {
        let frontmost = ServiceApplicationInfo(
            processIdentifier: 200,
            bundleIdentifier: "com.trimmy.app",
            name: "Trimmy",
            bundlePath: nil,
            isActive: true,
            isHidden: false,
            windowCount: 1
        )

        let matches = MenuBarClickVerifier.frontmostMatchesTarget(
            frontmost: frontmost,
            ownerPID: 200,
            ownerName: nil,
            bundleIdentifier: nil
        )

        #expect(matches)
    }

    @Test("matches by bundle identifier")
    func matchesByBundleIdentifier() {
        let frontmost = ServiceApplicationInfo(
            processIdentifier: 201,
            bundleIdentifier: "com.trimmy.app",
            name: "Trimmy",
            bundlePath: nil,
            isActive: true,
            isHidden: false,
            windowCount: 1
        )

        let matches = MenuBarClickVerifier.frontmostMatchesTarget(
            frontmost: frontmost,
            ownerPID: nil,
            ownerName: nil,
            bundleIdentifier: "com.trimmy.app"
        )

        #expect(matches)
    }

    @Test("matches by owner name")
    func matchesByOwnerName() {
        let frontmost = ServiceApplicationInfo(
            processIdentifier: 202,
            bundleIdentifier: nil,
            name: "Trimmy",
            bundlePath: nil,
            isActive: true,
            isHidden: false,
            windowCount: 1
        )

        let matches = MenuBarClickVerifier.frontmostMatchesTarget(
            frontmost: frontmost,
            ownerPID: nil,
            ownerName: "trimmy",
            bundleIdentifier: nil
        )

        #expect(matches)
    }

    @Test("rejects mismatched target")
    func rejectsMismatch() {
        let frontmost = ServiceApplicationInfo(
            processIdentifier: 203,
            bundleIdentifier: "com.apple.Safari",
            name: "Safari",
            bundlePath: nil,
            isActive: true,
            isHidden: false,
            windowCount: 2
        )

        let matches = MenuBarClickVerifier.frontmostMatchesTarget(
            frontmost: frontmost,
            ownerPID: 999,
            ownerName: "Trimmy",
            bundleIdentifier: "com.trimmy.app"
        )

        #expect(!matches)
    }
}

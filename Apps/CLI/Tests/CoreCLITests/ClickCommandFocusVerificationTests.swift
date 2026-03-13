import Testing
@testable import PeekabooCLI

@Suite("ClickCommand focus verification")
struct ClickCommandFocusVerificationTests {
    @Test("Exact app name match passes")
    func exactAppNameMatchPasses() {
        let frontmost = FrontmostApplicationIdentity(
            name: "Claude",
            bundleIdentifier: "com.anthropic.claudedesktop",
            processIdentifier: 41
        )

        let message = CoordinateClickFocusVerifier.mismatchMessage(
            targetApp: "Claude",
            targetPID: nil,
            frontmost: frontmost
        )

        #expect(message == nil)
    }

    @Test("Exact bundle identifier match passes")
    func exactBundleIdentifierMatchPasses() {
        let frontmost = FrontmostApplicationIdentity(
            name: "Claude",
            bundleIdentifier: "com.anthropic.claudedesktop",
            processIdentifier: 41
        )

        let message = CoordinateClickFocusVerifier.mismatchMessage(
            targetApp: "com.anthropic.claudedesktop",
            targetPID: nil,
            frontmost: frontmost
        )

        #expect(message == nil)
    }

    @Test("PID targets pass when the frontmost PID matches")
    func pidTargetPasses() {
        let frontmost = FrontmostApplicationIdentity(
            name: "Claude",
            bundleIdentifier: "com.anthropic.claudedesktop",
            processIdentifier: 41
        )

        let directPIDMessage = CoordinateClickFocusVerifier.mismatchMessage(
            targetApp: nil,
            targetPID: 41,
            frontmost: frontmost
        )
        #expect(directPIDMessage == nil)

        let pidStringMessage = CoordinateClickFocusVerifier.mismatchMessage(
            targetApp: "PID:41",
            targetPID: nil,
            frontmost: frontmost
        )
        #expect(pidStringMessage == nil)
    }

    @Test("Partial app-name matches still fail")
    func partialAppNameMatchesStillFail() {
        let frontmost = FrontmostApplicationIdentity(
            name: "Xcode",
            bundleIdentifier: "com.apple.dt.Xcode",
            processIdentifier: 99
        )

        let message = CoordinateClickFocusVerifier.mismatchMessage(
            targetApp: "Code",
            targetPID: nil,
            frontmost: frontmost
        )

        #expect(message != nil)
        #expect(message?.contains("'Xcode'") == true)
    }

    @Test("Mismatch includes the frontmost application details")
    func mismatchIncludesFrontmostDetails() {
        let frontmost = FrontmostApplicationIdentity(
            name: "Google Chrome",
            bundleIdentifier: "com.google.Chrome",
            processIdentifier: 512
        )

        let message = CoordinateClickFocusVerifier.mismatchMessage(
            targetApp: "Claude",
            targetPID: nil,
            frontmost: frontmost
        )

        #expect(message?.contains("Target app 'Claude'") == true)
        #expect(message?.contains("'Google Chrome'") == true)
        #expect(message?.contains("com.google.Chrome") == true)
        #expect(message?.contains("PID 512") == true)
    }
}

import Foundation
import Testing
@testable import PeekabooAutomationKit

struct ForegroundCloseFocusVerificationTests {
    @Test
    func `foreground close focus verification recovers only when close asks for it`() {
        let closeOptions = foregroundCloseFocusOptions()
        let ordinaryOptions = FocusManagementService.FocusOptions()
        #expect(closeOptions.recoverNonPositiveFrontmostProcessIdentifier)
        #expect(!ordinaryOptions.recoverNonPositiveFrontmostProcessIdentifier)
        #expect(closeOptions.switchSpace)
        #expect(!closeOptions.bringToCurrentSpace)

        var scanned = false
        let unchanged = focusVerificationFrontmostProcessIdentifier(
            recoverNonPositiveFrontmostProcessIdentifier: false,
            reportedProcessIdentifier: -1,
            recover: {
                scanned = true
                return 42
            })
        #expect(unchanged == -1)
        #expect(!scanned)

        let recovered = focusVerificationFrontmostProcessIdentifier(
            recoverNonPositiveFrontmostProcessIdentifier: true,
            reportedProcessIdentifier: -1,
            recover: { 42 },
            sampleAfterRecovery: {
                ForegroundCloseFrontmostSample(processIdentifier: -1, ownsRecoveredProcess: true)
            })
        #expect(recovered == 42)

        var positiveScan = false
        let positive = focusVerificationFrontmostProcessIdentifier(
            recoverNonPositiveFrontmostProcessIdentifier: true,
            reportedProcessIdentifier: 42,
            recover: {
                positiveScan = true
                return 99
            })
        #expect(positive == 42)
        #expect(!positiveScan)

        let switched = focusVerificationFrontmostProcessIdentifier(
            recoverNonPositiveFrontmostProcessIdentifier: true,
            reportedProcessIdentifier: -1,
            recover: { 42 },
            sampleAfterRecovery: {
                ForegroundCloseFrontmostSample(processIdentifier: 77, ownsRecoveredProcess: false)
            })
        #expect(switched == nil)
    }
}

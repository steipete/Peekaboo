import CoreGraphics
import Foundation
import PeekabooFoundation
import Testing
@testable import PeekabooAutomationKit

@MainActor
struct WindowCloseVerificationTests {
    private let identity = WindowMutationIdentity(
        windowID: 924,
        ownerProcessIdentifier: 42,
        ownerProcessStartIdentity: 7,
        capturedBounds: CGRect(x: 30, y: 40, width: 900, height: 700))

    @Test(arguments: [false, nil] as [Bool?])
    func `retained offscreen row closes when exact AX window disappears`(flag: Bool?) async throws {
        let row = try self.catalogIdentity(flag: flag)
        var axReads = 0
        let disposition = try await readPinnedWindowClosePresence(
            expectedIdentity: self.identity,
            windowServerIdentity: row,
            processStartIdentityReader: { _ in 7 },
            axPresenceReader: {
                axReads += 1
                return self.axPresence(bounds: [])
            })
        var verification = PinnedWindowCloseVerification()

        #expect(axReads == 1)
        #expect(disposition == .missing)
        #expect(verification.observe(disposition, elapsed: .zero) == .pending)
        #expect(verification.observe(disposition, elapsed: .milliseconds(750)) == .pending)
        let decision = verification.observe(disposition, elapsed: .seconds(4))
        #expect(decision == .succeeded)
        #expect(pinnedWindowCloseAttemptDisposition(for: decision) == .disappeared)
    }

    @Test(arguments: [false, nil] as [Bool?], [false, true])
    func `offscreen AX window remains whether hidden or minimized`(flag: Bool?, minimized: Bool) async throws {
        let expected = WindowMutationIdentity(
            windowID: self.identity.windowID,
            ownerProcessIdentifier: self.identity.ownerProcessIdentifier,
            ownerProcessStartIdentity: self.identity.ownerProcessStartIdentity,
            capturedBounds: self.identity.capturedBounds,
            isMinimized: minimized)
        let disposition = try await readPinnedWindowClosePresence(
            expectedIdentity: expected,
            windowServerIdentity: self.catalogIdentity(flag: flag),
            processStartIdentityReader: { _ in 7 },
            axPresenceReader: { self.axPresence(bounds: [self.identity.capturedBounds]) })
        var verification = PinnedWindowCloseVerification()

        #expect(disposition == .present)
        #expect(verification.observe(disposition, elapsed: .zero) == .pending)
        #expect(verification.observe(disposition, elapsed: .milliseconds(750)) == .retryClose)
        #expect(verification.observe(disposition, elapsed: .seconds(4)) == .retryClose)
    }

    @Test
    func `onscreen matching row remains without consulting AX`() async throws {
        let disposition = try await readPinnedWindowClosePresence(
            expectedIdentity: self.identity,
            windowServerIdentity: self.catalogIdentity(flag: true),
            processStartIdentityReader: { _ in 7 },
            axPresenceReader: {
                Issue.record("An on-screen matching row must not require AX readback")
                return .missing
            })
        var verification = PinnedWindowCloseVerification()

        #expect(disposition == .present)
        #expect(verification.observe(disposition, elapsed: .zero) == .pending)
        #expect(verification.observe(disposition, elapsed: .milliseconds(750)) == .retryClose)
    }

    @Test
    func `absent catalog row and exact AX window still confirm close`() async throws {
        var axReads = 0
        let disposition = try await readPinnedWindowClosePresence(
            expectedIdentity: self.identity,
            windowServerIdentity: nil,
            processStartIdentityReader: { _ in 7 },
            axPresenceReader: {
                axReads += 1
                return self.axPresence(bounds: [])
            })
        var verification = PinnedWindowCloseVerification()

        #expect(axReads == 1)
        #expect(disposition == .missing)
        #expect(verification.observe(disposition, elapsed: .zero) == .pending)
        #expect(verification.observe(disposition, elapsed: .seconds(4)) == .succeeded)
    }

    @Test(arguments: [false, nil] as [Bool?])
    func `offscreen incomplete AX scan cannot confirm close`(flag: Bool?) async throws {
        let disposition = try await readPinnedWindowClosePresence(
            expectedIdentity: self.identity,
            windowServerIdentity: self.catalogIdentity(flag: flag),
            processStartIdentityReader: { _ in 7 },
            axPresenceReader: { self.axPresence(bounds: [], complete: false) })
        var verification = PinnedWindowCloseVerification()

        #expect(disposition == .unverifiable)
        #expect(verification.observe(disposition, elapsed: .seconds(4)) == .unverifiable)
    }

    @Test(arguments: [true, false, nil] as [Bool?])
    func `catalog bounds mismatch still consults exact AX identity`(flag: Bool?) async throws {
        let differentBounds = CGRect(x: 50, y: 60, width: 640, height: 480)
        let disposition = try await readPinnedWindowClosePresence(
            expectedIdentity: self.identity,
            windowServerIdentity: self.catalogIdentity(flag: flag, bounds: differentBounds),
            processStartIdentityReader: { _ in 7 },
            axPresenceReader: { self.axPresence(bounds: [differentBounds]) })

        #expect(disposition == .replacement)
    }

    @Test(arguments: [true, false, nil] as [Bool?], [false, true])
    func `catalog owner and generation mismatches still fail before AX`(flag: Bool?, reusedPID: Bool) async throws {
        await #expect(throws: PeekabooError.self) {
            _ = try await readPinnedWindowClosePresence(
                expectedIdentity: self.identity,
                windowServerIdentity: self.catalogIdentity(flag: flag, ownerPID: reusedPID ? 42 : 43),
                processStartIdentityReader: { _ in reusedPID ? 8 : 7 },
                axPresenceReader: {
                    Issue.record("A replaced owner must fail before AX readback")
                    return .missing
                })
        }
    }

    private func catalogIdentity(
        flag: Bool?,
        bounds: CGRect? = nil,
        ownerPID: pid_t = 42) throws -> SystemWindowIdentity
    {
        let windowBounds = try #require(bounds ?? self.identity.capturedBounds)
        var row: [String: Any] = [
            kCGWindowNumber as String: self.identity.windowID,
            kCGWindowOwnerPID as String: ownerPID,
            kCGWindowBounds as String: windowBounds.dictionaryRepresentation,
            kCGWindowLayer as String: 0,
        ]
        if let flag {
            row[kCGWindowIsOnscreen as String] = flag
        }
        return try #require(SystemIdentityResolver.windowIdentity(CGWindowID(self.identity.windowID), in: [row]))
    }

    private func axPresence(bounds: [CGRect?], complete: Bool = true) -> PinnedMinimizedWindowAXPresence {
        pinnedMinimizedWindowAXPresence(
            expectedIdentity: self.identity,
            processStartIdentityBeforeScan: 7,
            processStartIdentityAfterScan: 7,
            scan: PinnedMinimizedWindowAXScan(matchingWindowBounds: bounds, isComplete: complete))
    }
}

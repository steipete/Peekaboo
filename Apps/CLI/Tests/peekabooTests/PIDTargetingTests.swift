import AppKit
import Foundation
import Testing
@testable import peekaboo

@Suite("PID Targeting Tests", .serialized)
struct PIDTargetingTests {
    @Test("Find application by valid PID", .enabled(if: ProcessInfo.processInfo.environment["CI"] == nil))
    func findByValidPID() throws {
        // Get any running application
        let runningApps = NSWorkspace.shared.runningApplications
        guard let testApp = runningApps.first(where: { $0.localizedName != nil }) else {
            Issue.record("No running applications found for testing")
            return
        }

        let pid = testApp.processIdentifier
        let identifier = "PID:\(pid)"

        do {
            let foundApp = try ApplicationFinder.findApplication(identifier: identifier)
            #expect(foundApp.processIdentifier == pid)
            #expect(foundApp.bundleIdentifier == testApp.bundleIdentifier)
        } catch {
            Issue.record("Failed to find application by PID: \(error)")
        }
    }

    @Test("Invalid PID format throws error")
    func invalidPIDFormat() throws {
        // Test various invalid PID formats
        let invalidPIDs = [
            "PID:", // Missing PID number
            "PID:abc", // Non-numeric PID
            "PID:-123", // Negative PID
            "PID:12.34", // Decimal PID
            "PID:999999999", // Very large PID (likely non-existent)
        ]

        for invalidPID in invalidPIDs {
            #expect(throws: ApplicationError.self) {
                _ = try ApplicationFinder.findApplication(identifier: invalidPID)
            }
        }
    }

    @Test("Non-existent PID throws notFound error")
    func nonExistentPID() throws {
        // Use a very high PID number that's unlikely to exist
        let identifier = "PID:99999"

        do {
            _ = try ApplicationFinder.findApplication(identifier: identifier)
            Issue.record("Expected error for non-existent PID")
        } catch let ApplicationError.notFound(message) {
            // The message should contain information about the PID
            #expect(
                message.contains("99999") || message == identifier,
                "Error message '\(message)' should mention PID 99999")
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }
}

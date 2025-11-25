import AppKit
import Foundation
import PeekabooCore
import PeekabooFoundation
import Testing

@Suite("PID Targeting Tests", .serialized, .tags(.safe))
struct PIDTargetingTests {
    @Test("Find application by valid PID", .enabled(if: ProcessInfo.processInfo.environment["CI"] == nil))
    func findByValidPID() async throws {
        // Get any running application
        let runningApps = NSWorkspace.shared.runningApplications
        guard let testApp = runningApps.first(where: { $0.localizedName != nil && $0.activationPolicy != .prohibited })
        else {
            Issue.record("No running applications found for testing")
            return
        }

        let pid = testApp.processIdentifier
        let identifier = "PID:\(pid)"

        let applicationService = await MainActor.run { ApplicationService() }

        do {
            let foundApp = try await applicationService.findApplication(identifier: identifier)
            #expect(foundApp.processIdentifier == pid)
            #expect(foundApp.bundleIdentifier == testApp.bundleIdentifier)
        } catch {
            Issue.record("Failed to find application by PID: \(error)")
        }
    }

    @Test("Invalid PID format throws error")
    func invalidPIDFormat() async throws {
        // Test various invalid PID formats
        let invalidPIDs = [
            "PID:", // Missing PID number
            "PID:abc", // Non-numeric PID
            "PID:-123", // Negative PID
            "PID:12.34", // Decimal PID
        ]

        let applicationService = await MainActor.run { ApplicationService() }

        for invalidPID in invalidPIDs {
            await #expect(throws: PeekabooError.self) {
                _ = try await applicationService.findApplication(identifier: invalidPID)
            }
        }
    }

    @Test("Non-existent PID throws notFound error")
    func nonExistentPID() async throws {
        // Use a very high PID that's unlikely to exist
        let nonExistentPID = "PID:999999"

        let applicationService = await MainActor.run { ApplicationService() }

        await #expect(throws: (any Error).self) {
            _ = try await applicationService.findApplication(identifier: nonExistentPID)
        }
    }

    @Test("PID prefix matching is case-insensitive")
    func pidPrefixCaseInsensitivity() async throws {
        // Get any running application
        let runningApps = NSWorkspace.shared.runningApplications
        guard let testApp = runningApps.first(where: { $0.localizedName != nil && $0.activationPolicy != .prohibited })
        else {
            Issue.record("No running applications found for testing")
            return
        }

        let pid = testApp.processIdentifier
        let applicationService = await MainActor.run { ApplicationService() }

        // ApplicationService treats the PID prefix in a case-insensitive manner
        let variations = ["PID:\(pid)", "pid:\(pid)", "Pid:\(pid)", "pId:\(pid)"]

        for identifier in variations {
            do {
                let foundApp = try await applicationService.findApplication(identifier: identifier)
                #expect(foundApp.processIdentifier == pid)
            } catch {
                Issue.record("Failed to find application with PID variation '\(identifier)': \(error)")
            }
        }
    }

    @Test("PID targeting has priority over name matching")
    func pidPriorityOverName() async throws {
        // Get Finder's PID since it's always running
        let runningApps = NSWorkspace.shared.runningApplications
        guard let finder = runningApps.first(where: { $0.bundleIdentifier == "com.apple.finder" }) else {
            Issue.record("Finder not found")
            return
        }

        // Use an identifier that looks like it could be a name but starts with PID:
        let identifier = "PID:\(finder.processIdentifier)"

        let applicationService = await MainActor.run { ApplicationService() }

        do {
            let foundApp = try await applicationService.findApplication(identifier: identifier)
            #expect(foundApp.processIdentifier == finder.processIdentifier)
            #expect(foundApp.bundleIdentifier == "com.apple.finder")
        } catch {
            Issue.record("Failed to find Finder by PID: \(error)")
        }
    }

    @Test("Find application by bundle ID")
    func findByBundleID() async throws {
        let applicationService = await MainActor.run { ApplicationService() }

        // Try to find Finder by bundle ID
        do {
            let foundApp = try await applicationService.findApplication(identifier: "com.apple.finder")
            #expect(foundApp.bundleIdentifier == "com.apple.finder")
            #expect(foundApp.name == "Finder")
        } catch {
            Issue.record("Failed to find Finder by bundle ID: \(error)")
        }
    }

    @Test("Find application by name")
    func findByName() async throws {
        let applicationService = await MainActor.run { ApplicationService() }

        // Try to find Finder by name (case-insensitive)
        for name in ["Finder", "finder", "FINDER"] {
            do {
                let foundApp = try await applicationService.findApplication(identifier: name)
                #expect(foundApp.bundleIdentifier == "com.apple.finder")
            } catch {
                Issue.record("Failed to find Finder by name '\(name)': \(error)")
            }
        }
    }
}

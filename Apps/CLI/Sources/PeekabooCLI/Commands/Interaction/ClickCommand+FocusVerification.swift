import Foundation
import PeekabooCore
import PeekabooFoundation

struct FrontmostApplicationIdentity: Equatable {
    let name: String?
    let bundleIdentifier: String?
    let processIdentifier: Int32?

    init(
        name: String? = nil,
        bundleIdentifier: String? = nil,
        processIdentifier: Int32? = nil
    ) {
        self.name = name?.nilIfEmpty
        self.bundleIdentifier = bundleIdentifier?.nilIfEmpty
        self.processIdentifier = processIdentifier
    }

    init(application: ServiceApplicationInfo?) {
        self.init(
            name: application?.name,
            bundleIdentifier: application?.bundleIdentifier,
            processIdentifier: application?.processIdentifier
        )
    }

    var displayDescription: String {
        var components: [String] = []
        if let name = self.name {
            components.append("'\(name)'")
        }
        if let bundleIdentifier = self.bundleIdentifier {
            components.append(bundleIdentifier)
        }
        if let processIdentifier = self.processIdentifier {
            components.append("PID \(processIdentifier)")
        }
        if components.isEmpty {
            return "unknown application"
        }
        return components.joined(separator: " ")
    }
}

enum CoordinateClickFocusVerifier {
    static func mismatchMessage(
        targetApp: String?,
        targetPID: Int32?,
        frontmost: FrontmostApplicationIdentity
    ) -> String? {
        guard targetApp != nil || targetPID != nil else {
            return nil
        }

        if let targetPID, frontmost.processIdentifier == targetPID {
            return nil
        }

        if let targetApp, self.matches(targetApp: targetApp, frontmost: frontmost) {
            return nil
        }

        let targetDescription = self.targetDescription(targetApp: targetApp, targetPID: targetPID)
        let frontmostDescription = frontmost.displayDescription

        return """
        \(targetDescription) is not frontmost after the focus attempt. Currently frontmost: \(frontmostDescription).
        The coordinate click would land on the frontmost window instead.

        Hints:
          - Ensure no other window is overlapping the target
          - Try clicking by element ID (--on) instead of coordinates
          - Close or minimize interfering windows first
        """
    }

    static func targetDescription(targetApp: String?, targetPID: Int32?) -> String {
        if let targetApp {
            return "Target app '\(targetApp)'"
        }
        if let targetPID {
            return "Target PID \(targetPID)"
        }
        return "Target application"
    }

    private static func matches(targetApp: String, frontmost: FrontmostApplicationIdentity) -> Bool {
        let trimmedTarget = targetApp.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTarget.isEmpty else {
            return false
        }

        if let pid = self.parsePID(trimmedTarget), frontmost.processIdentifier == pid {
            return true
        }

        if let bundleIdentifier = frontmost.bundleIdentifier,
           bundleIdentifier.caseInsensitiveCompare(trimmedTarget) == .orderedSame {
            return true
        }

        if let name = frontmost.name,
           name.caseInsensitiveCompare(trimmedTarget) == .orderedSame {
            return true
        }

        return false
    }

    private static func parsePID(_ identifier: String) -> Int32? {
        guard identifier.hasPrefix("PID:") else {
            return nil
        }
        return Int32(identifier.dropFirst(4))
    }
}

@available(macOS 14.0, *)
@MainActor
extension ClickCommand {
    /// Verify that the target app is actually frontmost before dispatching a coordinate click.
    func verifyFocusForCoordinateClick() async throws {
        let frontmostInfo = try? await self.services.applications.getFrontmostApplication()
        let frontmost = FrontmostApplicationIdentity(application: frontmostInfo)
        if let message = CoordinateClickFocusVerifier.mismatchMessage(
            targetApp: self.target.app,
            targetPID: self.target.pid,
            frontmost: frontmost
        ) {
            let targetDescription = CoordinateClickFocusVerifier.targetDescription(
                targetApp: self.target.app,
                targetPID: self.target.pid
            )
            self.outputLogger.warn(
                "Coordinate click focus mismatch for " +
                    "\(targetDescription). " +
                    "Frontmost is \(frontmost.displayDescription)."
            )
            throw PeekabooError.clickFailed(message)
        }
    }
}

extension String {
    fileprivate var nilIfEmpty: String? {
        self.isEmpty ? nil : self
    }
}

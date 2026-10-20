import AppKit
import Foundation
import PeekabooFoundation

@_spi(Testing) public protocol ApplicationResolving: Sendable {
    func findApplication(identifier: String) async throws -> ServiceApplicationInfo
    func frontmostApplication() async throws -> ServiceApplicationInfo
}

struct PeekabooApplicationResolver: ApplicationResolving {
    @MainActor
    func frontmostApplication() async throws -> ServiceApplicationInfo {
        guard let frontmost = NSWorkspace.shared.frontmostApplication else {
            throw NotFoundError.application("frontmost")
        }
        guard let pid = RunningApplicationProcessIdentity.resolve(frontmost) else {
            throw NotFoundError.application("frontmost")
        }
        return Self.applicationInfo(from: frontmost, processIdentifier: pid)
    }

    func findApplication(identifier: String) async throws -> ServiceApplicationInfo {
        let runningApps = NSWorkspace.shared.runningApplications.compactMap { app -> (NSRunningApplication, pid_t)? in
            guard !app.isTerminated, let pid = RunningApplicationProcessIdentity.resolve(app) else { return nil }
            return (app, pid)
        }
        let candidates = runningApps.map { ApplicationService.identifierCandidate($0.0, processIdentifier: $0.1) }
        if let resolution = try ApplicationIdentifierMatcher.resolution(for: identifier, in: candidates) {
            guard !resolution.hasWinningTie else {
                throw PeekabooError.ambiguousAppIdentifier(
                    identifier,
                    suggestions: resolution.ambiguitySuggestions)
            }
            let (app, pid) = runningApps[resolution.index]
            let application = Self.applicationInfo(from: app, processIdentifier: pid)
            let proof = application.processIdentity.map {
                resolution.proof(selectedProcessIdentity: $0)
            }
            return application.withSelectorResolutionProofs(proof.map { [$0] })
        }

        throw PeekabooError.appNotFound(identifier)
    }

    private static func applicationInfo(
        from app: NSRunningApplication,
        processIdentifier: pid_t) -> ServiceApplicationInfo
    {
        ServiceApplicationInfo(
            processIdentifier: processIdentifier,
            processStartIdentity: SystemIdentityResolver.processStartIdentity(processIdentifier),
            bundleIdentifier: app.bundleIdentifier,
            name: app.localizedName ?? app.bundleIdentifier ?? "Unknown",
            bundlePath: app.bundleURL?.path,
            executablePath: app.executableURL?.path,
            isActive: app.isActive,
            isHidden: app.isHidden,
            windowCount: 0,
            activationPolicy: ApplicationService.serviceActivationPolicy(from: app.activationPolicy))
    }
}

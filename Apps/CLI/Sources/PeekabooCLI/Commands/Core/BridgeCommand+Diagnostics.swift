import Foundation
import PeekabooBridge
import Security

struct BridgeDiagnostics {
    private let logger: Logger

    init(logger: Logger) {
        self.logger = logger
    }

    @MainActor
    func run(runtimeOptions: CommandRuntimeOptions) async -> BridgeStatusReport {
        let envNoRemote = ProcessInfo.processInfo.environment["PEEKABOO_NO_REMOTE"]
        let shouldSkipRemote = !runtimeOptions.preferRemote || envNoRemote != nil
        let remoteSkipReason = shouldSkipRemote
            ? (!runtimeOptions.preferRemote ? "--no-remote" : "PEEKABOO_NO_REMOTE")
            : nil

        let identity = PeekabooBridgeClientIdentity(
            bundleIdentifier: Bundle.main.bundleIdentifier,
            teamIdentifier: Self.currentTeamIdentifier(),
            processIdentifier: getpid(),
            hostname: Host.current().name
        )

        let candidates = self.candidateSocketPaths(runtimeOptions: runtimeOptions)
        if shouldSkipRemote {
            self.logger.debug("Bridge status: remote skipped (\(remoteSkipReason ?? "unknown reason"))")
            return BridgeStatusReport(
                remoteSkipped: true,
                remoteSkipReason: remoteSkipReason,
                selected: .local(),
                candidates: candidates.map { BridgeCandidateReport(socketPath: $0, result: .skipped) },
                client: .init(identity: identity)
            )
        }

        var results: [BridgeCandidateReport] = []
        var selected: BridgeSelectionReport?

        for socketPath in candidates {
            let client = PeekabooBridgeClient(socketPath: socketPath)
            do {
                let handshake = try await client.handshake(client: identity, requestedHost: nil)
                let report = BridgeHandshakeReport(from: handshake)
                self.logger.debug(
                    "Bridge status: handshake OK \(handshake.hostKind.rawValue) via \(socketPath)",
                    category: "Bridge"
                )
                results.append(.init(socketPath: socketPath, result: .success(report)))

                let enabledOps = handshake.enabledOperations ?? handshake.supportedOperations
                if selected == nil, enabledOps.contains(.captureScreen) {
                    selected = .remote(socketPath: socketPath, handshake: report)
                }
            } catch let envelope as PeekabooBridgeErrorEnvelope {
                self.logger.debug(
                    "Bridge status: handshake error \(envelope.code.rawValue) via \(socketPath): \(envelope.message)",
                    category: "Bridge"
                )
                results.append(.init(socketPath: socketPath, result: .failure(.bridgeEnvelope(envelope))))
            } catch {
                self.logger.debug(
                    "Bridge status: handshake error via \(socketPath): \(String(describing: error))",
                    category: "Bridge"
                )
                results.append(.init(socketPath: socketPath, result: .failure(.other(error))))
            }
        }

        return BridgeStatusReport(
            remoteSkipped: false,
            remoteSkipReason: nil,
            selected: selected ?? .local(),
            candidates: results,
            client: .init(identity: identity)
        )
    }

    private func candidateSocketPaths(runtimeOptions: CommandRuntimeOptions) -> [String] {
        let envSocket = ProcessInfo.processInfo.environment["PEEKABOO_BRIDGE_SOCKET"]
        let explicitSocket = runtimeOptions.bridgeSocketPath ?? envSocket

        let rawCandidates: [String] = if let explicitSocket, !explicitSocket.isEmpty {
            [explicitSocket]
        } else {
            [
                PeekabooBridgeConstants.peekabooSocketPath,
                PeekabooBridgeConstants.claudeSocketPath,
                PeekabooBridgeConstants.clawdbotSocketPath,
            ]
        }

        return rawCandidates.map { NSString(string: $0).expandingTildeInPath }
    }

    private static func currentTeamIdentifier() -> String? {
        var code: SecCode?
        guard SecCodeCopySelf([], &code) == errSecSuccess, let code else { return nil }

        var staticCode: SecStaticCode?
        guard SecCodeCopyStaticCode(code, SecCSFlags(), &staticCode) == errSecSuccess,
              let sCode = staticCode
        else { return nil }

        var infoCF: CFDictionary?
        let flags = SecCSFlags(rawValue: UInt32(kSecCSSigningInformation))
        guard SecCodeCopySigningInformation(sCode, flags, &infoCF) == errSecSuccess,
              let info = infoCF as? [String: Any]
        else { return nil }

        return info[kSecCodeInfoTeamIdentifier as String] as? String
    }
}

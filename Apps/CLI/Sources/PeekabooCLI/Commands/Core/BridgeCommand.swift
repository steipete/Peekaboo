import Commander
import Foundation
import PeekabooBridge
import PeekabooCore
import PeekabooFoundation

/// Diagnose Peekaboo Bridge host connectivity and resolution.
struct BridgeCommand: ParsableCommand {
    static let commandDescription = CommandDescription(
        commandName: "bridge",
        abstract: "Inspect Peekaboo Bridge host connectivity",
        discussion: """
        Peekaboo Bridge lets the CLI run permission-bound operations (Screen Recording, Accessibility,
        AppleScript) via a host app that already has the needed TCC grants.

        By default, Peekaboo prefers a remote host when available:
          1) Peekaboo.app
          2) Clawdis.app
          3) Local in-process fallback (caller needs permissions)

        Examples:
          peekaboo bridge status
          peekaboo bridge status --json-output
          peekaboo bridge status --verbose
          peekaboo bridge status --bridge-socket ~/Library/Application\\ Support/clawdis/bridge.sock
          peekaboo bridge status --no-remote
        """,
        subcommands: [
            StatusSubcommand.self
        ],
        defaultSubcommand: StatusSubcommand.self,
        showHelpOnEmptyInvocation: true
    )
}

extension BridgeCommand {
    @MainActor
    struct StatusSubcommand: OutputFormattable, RuntimeOptionsConfigurable {
        nonisolated(unsafe) static var commandDescription: CommandDescription {
            MainActorCommandDescription.describe {
                CommandDescription(
                    commandName: "status",
                    abstract: "Report which Bridge host would be used"
                )
            }
        }

        @RuntimeStorage private var runtime: CommandRuntime?
        var runtimeOptions = CommandRuntimeOptions()

        private var resolvedRuntime: CommandRuntime {
            guard let runtime else {
                preconditionFailure("CommandRuntime must be configured before accessing runtime resources")
            }
            return runtime
        }

        private var configuration: CommandRuntime.Configuration {
            if let runtime {
                return runtime.configuration
            }
            return self.runtimeOptions.makeConfiguration()
        }

        private var logger: Logger { self.resolvedRuntime.logger }
        var outputLogger: Logger { self.logger }

        var jsonOutput: Bool { self.configuration.jsonOutput }
        private var verbose: Bool { self.configuration.verbose }

        @MainActor
        mutating func run(using runtime: CommandRuntime) async throws {
            self.runtime = runtime
            self.logger.setJsonOutputMode(self.jsonOutput)

            let report = await BridgeDiagnostics(logger: self.logger).run(runtimeOptions: self.runtimeOptions)
            if self.jsonOutput {
                outputSuccessCodable(data: report, logger: self.outputLogger)
                return
            }

            self.printHumanReadable(report: report)
        }

        private func printHumanReadable(report: BridgeStatusReport) {
            print("Peekaboo Bridge")
            print("===============")
            print("")
            print("Selected: \(report.selected.humanSummary)")

            if report.remoteSkipped {
                print("Remote: skipped (\(report.remoteSkipReason ?? "disabled"))")
                return
            }

            guard self.verbose else {
                if report.selected.source == .local {
                    print("")
                    print("Tip: run with --verbose to see remote host probe results.")
                }
                return
            }

            print("")
            print("Candidates:")
            for candidate in report.candidates {
                print("- \(candidate.humanSummary)")
            }
        }
    }
}

extension BridgeCommand.StatusSubcommand: AsyncRuntimeCommand {}

@MainActor
extension BridgeCommand.StatusSubcommand: CommanderBindableCommand {
    mutating func applyCommanderValues(_: CommanderBindableValues) throws {
        // No command-specific flags; runtime flags are bound via RuntimeOptionsConfigurable.
    }
}

// MARK: - Diagnostics model

private struct BridgeDiagnostics: Sendable {
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
            teamIdentifier: nil,
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
                candidates: candidates.map { BridgeCandidateReport(socketPath: $0, result: .skipped) }
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

                if selected == nil, handshake.supportedOperations.contains(.captureScreen) {
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
            candidates: results
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
                PeekabooBridgeConstants.clawdisSocketPath,
            ]
        }

        return rawCandidates.map { NSString(string: $0).expandingTildeInPath }
    }
}

private struct BridgeStatusReport: Codable, Sendable {
    let remoteSkipped: Bool
    let remoteSkipReason: String?
    let selected: BridgeSelectionReport
    let candidates: [BridgeCandidateReport]
}

private struct BridgeCandidateReport: Codable, Sendable {
    let socketPath: String
    let result: BridgeCandidateResult

    var humanSummary: String {
        switch self.result {
        case .skipped:
            "\(self.socketPath) — skipped"
        case let .success(handshake):
            "\(self.socketPath) — OK (\(handshake.hostKind.rawValue), ops: \(handshake.supportedOperations.count))"
        case let .failure(error):
            "\(self.socketPath) — \(error.humanSummary)"
        }
    }
}

private enum BridgeCandidateResult: Codable, Sendable {
    case skipped
    case success(BridgeHandshakeReport)
    case failure(BridgeCandidateErrorReport)
}

private struct BridgeHandshakeReport: Codable, Sendable {
    let negotiatedVersion: PeekabooBridgeProtocolVersion
    let hostKind: PeekabooBridgeHostKind
    let build: String?
    let supportedOperations: [PeekabooBridgeOperation]
    let permissionTags: [String: [PeekabooBridgePermissionKind]]

    init(from handshake: PeekabooBridgeHandshakeResponse) {
        self.negotiatedVersion = handshake.negotiatedVersion
        self.hostKind = handshake.hostKind
        self.build = handshake.build
        self.supportedOperations = handshake.supportedOperations
        self.permissionTags = handshake.permissionTags
    }
}

private struct BridgeCandidateErrorReport: Codable, Sendable {
    let kind: String
    let code: String?
    let message: String
    let details: String?
    let hint: String?

    static func bridgeEnvelope(_ envelope: PeekabooBridgeErrorEnvelope) -> BridgeCandidateErrorReport {
        let hint: String? = if envelope.code == .unauthorizedClient {
            "Client not signed by an allowed TeamID. For local dev, set " +
                "PEEKABOO_ALLOW_UNSIGNED_SOCKET_CLIENTS=1 in the host."
        } else {
            nil
        }
        return BridgeCandidateErrorReport(
            kind: "bridge",
            code: envelope.code.rawValue,
            message: envelope.message,
            details: envelope.details,
            hint: hint
        )
    }

    static func other(_ error: any Error) -> BridgeCandidateErrorReport {
        BridgeCandidateErrorReport(
            kind: "system",
            code: nil,
            message: error.localizedDescription,
            details: String(describing: error),
            hint: nil
        )
    }

    var humanSummary: String {
        if let code {
            return "\(code): \(self.message)"
        }
        return self.message
    }
}

private struct BridgeSelectionReport: Codable, Sendable {
    enum Source: String, Codable, Sendable {
        case remote
        case local
    }

    let source: Source
    let socketPath: String?
    let handshake: BridgeHandshakeReport?

    static func local() -> BridgeSelectionReport {
        BridgeSelectionReport(source: .local, socketPath: nil, handshake: nil)
    }

    static func remote(socketPath: String, handshake: BridgeHandshakeReport) -> BridgeSelectionReport {
        BridgeSelectionReport(source: .remote, socketPath: socketPath, handshake: handshake)
    }

    var humanSummary: String {
        switch self.source {
        case .local:
            return "local (in-process)"
        case .remote:
            let kind = self.handshake?.hostKind.rawValue ?? "remote"
            let buildSuffix = self.handshake?.build.map { " (build \($0))" } ?? ""
            if let socketPath {
                return "remote \(kind) via \(socketPath)\(buildSuffix)"
            }
            return "remote \(kind)\(buildSuffix)"
        }
    }
}

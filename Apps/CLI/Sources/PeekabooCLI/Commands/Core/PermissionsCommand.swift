import Commander
import Foundation
import PeekabooCore
import PeekabooFoundation
import PeekabooXPC

@MainActor

struct PermissionsCommand: ParsableCommand {
    static let commandDescription = CommandDescription(
        commandName: "permissions",
        abstract: "Check Peekaboo permissions",
        subcommands: [
            StatusSubcommand.self,
            GrantSubcommand.self,
            HelperStatusSubcommand.self,
            HelperBootstrapSubcommand.self,
        ],
        defaultSubcommand: StatusSubcommand.self
    )

    @MainActor

    struct StatusSubcommand: OutputFormattable, RuntimeOptionsConfigurable {
        @RuntimeStorage private var runtime: CommandRuntime?
        var runtimeOptions = CommandRuntimeOptions()

        @Flag(name: .customLong("no-remote"), help: "Skip XPC helper and query permissions locally")
        var noRemote = false

        @Option(name: .customLong("xpc-service"), help: "Override the XPC service name for permission checks")
        var xpcService: String?

        private var resolvedRuntime: CommandRuntime {
            guard let runtime else {
                preconditionFailure("CommandRuntime must be configured before accessing runtime resources")
            }
            return runtime
        }

        var outputLogger: Logger { self.resolvedRuntime.logger }
        var jsonOutput: Bool { self.runtime?.configuration.jsonOutput ?? self.runtimeOptions.jsonOutput }

        @MainActor
        mutating func run(using runtime: CommandRuntime) async throws {
            self.runtime = runtime
            let response = await PermissionHelpers.getCurrentPermissionsWithSource(
                services: runtime.services,
                allowRemote: !self.noRemote,
                serviceName: self.xpcService
            )
            if self.jsonOutput {
                outputSuccessCodable(data: response, logger: self.outputLogger)
            } else {
                let sourceLabel = response.source == "xpc" ? "XPC helper" : "local runtime"
                print("Source: \(sourceLabel)")
                response.permissions.forEach { print(PermissionHelpers.formatPermissionStatus($0)) }
            }
        }
    }

    @MainActor

    struct GrantSubcommand: OutputFormattable, RuntimeOptionsConfigurable {
        @RuntimeStorage private var runtime: CommandRuntime?
        var runtimeOptions = CommandRuntimeOptions()

        private var resolvedRuntime: CommandRuntime {
            guard let runtime else {
                preconditionFailure("CommandRuntime must be configured before accessing runtime resources")
            }
            return runtime
        }

        var outputLogger: Logger { self.resolvedRuntime.logger }
        var jsonOutput: Bool { self.runtime?.configuration.jsonOutput ?? self.runtimeOptions.jsonOutput }

        @MainActor
        mutating func run(using runtime: CommandRuntime) async throws {
            self.runtime = runtime

            let permissions = await PermissionHelpers.getCurrentPermissions(services: runtime.services)
            if self.jsonOutput {
                outputSuccessCodable(data: permissions, logger: self.outputLogger)
            } else {
                print("Grant the following permissions in System Settings:")
                for permission in permissions {
                    print("• \(permission.name): \(permission.grantInstructions)")
                }
            }
        }
    }

    @MainActor
    struct HelperStatusSubcommand: OutputFormattable, RuntimeOptionsConfigurable {
        @RuntimeStorage private var runtime: CommandRuntime?
        var runtimeOptions = CommandRuntimeOptions()

        @Option(name: .customLong("xpc-service"), help: "Override the XPC service name")
        var xpcService: String?

        private var resolvedServiceName: String {
            self.xpcService ?? ProcessInfo.processInfo.environment["PEEKABOO_XPC_SERVICE"] ?? PeekabooXPCConstants
                .serviceName
        }

        var outputLogger: Logger { self.runtime?.logger ?? Logger.shared }
        var jsonOutput: Bool { self.runtime?.configuration.jsonOutput ?? self.runtimeOptions.jsonOutput }

        @MainActor
        mutating func run(using runtime: CommandRuntime) async throws {
            self.runtime = runtime
            let client = PeekabooXPCClient(serviceName: self.resolvedServiceName)
            let identity = PeekabooXPCClientIdentity(
                bundleIdentifier: Bundle.main.bundleIdentifier,
                teamIdentifier: nil,
                processIdentifier: getpid(),
                hostname: Host.current().name
            )

            do {
                let handshake = try await client.handshake(client: identity, requestedHost: .helper)
                let resolvedPermissionTags = resolvePermissionTags(
                    handshake.permissionTags,
                    operations: handshake.supportedOperations
                )
                let payload = HelperStatusPayload(
                    service: self.resolvedServiceName,
                    hostKind: handshake.hostKind.rawValue,
                    protocolVersion: "\(handshake.negotiatedVersion.major).\(handshake.negotiatedVersion.minor)",
                    build: handshake.build ?? "unknown",
                    supportedOperations: handshake.supportedOperations.map(\.rawValue),
                    permissionTags: resolvedPermissionTags
                )
                if self.jsonOutput {
                    outputSuccessCodable(data: payload, logger: self.outputLogger)
                } else {
                    let summary = "Helper reachable at \(payload.service) " +
                        "[host: \(payload.hostKind), proto: \(payload.protocolVersion), build: \(payload.build)]"
                    print(summary)
                    print("Operations: \(payload.supportedOperations.joined(separator: ", "))")
                    if !payload.permissionTags.isEmpty {
                        let tagSummary = payload.permissionTags
                            .sorted { $0.key < $1.key }
                            .map { key, value in
                                let tags = value.map(\.rawValue).joined(separator: "+")
                                return "\(key)=\(tags)"
                            }
                            .joined(separator: ", ")
                        print("Permission tags: \(tagSummary)")
                    }
                }
            } catch {
                if self.jsonOutput {
                    outputFailure(message: "Helper unreachable", logger: self.outputLogger, error: error)
                } else {
                    print("Helper unreachable at \(self.resolvedServiceName): \(error)")
                    print("Try building the helper (pnpm run build:swift) and starting the LaunchAgent.")
                }
            }
        }
    }

    @MainActor
    struct HelperBootstrapSubcommand: OutputFormattable, RuntimeOptionsConfigurable {
        @RuntimeStorage private var runtime: CommandRuntime?
        var runtimeOptions = CommandRuntimeOptions()

        @Option(name: .customLong("xpc-service"), help: "Override the XPC service name")
        var xpcService: String?

        @Option(name: .customLong("helper-binary"), help: "Path to a built PeekabooHelper binary to install")
        var helperBinary: String?

        @Option(
            name: .customLong("install-path"),
            help: "Destination for the helper binary (default ~/Library/Application Support/Peekaboo/PeekabooHelper)"
        )
        var installPath: String?

        var outputLogger: Logger { self.runtime?.logger ?? Logger.shared }
        var jsonOutput: Bool { self.runtime?.configuration.jsonOutput ?? self.runtimeOptions.jsonOutput }

        @MainActor
        mutating func run(using runtime: CommandRuntime) async throws {
            self.runtime = runtime
            let serviceName = self.resolvedServiceName
            let fm = FileManager.default

            guard let helperSource = self.resolveHelperBinary(fm: fm) else {
                self
                    .emitFailure(
                        "Unable to find PeekabooHelper. Build with `pnpm run build:swift` or pass --helper-binary."
                    )
                return
            }

            let destination = self.resolvedInstallPath
            do {
                try self.installHelperBinary(from: helperSource, to: destination, fm: fm)
                let plistPath = try self.writeLaunchAgent(
                    binaryPath: destination,
                    serviceName: serviceName,
                    fm: fm
                )
                try self.bootstrapLaunchAgent(plistPath: plistPath, serviceName: serviceName)

                let client = PeekabooXPCClient(serviceName: serviceName)
                let identity = PeekabooXPCClientIdentity(
                    bundleIdentifier: Bundle.main.bundleIdentifier,
                    teamIdentifier: nil,
                    processIdentifier: getpid(),
                    hostname: Host.current().name
                )
                let handshake = try await client.handshake(client: identity, requestedHost: .helper)
                let resolvedPermissionTags = resolvePermissionTags(
                    handshake.permissionTags,
                    operations: handshake.supportedOperations
                )

                let result = HelperBootstrapResult(
                    service: serviceName,
                    plistPath: plistPath,
                    binaryPath: destination,
                    hostKind: handshake.hostKind.rawValue,
                    build: handshake.build ?? "unknown",
                    supportedOperations: handshake.supportedOperations.map(\.rawValue),
                    permissionTags: resolvedPermissionTags
                )
                if self.jsonOutput {
                    outputSuccessCodable(data: result, logger: self.outputLogger)
                } else {
                    print("Helper installed and started at \(serviceName)")
                    print("  LaunchAgent: \(plistPath)")
                    print("  Binary: \(destination)")
                    print("  Host: \(result.hostKind) (build \(result.build))")
                    print("  Operations: \(result.supportedOperations.joined(separator: ", "))")
                    if !result.permissionTags.isEmpty {
                        let tagSummary = result.permissionTags
                            .sorted { $0.key < $1.key }
                            .map { key, value in
                                let tags = value.map(\.rawValue).joined(separator: "+")
                                return "\(key)=\(tags)"
                            }
                            .joined(separator: ", ")
                        print("  Permission tags: \(tagSummary)")
                    }
                }
            } catch {
                self.emitFailure("Helper bootstrap failed", error: error)
            }
        }

        private var resolvedServiceName: String {
            self.xpcService ?? ProcessInfo.processInfo.environment["PEEKABOO_XPC_SERVICE"] ?? PeekabooXPCConstants
                .serviceName
        }

        private var resolvedInstallPath: String {
            let defaultPath = ("~/Library/Application Support/Peekaboo/PeekabooHelper" as NSString)
                .expandingTildeInPath
            return (self.installPath.map { ($0 as NSString).expandingTildeInPath }) ?? defaultPath
        }

        private func resolveHelperBinary(fm: FileManager) -> String? {
            if let provided = self.helperBinary, !provided.isEmpty {
                let expanded = (provided as NSString).expandingTildeInPath
                return fm.isExecutableFile(atPath: expanded) ? expanded : nil
            }
            if let envPath = ProcessInfo.processInfo.environment["PEEKABOO_HELPER_BINARY"] {
                let expanded = (envPath as NSString).expandingTildeInPath
                if fm.isExecutableFile(atPath: expanded) { return expanded }
            }
            if let sibling = Bundle.main.executableURL?
                .deletingLastPathComponent()
                .appendingPathComponent("PeekabooHelper").path,
                fm.isExecutableFile(atPath: sibling) {
                return sibling
            }

            let cwd = fm.currentDirectoryPath
            let candidates = [
                ".build/debug/PeekabooHelper",
                ".build/release/PeekabooHelper",
                "Core/PeekabooCore/.build/debug/PeekabooHelper",
                "Core/PeekabooCore/.build/release/PeekabooHelper",
            ].map { NSString(string: cwd).appendingPathComponent($0) }

            for candidate in candidates where fm.isExecutableFile(atPath: candidate) {
                return candidate
            }
            return nil
        }

        private func installHelperBinary(from source: String, to destination: String, fm: FileManager) throws {
            let destURL = URL(fileURLWithPath: destination)
            try fm.createDirectory(
                at: destURL.deletingLastPathComponent(),
                withIntermediateDirectories: true,
                attributes: nil
            )
            if fm.fileExists(atPath: destination) {
                try fm.removeItem(atPath: destination)
            }
            try fm.copyItem(atPath: source, toPath: destination)
            try fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: destination)
        }

        private func writeLaunchAgent(
            binaryPath: String,
            serviceName: String,
            fm: FileManager
        ) throws -> String {
            let launchAgentsDir = ("~/Library/LaunchAgents" as NSString).expandingTildeInPath
            try fm.createDirectory(atPath: launchAgentsDir, withIntermediateDirectories: true, attributes: nil)
            let plistPath = (launchAgentsDir as NSString).appendingPathComponent("\(serviceName).plist")
            let logsDir = ("~/Library/Logs/Peekaboo" as NSString).expandingTildeInPath
            try fm.createDirectory(atPath: logsDir, withIntermediateDirectories: true, attributes: nil)
            let logPath = (logsDir as NSString).appendingPathComponent("PeekabooHelper.log")

            let plist: [String: Any] = [
                "Label": serviceName,
                "ProgramArguments": [binaryPath],
                "MachServices": [serviceName: true],
                "RunAtLoad": false,
                "KeepAlive": ["SuccessfulExit": false],
                "StandardOutPath": logPath,
                "StandardErrorPath": logPath,
                "EnvironmentVariables": [
                    "PEEKABOO_XPC_SERVICE": serviceName,
                ],
            ]

            let data = try PropertyListSerialization.data(
                fromPropertyList: plist,
                format: .xml,
                options: 0
            )
            try data.write(to: URL(fileURLWithPath: plistPath))
            return plistPath
        }

        private func bootstrapLaunchAgent(plistPath: String, serviceName: String) throws {
            let uid = getuid()
            let launchctl = "/bin/launchctl"

            func run(_ args: [String]) throws {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: launchctl)
                process.arguments = args
                try process.run()
                process.waitUntilExit()
                if process.terminationStatus != 0 {
                    throw PeekabooError.operationError(message: "launchctl \(args.joined(separator: " ")) failed")
                }
            }

            _ = try? run(["bootout", "gui/\(uid)", plistPath])
            try run(["bootstrap", "gui/\(uid)", plistPath])
            try run(["enable", "gui/\(uid)/\(serviceName)"])
            try run(["kickstart", "-k", "gui/\(uid)/\(serviceName)"])
        }

        private func emitFailure(_ message: String, error: (any Error)? = nil) {
            if self.jsonOutput {
                outputFailure(message: message, logger: self.outputLogger, error: error)
            } else {
                print(message + (error.map { ": \($0)" } ?? ""))
            }
        }
    }
}

private func resolvePermissionTags(
    _ advertised: [String: [PeekabooXPCPermissionKind]],
    operations: [PeekabooXPCOperation]
) -> [String: [PeekabooXPCPermissionKind]] {
    if !advertised.isEmpty { return advertised }
    return Dictionary(
        uniqueKeysWithValues: operations.map { op in
            (op.rawValue, Array(op.requiredPermissions).sorted { $0.rawValue < $1.rawValue })
        })
}

private struct HelperStatusPayload: Codable {
    let service: String
    let hostKind: String
    let protocolVersion: String
    let build: String
    let supportedOperations: [String]
    let permissionTags: [String: [PeekabooXPCPermissionKind]]
}

private struct HelperBootstrapResult: Codable {
    let service: String
    let plistPath: String
    let binaryPath: String
    let hostKind: String
    let build: String
    let supportedOperations: [String]
    let permissionTags: [String: [PeekabooXPCPermissionKind]]
}

@MainActor
extension PermissionsCommand.StatusSubcommand: ParsableCommand {
    nonisolated(unsafe) static var commandDescription: CommandDescription {
        MainActorCommandDescription.describe {
            CommandDescription(
                commandName: "status",
                abstract: "Show current permissions"
            )
        }
    }
}

extension PermissionsCommand.StatusSubcommand: AsyncRuntimeCommand {}

@MainActor
extension PermissionsCommand.StatusSubcommand: CommanderBindableCommand {
    mutating func applyCommanderValues(_ values: CommanderBindableValues) throws {
        _ = values
    }
}

@MainActor
extension PermissionsCommand.GrantSubcommand: ParsableCommand {
    nonisolated(unsafe) static var commandDescription: CommandDescription {
        MainActorCommandDescription.describe {
            CommandDescription(
                commandName: "grant",
                abstract: "Show grant instructions"
            )
        }
    }
}

@MainActor
extension PermissionsCommand.HelperStatusSubcommand: ParsableCommand {
    nonisolated(unsafe) static var commandDescription: CommandDescription {
        MainActorCommandDescription.describe {
            CommandDescription(
                commandName: "helper-status",
                abstract: "Check connectivity to the Peekaboo helper"
            )
        }
    }
}

@MainActor
extension PermissionsCommand.HelperStatusSubcommand: AsyncRuntimeCommand {}

@MainActor
extension PermissionsCommand.HelperStatusSubcommand: CommanderBindableCommand {
    mutating func applyCommanderValues(_ values: CommanderBindableValues) throws {
        _ = values
    }
}

@MainActor
extension PermissionsCommand.HelperBootstrapSubcommand: ParsableCommand {
    nonisolated(unsafe) static var commandDescription: CommandDescription {
        MainActorCommandDescription.describe {
            CommandDescription(
                commandName: "helper-bootstrap",
                abstract: "Guide installing or starting the Peekaboo helper LaunchAgent"
            )
        }
    }
}

@MainActor
extension PermissionsCommand.HelperBootstrapSubcommand: AsyncRuntimeCommand {}

@MainActor
extension PermissionsCommand.HelperBootstrapSubcommand: CommanderBindableCommand {
    mutating func applyCommanderValues(_ values: CommanderBindableValues) throws {
        _ = values
    }
}

extension PermissionsCommand.GrantSubcommand: AsyncRuntimeCommand {}

@MainActor
extension PermissionsCommand.GrantSubcommand: CommanderBindableCommand {
    mutating func applyCommanderValues(_ values: CommanderBindableValues) throws {
        _ = values
    }
}

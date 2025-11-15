import Foundation
import Subprocess
#if canImport(System)
import System
#else
import SystemPackage
#endif

enum TestChildProcess {
    struct Result {
        let standardOutput: String
        let standardError: String
        let status: TerminationStatus
    }

    static func runPeekaboo(
        _ arguments: [String],
        environment extraEnvironment: [String: String] = [:]
    ) async throws -> Result {
        let binaryURL = try Self.peekabooBinaryURL()
        var environmentOverrides: [Environment.Key: String?] = [:]
        for (key, value) in extraEnvironment {
            if let envKey = Environment.Key(rawValue: key) {
                environmentOverrides[envKey] = value
            }
        }
        let environment = Environment.inherit.updating(environmentOverrides)
        let collected = try await Subprocess.run(
            .path(FilePath(binaryURL.path)),
            arguments: Arguments(arguments),
            environment: environment,
            output: .string(limit: .max),
            error: .string(limit: .max)
        )
        return Result(
            standardOutput: collected.standardOutput ?? "",
            standardError: collected.standardError ?? "",
            status: collected.terminationStatus
        )
    }

    private static func peekabooBinaryURL() throws -> URL {
        if let override = ProcessInfo.processInfo.environment["PEEKABOO_CLI_BINARY"], !override.isEmpty {
            return URL(fileURLWithPath: override)
        }

        let packageRoot = Self.packageRootURL()
        let potentialPaths = [
            packageRoot.appendingPathComponent(".build/debug/peekaboo"),
            packageRoot.appendingPathComponent(".build/arm64-apple-macosx/debug/peekaboo"),
            packageRoot.appendingPathComponent(".build/x86_64-apple-macosx/debug/peekaboo")
        ]

        if let match = potentialPaths.first(where: { FileManager.default.isExecutableFile(atPath: $0.path) }) {
            return match
        }

        throw RuntimeError(
            "Unable to locate peekaboo binary. Checked: \n\(potentialPaths.map(\.path).joined(separator: "\n"))"
        )
    }

    static func canLocatePeekabooBinary() -> Bool {
        (try? self.peekabooBinaryURL()) != nil
    }

    private static func packageRootURL() -> URL {
        var url = URL(fileURLWithPath: #filePath)
        // .../Apps/CLI/Tests/CLIRuntimeTests/Support/TestChildProcess.swift
        for _ in 0..<4 {
            url.deleteLastPathComponent()
        }
        return url
    }
}

struct RuntimeError: Error, CustomStringConvertible {
    let message: String
    init(_ message: String) { self.message = message }
    var description: String { self.message }
}

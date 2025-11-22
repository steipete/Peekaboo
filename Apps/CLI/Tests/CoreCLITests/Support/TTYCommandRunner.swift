import Darwin
import Foundation

/// Minimal PTY runner used in tests to exercise interactive CLI flows.
/// Spawns a process inside a pseudo-terminal, seeds PATH, isolates the
/// process group, and force-kills the group on teardown to avoid leaks.
struct TTYCommandRunner {
    struct Result {
        let text: String
    }

    struct Options {
        var rows: UInt16 = 50
        var cols: UInt16 = 160
        var timeout: TimeInterval = 5.0
        var extraArgs: [String] = []
    }

    enum Error: Swift.Error {
        case binaryNotFound(String)
        case launchFailed(String)
        case timedOut
    }

    // swiftlint:disable cyclomatic_complexity function_body_length
    func run(binary: String, send script: String, options: Options = Options()) throws -> Result {
        guard let resolved = Self.which(binary) else { throw Error.binaryNotFound(binary) }

        var masterFD: Int32 = -1
        var slaveFD: Int32 = -1
        var term = termios()
        var win = winsize(ws_row: options.rows, ws_col: options.cols, ws_xpixel: 0, ws_ypixel: 0)
        guard openpty(&masterFD, &slaveFD, nil, &term, &win) == 0 else {
            throw Error.launchFailed("openpty failed")
        }
        _ = fcntl(masterFD, F_SETFL, O_NONBLOCK)

        let master = FileHandle(fileDescriptor: masterFD, closeOnDealloc: true)
        let slave = FileHandle(fileDescriptor: slaveFD, closeOnDealloc: true)

        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: resolved)
        proc.arguments = options.extraArgs
        proc.standardInput = slave
        proc.standardOutput = slave
        proc.standardError = slave
        proc.environment = ["PATH": Self.enrichedPath()]

        var didLaunch = false
        try proc.run()
        didLaunch = true

        // Isolate into its own process group so background children are killed during cleanup.
        let pid = proc.processIdentifier
        var processGroup: pid_t?
        if setpgid(pid, pid) == 0 {
            processGroup = pid
        }

        var cleanedUp = false
        func cleanup() {
            guard !cleanedUp else { return }
            cleanedUp = true

            if didLaunch, proc.isRunning {
                try? master.write(contentsOf: Data("/exit\n".utf8))
            }

            try? master.close()
            try? slave.close()

            guard didLaunch else { return }

            if proc.isRunning {
                proc.terminate()
            }
            if let pgid = processGroup {
                kill(-pgid, SIGTERM)
            }
            let waitDeadline = Date().addingTimeInterval(1.5)
            while proc.isRunning, Date() < waitDeadline {
                usleep(80_000)
            }
            if proc.isRunning {
                if let pgid = processGroup {
                    kill(-pgid, SIGKILL)
                }
                kill(proc.processIdentifier, SIGKILL)
            }
            if didLaunch {
                proc.waitUntilExit()
            }
        }
        defer { cleanup() }

        func send(_ text: String) throws {
            guard let data = text.data(using: .utf8) else { return }
            try master.write(contentsOf: data)
        }

        let primaryDeadline = Date().addingTimeInterval(options.timeout)
        var afterFirstByteDeadline: Date?
        var buffer = Data()
        func readChunk() {
            var tmp = [UInt8](repeating: 0, count: 8192)
            let n = Darwin.read(masterFD, &tmp, tmp.count)
            if n > 0 { buffer.append(contentsOf: tmp.prefix(n)) }
        }

        usleep(120_000) // boot grace
        try send(script)
        try send("\r")

        while true {
            readChunk()

            if !buffer.isEmpty, afterFirstByteDeadline == nil {
                afterFirstByteDeadline = Date().addingTimeInterval(0.5)
            }

            if let text = String(data: buffer, encoding: .utf8), !text.isEmpty {
                if text.contains("CHILD_PID=") || text.contains("\n") {
                    break
                }
            }

            let now = Date()
            if let byteDeadline = afterFirstByteDeadline, now >= byteDeadline { break }
            if afterFirstByteDeadline == nil, now >= primaryDeadline { break }

            usleep(60_000)
        }

        guard let text = String(data: buffer, encoding: .utf8), !text.isEmpty else {
            throw Error.timedOut
        }

        return Result(text: text)
    }
    // swiftlint:enable cyclomatic_complexity function_body_length

    static func which(_ tool: String) -> String? {
        if let path = runWhich(tool) { return path }
        let home = NSHomeDirectory()
        let candidates = [
            "/opt/homebrew/bin/\(tool)",
            "/usr/local/bin/\(tool)",
            "\(home)/.local/bin/\(tool)",
            "\(home)/bin/\(tool)",
        ]
        for path in candidates where FileManager.default.isExecutableFile(atPath: path) {
            return path
        }
        return nil
    }

    private static func runWhich(_ tool: String) -> String? {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        proc.arguments = [tool]
        let pipe = Pipe()
        proc.standardOutput = pipe
        try? proc.run()
        proc.waitUntilExit()
        guard proc.terminationStatus == 0 else { return nil }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let path = String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
              !path.isEmpty else { return nil }
        return path
    }

    /// Expand PATH with common Homebrew/npm/bun locations to mirror agent runtime probes.
    static func enrichedPath() -> String {
        let base = ProcessInfo.processInfo.environment["PATH"] ?? "/usr/bin:/bin"
        let extras = [
            "/opt/homebrew/bin",
            "/usr/local/bin",
            "\(NSHomeDirectory())/.local/bin",
            "\(NSHomeDirectory())/bin",
        ]
        return ([base] + extras).joined(separator: ":")
    }
}
